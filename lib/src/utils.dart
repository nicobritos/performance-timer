import 'dart:math';

import 'package:meta/meta.dart';

@internal
abstract class Utils {
  static String generateHexId(int bytesCount) {
    final random = Random.secure();
    final bytes = List<int>.generate(bytesCount, (_) => random.nextInt(256));
    return bytesToHex(bytes);
  }

  static String bytesToHex(List<int> bytes) {
    final buffer = StringBuffer();
    for (var byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
