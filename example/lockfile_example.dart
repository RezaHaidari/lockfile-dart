import 'package:lockfile/lockfile.dart';

void main() async {
  var lock = LockFileManager();
  await lock.lock(
    
      './example1.txt',
      LockOptions(
        realpath: false,
        retries: RetryOptions(
          maxDelay: Duration(milliseconds: 10),
          maxAttempts: 3,
        ),
      ));
}
