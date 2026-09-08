import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

const int _maxDocumentImageDimension = 1600;
const int _secondaryDocumentImageDimension = 1200;
const int _documentJpegQuality = 74;
const int _minimumDocumentJpegQuality = 62;
const int _targetDocumentImageBytes = 500 * 1024;

class OptimizedDocumentImage {
  const OptimizedDocumentImage({
    required this.bytes,
    required this.wasOptimized,
    required this.fileName,
  });

  final Uint8List bytes;
  final bool wasOptimized;
  final String fileName;
}

Future<OptimizedDocumentImage> optimizeDocumentImage({
  required Uint8List bytes,
  required String fileName,
}) async {
  final String extension = fileName.contains('.')
      ? fileName.split('.').last.toLowerCase()
      : '';

  if (!const {'jpg', 'jpeg', 'png'}.contains(extension)) {
    return OptimizedDocumentImage(
      bytes: bytes,
      wasOptimized: false,
      fileName: fileName,
    );
  }

  final result = await compute(_optimizeImageBytes, {
    'bytes': bytes,
    'extension': extension,
  });
  final optimizedBytes = result['bytes'] as Uint8List;

  return OptimizedDocumentImage(
    bytes: optimizedBytes,
    wasOptimized: result['wasOptimized'] as bool,
    fileName: result['encodedAsJpeg'] as bool
        ? _withJpegExtension(fileName)
        : fileName,
  );
}

String _withJpegExtension(String fileName) {
  final dotIndex = fileName.lastIndexOf('.');
  final baseName = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
  return '$baseName.jpg';
}

Map<String, Object> _optimizeImageBytes(Map<String, Object> request) {
  final originalBytes = request['bytes'] as Uint8List;
  final extension = request['extension'] as String;
  final decoded = img.decodeImage(originalBytes);

  if (decoded == null) {
    return {
      'bytes': originalBytes,
      'wasOptimized': false,
      'encodedAsJpeg': false,
    };
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

  final bool convertPngToJpeg =
      extension == 'png' &&
      (originalBytes.length > _targetDocumentImageBytes ||
          largestDimension > _maxDocumentImageDimension);

  Uint8List candidateBytes;
  bool encodedAsJpeg = extension != 'png' || convertPngToJpeg;

  if (encodedAsJpeg) {
    var quality = _documentJpegQuality;
    candidateBytes = img.encodeJpg(optimizedImage, quality: quality);

    while (candidateBytes.length > _targetDocumentImageBytes &&
        quality > _minimumDocumentJpegQuality) {
      quality -= 4;
      candidateBytes = img.encodeJpg(optimizedImage, quality: quality);
    }

    if (candidateBytes.length > _targetDocumentImageBytes &&
        (optimizedImage.width > _secondaryDocumentImageDimension ||
            optimizedImage.height > _secondaryDocumentImageDimension)) {
      if (optimizedImage.width >= optimizedImage.height) {
        optimizedImage = img.copyResize(
          optimizedImage,
          width: _secondaryDocumentImageDimension,
          interpolation: img.Interpolation.average,
        );
      } else {
        optimizedImage = img.copyResize(
          optimizedImage,
          height: _secondaryDocumentImageDimension,
          interpolation: img.Interpolation.average,
        );
      }
      candidateBytes = img.encodeJpg(
        optimizedImage,
        quality: _minimumDocumentJpegQuality,
      );
    }
  } else {
    candidateBytes = img.encodePng(optimizedImage, level: 9);
  }

  if (candidateBytes.length >= originalBytes.length) {
    return {
      'bytes': originalBytes,
      'wasOptimized': false,
      'encodedAsJpeg': false,
    };
  }

  return {
    'bytes': candidateBytes,
    'wasOptimized': true,
    'encodedAsJpeg': encodedAsJpeg,
  };
}
