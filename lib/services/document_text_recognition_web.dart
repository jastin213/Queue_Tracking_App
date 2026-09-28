import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'document_ocr_preprocessor.dart';

@JS('queueOcrRecognize')
external JSPromise<JSString> _queueOcrRecognize(JSString imageDataUrl);

class DocumentTextRecognizer {
  bool get isSupported => true;

  Future<String> recognize({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (fileName.toLowerCase().endsWith('.pdf')) {
      throw UnsupportedError(
        'PDF OCR is not supported. Review this PDF manually.',
      );
    }

    final enhancedFuture = enhanceDocumentImageForOcr(
      bytes: bytes,
      fileName: fileName,
    );
    final primaryText = await _recognizeSingle(
      bytes: bytes,
      fileName: fileName,
    );
    final enhanced = await enhancedFuture;
    if (enhanced == null) return primaryText;

    final enhancedText = await _recognizeSingle(
      bytes: enhanced.bytes,
      fileName: enhanced.fileName,
    );
    final first = primaryText.trim();
    final second = enhancedText.trim();
    if (first.isEmpty) return second;
    if (second.isEmpty || first == second) return first;
    return '$first\n$second';
  }

  Future<String> _recognizeSingle({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final mimeType = fileName.toLowerCase().endsWith('.png')
        ? 'image/png'
        : fileName.toLowerCase().endsWith('.webp')
        ? 'image/webp'
        : 'image/jpeg';
    final dataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
    final text = await _queueOcrRecognize(dataUrl.toJS).toDart;
    return text.toDart;
  }

  Future<void> close() async {}
}
