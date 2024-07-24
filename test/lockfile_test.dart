import 'package:lockfile/lockfile.dart';
import 'package:test/test.dart';

void main() {
  test('LockFileManager check lock', () async {
    var lock = LockFileManager();
    await lock.lock('./example.txt', LockOptions());

    var isLocked = await lock.check('./example.txt', LockOptions());
    expect(isLocked, true);

    Future.delayed(Duration(seconds: 5), () async {
      await lock.unlock('./example.txt', LockOptions());

      isLocked = await lock.check('./example.txt', LockOptions());

      expect(isLocked, false);
    });
  });

}
