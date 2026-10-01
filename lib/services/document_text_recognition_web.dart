import 'dart:js_interop';
import 'dart:typed_data';

@JS('queueOcrRecognize')
external JSPromise<JSString> _queueOcrRecognize(
  JSUint8Array imageBytes,
  JSString mimeType,
);

@JS('queueOcrRecognizeEnhanced')
external JSPromise<JSString> _queueOcrRecognizeEnhanced(
  JSUint8Array imageBytes,
  JSString mimeType,
);

@JS('queueOcrWarmup')
external JSPromise<JSString> _queueOcrWarmup();

class DocumentTextRecognizer {
  bool get isSupported => true;

  Future<void> warmUp() async {
    await _queueOcrWarmup().toDart;
  }

  Future<String> recognize({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (fileName.toLowerCase().endsWith('.pdf')) {
      throw UnsupportedError(
        'PDF OCR is not supported. Review this PDF manually.',
      );
    }

    return _recognizeSingle(bytes: bytes, fileName: fileName);
  }

  Future<String> recognizeEnhanced({
    required Uint8List bytes,
    required String fileName,
    required String primaryText,
  }) async {
    final mimeType = _mimeType(fileName);
    final enhancedText = await _queueOcrRecognizeEnhanced(
      bytes.toJS,
      mimeType.toJS,
    ).toDart;
    final first = primaryText.trim();
    final second = enhancedText.toDart.trim();
    if (first.isEmpty) return second;
    if (second.isEmpty || first == second) return first;
    return '$first\n$second';
  }

  Future<String> _recognizeSingle({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final mimeType = _mimeType(fileName);
    final text = await _queueOcrRecognize(bytes.toJS, mimeType.toJS).toDart;
    return text.toDart;
  }

  String _mimeType(String fileName) {
    final lowerName = fileName.toLowerCase();
    if (lowerName.endsWith('.png')) return 'image/png';
    if (lowerName.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> close() async {}
}
