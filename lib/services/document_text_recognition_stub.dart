import 'dart:typed_data';

class DocumentTextRecognizer {
  bool get isSupported => false;

  Future<void> warmUp() async {}

  Future<String> recognize({
    required Uint8List bytes,
    required String fileName,
  }) {
    throw UnsupportedError(
      'AI-assisted document review is not supported on this platform.',
    );
  }

  Future<String> recognizeEnhanced({
    required Uint8List bytes,
    required String fileName,
    required String primaryText,
  }) {
    throw UnsupportedError(
      'AI-assisted document review is not supported on this platform.',
    );
  }

  Future<void> close() async {}
}
