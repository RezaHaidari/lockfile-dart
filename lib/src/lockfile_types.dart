import 'dart:async';

class LockOptions {
  /// Duration in milliseconds in which the lock is considered stale, defaults to 10000 (minimum value is 5000)
  num? stale;

  /// The interval in milliseconds in which the lockfile's mtime will be updated, defaults to stale/2 (minimum value is 1000, maximum value is stale/2)
  num? update;

  /// The number of retries or a retry options object, defaults to 0
  dynamic retries;

  /// A custom fs to use, defaults to `graceful-fs`
  dynamic fs;

  /// Resolve symlinks using realpath, defaults to true (note that if true, the file must exist previously)
  bool? realpath;

  /// Called if the lock gets compromised, defaults to a function that simply throws the error which will probably cause the process to die
  void Function(Exception)? onCompromised;

  /// Custom lockfile path. e.g.: If you want to lock a directory and create the lock file inside it, you can pass file as <dir path> and options.lockfilePath as <dir path>/dir.lock
  String? lockfilePath;

  LockOptions({
    this.stale,
    this.update,
    this.retries,
    this.fs,
    this.realpath,
    this.onCompromised,
    this.lockfilePath,
  });

  LockOptions copyWith({
    num? stale,
    num? update,
    dynamic retries,
    dynamic fs,
    bool? realpath,
    void Function(Exception)? onCompromised,
    String? lockfilePath,
  }) {
    return LockOptions(
      stale: stale ?? this.stale,
      update: update ?? this.update,
      retries: retries ?? this.retries,
      fs: fs ?? this.fs,
      realpath: realpath ?? this.realpath,
      onCompromised: onCompromised ?? this.onCompromised,
      lockfilePath: lockfilePath ?? this.lockfilePath,
    );
  }
}

/// Internal lock options to be used after the defaults are merged
class InternalLockOptions {
  num? stale;
  num? update;
  dynamic retries;
  dynamic fs;
  bool? realpath;
  void Function(Exception) onCompromised;
  String lockfilePath;

  InternalLockOptions({
    required this.stale,
    required this.update,
    required this.retries,
    required this.fs,
    required this.realpath,
    required this.onCompromised,
    this.lockfilePath = '',
  });
}

class Lock {
  String lockfilePath;
  DateTime mtime;
  String mtimePrecision;
  LockOptions options;
  num lastUpdate;
  Timer? updateTimeout;
  num? updateDelay;
  bool? released;

  Lock({
    required this.lockfilePath,
    required this.mtime,
    required this.mtimePrecision,
    required this.options,
    required this.lastUpdate,
    this.updateTimeout,
    this.updateDelay,
    this.released,
  });
}

class Probe {
  final DateTime mtime;
  final String mtimePrecision;

  Probe(this.mtime, this.mtimePrecision);
}


class RetryableException {
  final Exception exception;
  RetryableException(this.exception);
}
