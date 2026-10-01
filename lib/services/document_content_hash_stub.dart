import 'dart:typed_data';

import 'package:crypto/crypto.dart';

Future<String> documentContentHash(Uint8List bytes) async {
  return sha256.convert(bytes).toString();
}
