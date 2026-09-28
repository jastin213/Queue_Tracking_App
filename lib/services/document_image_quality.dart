import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

enum DocumentImageQualityIssue {
  unreadableFile,
  lowResolution,
  tooDark,
  overexposed,
  likelyBlurred,
}

class DocumentImageQualityAssessment {
  const DocumentImageQualityAssessment({
    required this.issues,
    required this.width,
    required this.height,
  });

  final List<DocumentImageQualityIssue> issues;
  final int width;
  final int height;

  bool get shouldWarn => issues.isNotEmpty;

  List<String> get messages => issues
      .map((issue) {
        return switch (issue) {
          DocumentImageQualityIssue.unreadableFile =>
            'The selected image could not be checked. Make sure it is a valid JPG or PNG file.',
          DocumentImageQualityIssue.lowResolution =>
            'The photo resolution is low. Small names, plate numbers, and document labels may be difficult to read.',
          DocumentImageQualityIssue.tooDark =>
            'The photo is too dark. Retake it in brighter, even lighting.',
          DocumentImageQualityIssue.overexposed =>
            'The photo is too bright or has glare. Move away from direct light and retake it.',
          DocumentImageQualityIssue.likelyBlurred =>
            'The photo may be blurry. Hold the camera steady and tap the document to focus.',
        };
      })
      .toList(growable: false);
}

Future<DocumentImageQualityAssessment> assessDocumentImageQuality({
  required Uint8List bytes,
  required String fileName,
}) async {
  final extension = fileName.contains('.')
      ? fileName.split('.').last.toLowerCase()
      : '';
  if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
    return const DocumentImageQualityAssessment(
      issues: [],
      width: 0,
      height: 0,
    );
  }

  final result = await compute(_assessImageBytes, bytes);
  final issueIndexes = (result['issues'] as List<Object?>).cast<int>();
  return DocumentImageQualityAssessment(
    issues: issueIndexes
        .map((index) => DocumentImageQualityIssue.values[index])
        .toList(growable: false),
    width: result['width'] as int,
    height: result['height'] as int,
  );
}

Map<String, Object> _assessImageBytes(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return {
      'issues': <int>[DocumentImageQualityIssue.unreadableFile.index],
      'width': 0,
      'height': 0,
    };
  }

  final oriented = img.bakeOrientation(decoded);
  final originalWidth = oriented.width;
  final originalHeight = oriented.height;
  img.Image sample = oriented;
  const sampleLimit = 480;
  if (math.max(sample.width, sample.height) > sampleLimit) {
    sample = sample.width >= sample.height
        ? img.copyResize(
            sample,
            width: sampleLimit,
            interpolation: img.Interpolation.average,
          )
        : img.copyResize(
            sample,
            height: sampleLimit,
            interpolation: img.Interpolation.average,
          );
  }

  final luminance = Uint8List(sample.width * sample.height);
  var luminanceTotal = 0.0;
  var luminanceSquaredTotal = 0.0;
  var darkPixels = 0;
  var brightPixels = 0;
  var offset = 0;
  for (var y = 0; y < sample.height; y++) {
    for (var x = 0; x < sample.width; x++) {
      final pixel = sample.getPixel(x, y);
      final value = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b)
          .round()
          .clamp(0, 255);
      luminance[offset++] = value;
      luminanceTotal += value;
      luminanceSquaredTotal += value * value;
      if (value < 45) darkPixels++;
      if (value > 245) brightPixels++;
    }
  }

  final pixelCount = math.max(1, luminance.length);
  final meanLuminance = luminanceTotal / pixelCount;
  final luminanceVariance =
      (luminanceSquaredTotal / pixelCount) - (meanLuminance * meanLuminance);
  final darkRatio = darkPixels / pixelCount;
  final brightRatio = brightPixels / pixelCount;

  var laplacianTotal = 0.0;
  var laplacianSquaredTotal = 0.0;
  var laplacianCount = 0;
  for (var y = 1; y < sample.height - 1; y++) {
    for (var x = 1; x < sample.width - 1; x++) {
      final center = luminance[(y * sample.width) + x];
      final laplacian =
          (4 * center) -
          luminance[(y * sample.width) + x - 1] -
          luminance[(y * sample.width) + x + 1] -
          luminance[((y - 1) * sample.width) + x] -
          luminance[((y + 1) * sample.width) + x];
      laplacianTotal += laplacian;
      laplacianSquaredTotal += laplacian * laplacian;
      laplacianCount++;
    }
  }
  final laplacianMean = laplacianCount == 0
      ? 0.0
      : laplacianTotal / laplacianCount;
  final sharpnessVariance = laplacianCount == 0
      ? 0.0
      : (laplacianSquaredTotal / laplacianCount) -
            (laplacianMean * laplacianMean);

  final issues = <DocumentImageQualityIssue>[];
  if (math.min(originalWidth, originalHeight) < 600) {
    issues.add(DocumentImageQualityIssue.lowResolution);
  }
  if (meanLuminance < 55 || darkRatio > 0.58) {
    issues.add(DocumentImageQualityIssue.tooDark);
  }
  if (meanLuminance > 238 || brightRatio > 0.72) {
    issues.add(DocumentImageQualityIssue.overexposed);
  }
  // The variance guard prevents a nearly blank page from being described only
  // as blurred; both conditions must indicate a lack of readable edges.
  if (sharpnessVariance < 28 && luminanceVariance < 1800) {
    issues.add(DocumentImageQualityIssue.likelyBlurred);
  }

  return {
    'issues': issues.map((issue) => issue.index).toList(growable: false),
    'width': originalWidth,
    'height': originalHeight,
  };
}
