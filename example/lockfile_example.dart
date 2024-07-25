import 'package:lockfile/lockfile.dart';

void main() async {
  var lock = LockFileManager();
  await lock.lock(
      './example.txt',
      LockOptions(
        retries: RetryOptions(
          maxDelay: Duration(milliseconds: 10),
          maxAttempts: 3,
        ),
      ));
}
