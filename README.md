# Dart Lockfile Library

The Dart Lockfile Library is a powerful tool for managing lockfiles in Dart projects. It provides various methods and options to ensure consistent and reliable dependency resolution.

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

lockFileManager.lock('path/to/file', LockOptions());

```

Call the unlock method to release the lock on a file

```dart
lockFileManager.unlock('path/to/file', LockOptions());

```

Call the check method to check if a file is locked

```dart
final isLocked = lockFileManager.check('path/to/file', LockOptions());

```

Get the locks
```dart
final locks = lockFileManager.getLocks();

```
