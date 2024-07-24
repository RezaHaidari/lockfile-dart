import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:lockfile/src/lockfile_mtime.dart';
import 'package:lockfile/src/lockfile_types.dart';
import 'package:path/path.dart' as path;
import 'package:retry/retry.dart';

class LockFileManager {
  Map<String, Lock> locks = {};

  LockFileManager() {
    onExit();
  }

  /// Get the lock file path.
  ///
  /// @param {String} file - Lock file.
  /// @param {LockOptions} options - Options.
  String getLockFile(String file, LockOptions options) {
    return options.lockfilePath ?? '$file.lock';
  }

  /// Resolves the canonical path of a file.
  ///
  /// @param {String} file
  /// @param {InternalLockOptions} options
  Future<String?> resolveCanonicalPath(String file, LockOptions options) {
    if (options.realpath == null) {
      return Future.value(file);
    }

    // Use realpath to resolve symlinks and relative paths
    return File(file).resolveSymbolicLinks().then((resolvedPath) {
      return resolvedPath;
    }).catchError((err) {
      throw err;
    });
  }

  /// Checks if the lock is stale based on the file's modification time and options.
  ///
  /// @param {FileStat} stat - The file's statistics.
  /// @param {InternalLockOptions} options - The lock options.
  bool isLockStale(FileStat stat, LockOptions options) {
    if (options.stale == null) {
      return false;
    }
    final num staleTime = options.stale!;
    final DateTime now = DateTime.now();
    final DateTime mtime = stat.modified;

    return mtime
        .isBefore(now.subtract(Duration(milliseconds: staleTime as int)));
  }

  /// Removes the lock file.
  Future<void> removeLock(String file, LockOptions options) async {
    final lockfilePath = getLockFile(file, options);
    Directory(lockfilePath).delete().then((_) {
      return;
    }).catchError((err) {
      throw err;
    });
  }

  /// Acquires a lock on a file.
  Future<Probe> acquireLock(String file, LockOptions options) async {
    final lockfilePath = getLockFile(file, options);

    try {
      // Use mkdir to create the lockfile (atomic operation)
      await Directory(lockfilePath).create();

      // At this point, we acquired the lock!
      // Probe the mtime precision
      final Probe prob =
          await MtimePrecision.probe(lockfilePath, Directory(lockfilePath));

      return prob;
    } catch (err) {
      // If error is not EEXIST then some other error occurred while locking
      if (err.toString().contains('File exists')) {
        // Lock file already exists
        // Read the mtime and mtimePrecision
        final stat = await File(lockfilePath).stat();
        final mtime = stat.modified;
        final mtimePrecision = 'ms'; // stat.mtimePrecision;

        return Probe(mtime, mtimePrecision);
      }

      // Otherwise, check if lock is stale by analyzing the file mtime
      if (options.stale == null || options.stale! <= 0) {
        //throw Exception('Lock file is already being held');

        throw RetryableException(Exception('Lock file is already being held'));
      }

      try {
        final stat = await File(lockfilePath).stat();

        // Retry if the lockfile has been removed (meanwhile)
        // Skip stale check to avoid recursiveness

        if (!isLockStale(stat, options)) {
          //throw Exception('Lock file is already being held');
          throw RetryableException(
              Exception('Lock file is already being held'));
        }

        // If it's stale, remove it and try again!
        // Skip stale check to avoid recursiveness
        await removeLock(file, options);

        options.stale = 0;
        return acquireLock(file, options);
      } catch (err) {
        if (err is FileSystemException && err.osError?.errorCode == 2) {
          options.stale = 0;
          return acquireLock(file, options);
        }
        throw RetryableException(Exception('Error while acquiring lock: $err'));
      }
    }
  }

  /// Updates the lock file.
  void updateLock(String file, LockOptions options) {
    final lock = locks[file];

    if (lock == null) {
      return;
    }

    // Just for safety, should never happen
    if (lock.updateTimeout != null) {
      return;
    }

    lock.updateDelay = lock.updateDelay ?? options.update;
    lock.updateTimeout =
        Timer(Duration(milliseconds: (lock.updateDelay ?? 1000).toInt()), () {
      lock.updateTimeout = null;
      var stale = options.stale ?? 0;

      // Stat the file to check if mtime is still ours
      // If it is, we can still recover from a system sleep or a busy event loop
      File(lock.lockfilePath).stat().then((stat) {
        final isOverThreshold =
            lock.lastUpdate + stale < DateTime.now().millisecondsSinceEpoch;

        // If it failed to update the lockfile, keep trying unless
        // the lockfile was deleted or we are over the threshold
        if (!File(lock.lockfilePath).existsSync()) {
          if (isOverThreshold) {
            return setLockAsCompromised(file, lock, Exception('ECOMPROMISED'));
          }

          lock.updateDelay = 1000;
          return updateLock(file, options);
        }

        final isMtimeOurs = lock.mtime.millisecondsSinceEpoch ==
            stat.modified.millisecondsSinceEpoch;

        if (!isMtimeOurs) {
          return setLockAsCompromised(
            file,
            lock,
            Exception('Unable to update lock within the stale threshold'),
          );
        }

        final mtime = DateTime
            .now(); // Replace with mtimePrecision.getMtime(lock['mtimePrecision']);

        File(lock.lockfilePath).setLastModified(mtime).then((_) {
          final isOverThreshold =
              lock.lastUpdate + stale < DateTime.now().millisecondsSinceEpoch;

          // Ignore if the lock was released
          if (lock.released == true) {
            return;
          }

          // If it failed to update the lockfile, keep trying unless
          // the lockfile was deleted or we are over the threshold
          if (!File(lock.lockfilePath).existsSync()) {
            if (isOverThreshold) {
              return setLockAsCompromised(
                  file, lock, Exception('ECOMPROMISED'));
            }

            lock.updateDelay = 1000;
            return updateLock(file, options);
          }

          // All ok, keep updating..
          lock.mtime = mtime;
          lock.lastUpdate = DateTime.now().millisecondsSinceEpoch;
          lock.updateDelay = null;
          updateLock(file, options);
        }).catchError((err) {
          final isOverThreshold =
              lock.lastUpdate + stale < DateTime.now().millisecondsSinceEpoch;

          if (!File(lock.lockfilePath).existsSync() || isOverThreshold) {
            return setLockAsCompromised(file, lock, Exception('ECOMPROMISED'));
          }

          lock.updateDelay = 1000;
          return updateLock(file, options);
        });
      }).catchError((err) {
        final isOverThreshold =
            lock.lastUpdate + stale < DateTime.now().millisecondsSinceEpoch;

        if (err.toString().contains('No such file or directory') ||
            isOverThreshold) {
          return setLockAsCompromised(file, lock, Exception('ECOMPROMISED'));
        }

        lock.updateDelay = 1000;
        return updateLock(file, options);
      });
    });

    // Unref the timer so that the Dart process can exit freely
    // This is safe because all acquired locks will be automatically released
    // on process exit
    if (lock.updateTimeout is Timer) {
      // Unref the timer (not directly supported in Dart, but this simulates it)
      Timer(Duration(milliseconds: (lock.updateDelay ?? 1000).toInt()), () {});
    }
  }

