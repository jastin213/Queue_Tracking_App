import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:queue_tracking_app/services/document_image_quality.dart';

void main() {
  test('warns about a small image with no readable edges', () async {
    final image = img.Image(width: 320, height: 240);
    img.fill(image, color: img.ColorRgb8(230, 230, 230));

    final result = await assessDocumentImageQuality(
      bytes: img.encodeJpg(image),
      fileName: 'document.jpg',
    );

    expect(result.shouldWarn, isTrue);
    expect(result.issues, contains(DocumentImageQualityIssue.lowResolution));
    expect(result.issues, contains(DocumentImageQualityIssue.likelyBlurred));
  });

  test('accepts a clear, high-resolution document pattern', () async {
    final image = img.Image(width: 1200, height: 900);
    img.fill(image, color: img.ColorRgb8(235, 235, 235));
    for (var y = 80; y < 820; y += 45) {
      img.fillRect(
        image,
        x1: 80,
        y1: y,
        x2: 1050,
        y2: y + 8,
        color: img.ColorRgb8(30, 30, 30),
      );
    }

    final result = await assessDocumentImageQuality(
      bytes: img.encodeJpg(image, quality: 90),
      fileName: 'document.jpg',
    );

    expect(result.shouldWarn, isFalse);
  });
}
