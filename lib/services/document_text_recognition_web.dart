import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

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
