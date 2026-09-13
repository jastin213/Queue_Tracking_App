import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

class DocumentTextRecognizer {
  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  Future<String> recognize({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (!isSupported) {
      throw UnsupportedError(
        'AI-assisted document review is available on Android, iOS, and web.',
      );
    }

    if (fileName.toLowerCase().endsWith('.pdf')) {
      throw UnsupportedError(
        'PDF OCR is not supported. Review this PDF manually.',
      );
    }

    final extension = _safeImageExtension(fileName);
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}'
      'npjn_document_review_${DateTime.now().microsecondsSinceEpoch}.$extension',
    );

    try {
      await file.writeAsBytes(bytes, flush: true);
      final inputImage = InputImage.fromFilePath(file.path);
      final recognizedText = await _recognizer.processImage(inputImage);
      return recognizedText.text;
    } finally {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  String _safeImageExtension(String fileName) {
    final lowerName = fileName.toLowerCase();
    if (lowerName.endsWith('.png')) return 'png';
    if (lowerName.endsWith('.webp')) return 'webp';
    return 'jpg';
  }

  Future<void> close() => _recognizer.close();
}
