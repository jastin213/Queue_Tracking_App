import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class EnhancedOcrImage {
  const EnhancedOcrImage({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

/// Creates a temporary high-contrast copy for a second OCR pass.
///
/// The returned bytes are never uploaded or persisted. The original uploaded
/// image remains the only document stored by the application.
Future<EnhancedOcrImage?> enhanceDocumentImageForOcr({
  required Uint8List bytes,
  required String fileName,
}) async {
  final extension = fileName.contains('.')
      ? fileName.split('.').last.toLowerCase()
      : '';
  if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) return null;

  final enhancedBytes = await compute(_enhanceImageBytes, bytes);
  if (enhancedBytes == null) return null;
  final dotIndex = fileName.lastIndexOf('.');
  final baseName = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
  return EnhancedOcrImage(
    bytes: enhancedBytes,
    fileName: '${baseName}_ocr_enhanced.jpg',
  );
}

Uint8List? _enhanceImageBytes(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  img.Image enhanced = img.bakeOrientation(decoded);
  const targetLongestSide = 2200;
  final longestSide = math.max(enhanced.width, enhanced.height);
  if (longestSide != targetLongestSide) {
    enhanced = enhanced.width >= enhanced.height
        ? img.copyResize(
            enhanced,
            width: targetLongestSide,
            interpolation: img.Interpolation.cubic,
          )
        : img.copyResize(
            enhanced,
            height: targetLongestSide,
            interpolation: img.Interpolation.cubic,
          );
  }

  final meanLuminance = _meanLuminance(enhanced);
  img.grayscale(enhanced);
  img.adjustColor(
    enhanced,
    contrast: 1.35,
    brightness: meanLuminance < 90 ? 1.22 : 1.05,
  );
  img.convolution(
    enhanced,
    filter: const [0, -1, 0, -1, 5, -1, 0, -1, 0],
    amount: 0.72,
  );
  return img.encodeJpg(enhanced, quality: 88);
}

double _meanLuminance(img.Image image) {
  var total = 0.0;
  var count = 0;
  final step = math.max(1, math.max(image.width, image.height) ~/ 500);
  for (var y = 0; y < image.height; y += step) {
    for (var x = 0; x < image.width; x += step) {
      final pixel = image.getPixel(x, y);
      total += 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
      count++;
    }
  }
  return count == 0 ? 128 : total / count;
}
