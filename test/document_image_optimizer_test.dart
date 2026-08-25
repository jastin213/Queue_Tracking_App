import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:queue_tracking_app/services/document_image_optimizer.dart';

void main() {
  test(
    'resizes oversized selected images while preserving proportions',
    () async {
      final source = img.Image(width: 3000, height: 1200);
      img.fill(source, color: img.ColorRgb8(12, 80, 130));
      final originalBytes = img.encodePng(source, level: 1);

      final result = await optimizeDocumentImage(
        bytes: originalBytes,
        fileName: 'vehicle-document.png',
      );

      final decoded = img.decodeImage(result.bytes);
      expect(result.wasOptimized, isTrue);
      expect(decoded, isNotNull);
      expect(decoded!.width, 2048);
      expect(decoded.height, 819);
      expect(result.bytes.length, lessThan(originalBytes.length));
    },
  );

  test('leaves PDF files unchanged', () async {
    final originalBytes = Uint8List.fromList(<int>[37, 80, 68, 70]);

    final result = await optimizeDocumentImage(
      bytes: originalBytes,
      fileName: 'document.pdf',
    );

    expect(result.wasOptimized, isFalse);
    expect(result.bytes, orderedEquals(originalBytes));
  });
}
