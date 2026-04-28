import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

final Set<String> _assetLoadErrorsLogged = <String>{};

Future<Image?> loadUiImageSafe(String assetPath) async {
  final normalizedPath = _normalizeAssetPath(assetPath);
  try {
    final data = await rootBundle.load(normalizedPath);
    final bytes = data.buffer.asUint8List();
    // Preferred path: codec decode is more reliable across platforms.
    final codec = await instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  } catch (_) {
    try {
      // Fallback path for environments where codec creation may fail.
      final data = await rootBundle.load(normalizedPath);
      final bytes = data.buffer.asUint8List();
      final completer = Completer<Image>();
      decodeImageFromList(bytes, completer.complete);
      return completer.future;
    } catch (e) {
      if (kDebugMode && _assetLoadErrorsLogged.add(normalizedPath)) {
        debugPrint('Asset load failed: $normalizedPath ($e)');
      }
      return null;
    }
  }
}

String _normalizeAssetPath(String rawPath) {
  var path = rawPath.trim().replaceAll('\\', '/');
  while (path.contains('//')) {
    path = path.replaceAll('//', '/');
  }

  // Guard against accidental double prefix like assets/assets/sprites/...
  if (path.startsWith('assets/assets/')) {
    path = path.replaceFirst('assets/assets/', 'assets/');
  }
  return path;
}
