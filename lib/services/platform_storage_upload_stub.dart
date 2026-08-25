import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

UploadTask startPlatformStorageUpload({
  required Reference reference,
  required Uint8List bytes,
  required String? filePath,
  required SettableMetadata metadata,
}) {
  return reference.putData(bytes, metadata);
}
