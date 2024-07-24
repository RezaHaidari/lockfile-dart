import 'dart:io';

import "./lockfile_types.dart";

final cacheSymbol = Object();

class MtimePrecision {
  /// @param {String} file
  /// @param {FileSystemEntity} fs
  /// @param {(Error? err, DateTime? mtime, String? cachedPrecision) => void} callback
  static Future<Probe> probe(
    String file,
    FileSystemEntity fs,
  ) async {
    var cachedPrecision = fs.statSync().mode == cacheSymbol;

    if (cachedPrecision) {
      try {
        var stat = await fs.stat();
        // return Future.value(Probe(mtime: stat.modified, precision: 'ms');
        //stat.modified, cachedPrecision.toString()
        return Probe(stat.modified, cachedPrecision.toString());
      } catch (err) {
        //return Future.value([err, null, null]);
        rethrow;
      }
    } else {
      try {
        // await File(file).setLastModified(mtime);
        var stat = await Directory(file).stat();
        var precision =
            stat.modified.millisecondsSinceEpoch % 1000 == 0 ? 's' : 'ms';

        // Cache the precision in a non-enumerable way
        fs.statSync().mode == cacheSymbol;

        //return Future.value([stat.modified, precision]);
        return Probe(stat.modified, precision);
      } catch (err) {
        // return Future.value([err, null, null]);
        rethrow;
      }
    }
  }

  /// @param {"s" | "ms"} precision
  static DateTime getMtime(String precision) {
    var now = DateTime.now().millisecondsSinceEpoch;

    if (precision == 's') {
      now = (now / 1000).ceil() * 1000;
    }

    return DateTime.fromMillisecondsSinceEpoch(now);
  }
}
