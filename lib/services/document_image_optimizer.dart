import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

const int _maxDocumentImageDimension = 2048;
const int _documentJpegQuality = 82;

class OptimizedDocumentImage {
  const OptimizedDocumentImage({
    required this.bytes,
    required this.wasOptimized,
  });

  final Uint8List bytes;
  final bool wasOptimized;
}

Future<OptimizedDocumentImage> optimizeDocumentImage({
  required Uint8List bytes,
  required String fileName,
}) async {
  final String extension = fileName.contains('.')
      ? fileName.split('.').last.toLowerCase()
      : '';

  if (!const {'jpg', 'jpeg', 'png'}.contains(extension)) {
    return OptimizedDocumentImage(bytes: bytes, wasOptimized: false);
  }

  final result = await compute(_optimizeImageBytes, {
    'bytes': bytes,
    'extension': extension,
  });
  final optimizedBytes = result['bytes'] as Uint8List;

  return OptimizedDocumentImage(
    bytes: optimizedBytes,
    wasOptimized: result['wasOptimized'] as bool,
  );
}

Map<String, Object> _optimizeImageBytes(Map<String, Object> request) {
  final originalBytes = request['bytes'] as Uint8List;
  final extension = request['extension'] as String;
  final decoded = img.decodeImage(originalBytes);

  if (decoded == null) {
    return {'bytes': originalBytes, 'wasOptimized': false};
  }

  img.Image optimizedImage = img.bakeOrientation(decoded);
  final int largestDimension = optimizedImage.width > optimizedImage.height
      ? optimizedImage.width
      : optimizedImage.height;

  if (largestDimension > _maxDocumentImageDimension) {
    if (optimizedImage.width >= optimizedImage.height) {
      optimizedImage = img.copyResize(
        optimizedImage,
        width: _maxDocumentImageDimension,
        interpolation: img.Interpolation.average,
      );
    } else {
      optimizedImage = img.copyResize(
        optimizedImage,
        height: _maxDocumentImageDimension,
        interpolation: img.Interpolation.average,
      );
    }
  }

  final Uint8List candidateBytes = extension == 'png'
      ? img.encodePng(optimizedImage, level: 7)
      : img.encodeJpg(optimizedImage, quality: _documentJpegQuality);

  if (candidateBytes.length >= originalBytes.length) {
    return {'bytes': originalBytes, 'wasOptimized': false};
  }

  return {'bytes': candidateBytes, 'wasOptimized': true};
}
