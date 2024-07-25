# Dart Lockfile Library

This Dart library utilizes the mkdir strategy which works atomically on any kind of file system, even network based ones. The lockfile path is based on the file path you are trying to lock by suffixing it with .lock.

## Installation

To use the Dart Lockfile Library in your project, add the following dependency to your `pubspec.yaml` file:

```yaml
dependencies:
  lockfile: ^1.0.0
```

Then, run `pub get` to fetch the library.

## Usage

Create an instance of LockFileManager

```dart

final lockFileManager = LockFileManager();

```

Call the lock method to acquire a lock on a file

```dart

await lock.lock(
  'path/to/file',
  LockOptions(
    retries: RetryOptions(
    maxDelay: Duration(milliseconds: 20),
    maxAttempts: 3,
    ),
  ));

```

Call the unlock method to release the lock on a file

```dart
await lockFileManager.unlock('path/to/file', LockOptions());

```

Call the check method to check if a file is locked

```dart
final isLocked = await lockFileManager.check('path/to/file', LockOptions());

```

Get the locks

```dart
final locks = await lockFileManager.getLocks();

```
