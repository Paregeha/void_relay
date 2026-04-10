import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

final Set<String> _assetLoadErrorsLogged = <String>{};

Future<Image?> loadUiImageSafe(String assetPath) async {
  try {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    // Preferred path: codec decode is more reliable across platforms.
    final codec = await instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  } catch (_) {
    try {
      // Fallback path for environments where codec creation may fail.
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      final completer = Completer<Image>();
      decodeImageFromList(bytes, completer.complete);
      return completer.future;
    } catch (e) {
      if (kDebugMode && _assetLoadErrorsLogged.add(assetPath)) {
        debugPrint('Asset load failed: $assetPath ($e)');
      }
      return null;
    }
  }
}
