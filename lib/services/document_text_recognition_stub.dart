import 'dart:typed_data';

class DocumentTextRecognizer {
  bool get isSupported => false;

  Future<String> recognize({
    required Uint8List bytes,
    required String fileName,
  }) {
    throw UnsupportedError(
      'AI-assisted document review is not supported on this platform.',
    );
  }

  Future<void> close() async {}
}