  /// Sets the lock as compromised and handles the error.
  ///
  /// @param {String} file - The file associated with the lock.
  /// @param {Lock} lock - The lock object.
  /// @param {Exception} err - The error indicating the compromise.
  void setLockAsCompromised(String file, Lock lock, Exception err) {
    // Signal the lock has been released
    lock.released = true;

    // Cancel lock mtime update
    // Just for safety, at this point updateTimeout should be null
    if (lock.updateTimeout != null) {
      lock.updateTimeout!.cancel();
      lock.updateTimeout = null;
    }

    if (locks[file] == lock) {
      locks.remove(file);
    }

    if (lock.options.onCompromised != null) lock.options.onCompromised!(err);
  }

  Future<void> lock(String file, LockOptions options) async {
    // Initialize and sanitize options
    options = options.copyWith(
      stale: 10000,
      update: null,
      realpath: true,
      retries: 0,
      onCompromised: (err) => {throw RetryableException(Exception(err))},
    );

    // Resolve to a canonical file path
    String? resolvedFile;
    try {
      resolvedFile = await resolveCanonicalPath(file, options);
    } catch (e) {
      rethrow; // Handle error or rethrow
    }

    // Attempt to acquire the lock with retries
    final r = RetryOptions(maxAttempts: options.retries);
    await r.retry(
      () async {
        try {
          final probe = await acquireLock(resolvedFile!, options);
          // Lock acquired, store lock info
          locks[resolvedFile] = Lock(
            lockfilePath: getLockFile(file, options),
            mtime: probe.mtime,
            mtimePrecision: probe.mtimePrecision,
            options: options,
            lastUpdate: DateTime.now().millisecondsSinceEpoch,
          );
          // Keep the lock fresh to avoid staleness
          updateLock(resolvedFile, options);
        } catch (e) {
          if (e is RetryableException) rethrow; // Allow retry
          //throw NonRetryableException(e); // Prevent further retries
        }
      },
      retryIf: (e) => e is RetryableException,
    );

    // Logic for releasing the lock (to be implemented)
  }

  Future<void> unlock(String file, LockOptions options) async {
    options = options.copyWith(
      realpath: true,
      fs: Directory,
    );

    String? resolvedFile;
    try {
      resolvedFile = await resolveCanonicalPath(file, options);
    } catch (e) {
      rethrow; // Rethrow the error to be caught by the caller
    }

    // Skip if the lock is not acquired
    final lock = locks[resolvedFile];
    if (lock == null) {
      final error = Exception('Lock is not acquired/owned by you');
      throw error; // Throw the error to be caught by the caller
    }

    lock.updateTimeout?.cancel(); // Cancel lock mtime update
    lock.released = true; // Signal the lock has been released
    locks.remove(resolvedFile); // Delete from locks

    await removeLock(resolvedFile!, options); // Await the removal of the lock
  }

  Future<bool> check(String file, LockOptions options) async {
    options = options.copyWith(
      stale: 10000,
      realpath: true,
      fs: options.fs,
    );

    options.stale = max(options.stale ?? 0, 2000);

    String? resolvedFile;
    try {
      resolvedFile = await resolveCanonicalPath(file, options);
    } catch (e) {
      return false;
    }

    try {
      final stat = await Directory(getLockFile(resolvedFile!, options)).stat();
      // If execution reaches here, lockfile exists. Check if lock is stale.
      return !isLockStale(stat, options);
    } catch (e) {
      if (e is FileSystemException && e.osError?.errorCode == 2) {
        // If does not exist, file is not locked.
        return false;
      } else {
        rethrow; // Rethrow other exceptions to be caught by the caller
      }
    }
  }

  getLocks() {
    return locks;
  }

  void onExit() {
    ProcessSignal.sigterm.watch().listen((signal) {
      cleanupLocks();
    });
    ProcessSignal.sigint.watch().listen((signal) {
      cleanupLocks();
      exit(0); // Ensure the process exits after cleanup
    });
  }

  void cleanupLocks() {
    locks.forEach((file, lockInfo) {
      final options = lockInfo.options;
      final lockFile = getLockFile(file, options);
      try {
        Directory(lockFile).deleteSync();
      } catch (e) {
        // Empty catch block to ignore any errors during cleanup
      }
    });
  }
}

