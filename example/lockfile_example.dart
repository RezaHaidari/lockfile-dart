import 'package:lockfile/lockfile.dart';
import 'package:retry/retry.dart';

void main() async {
  var lock = LockFileManager();
 await lock.lock('./example.txt', LockOptions(
    retries: RetryOptions(
      maxDelay: Duration(seconds: 10),
      maxAttempts: 3,
    ),
  ));

// callback(releasedCallback : () async {
//     print("Released");
//   }
//   );

  // var lock = LockFileManager();
  // var callback = await lock.lock('./example.txt', LockOptions(
  //   retries: RetryOptions(
  //     maxDelay: Duration(seconds: 1),
  //     maxAttempts: 3,
  //   ),
  // ));

// callback(releasedCallback : () async {
//     print("Released");
//   }
//   );


  // var isLocked = await lock.check('./example.txt', LockOptions());
  // print("Is locked: $isLocked");

  // Future.delayed(Duration(seconds: 5), () async {
  //   await lock.unlock('./example.txt', LockOptions());

  //   isLocked = await lock.check('./example.txt', LockOptions());

  //   print("Is locked: $isLocked");
  // });
}
