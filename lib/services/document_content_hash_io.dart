import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

Future<String> documentContentHash(Uint8List bytes) {
  return compute(_sha256Hex, bytes);
}

String _sha256Hex(Uint8List bytes) => sha256.convert(bytes).toString();
