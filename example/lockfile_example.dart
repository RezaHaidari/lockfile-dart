import 'package:lockfile/lockfile.dart';

void main() async {
  var lock = LockFileManager();
  await lock.lock('./example.txt', LockOptions());

  var isLocked = await lock.check('./example.txt', LockOptions());
  print("Is locked: $isLocked");

  Future.delayed(Duration(seconds: 5), () async {
    await lock.unlock('./example.txt', LockOptions());

    isLocked = await lock.check('./example.txt', LockOptions());

    print("Is locked: $isLocked");
  });
}
