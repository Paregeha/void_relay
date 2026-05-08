import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../flame_game.dart';

/// Blackout overlay with a soft spotlight centered on the player.
class BlackoutSpotlightOverlay extends StatefulWidget {
  const BlackoutSpotlightOverlay({
    super.key,
    required this.game,
    required this.opacity,
  });

  final VoidRelayGame game;
  final double opacity;

  @override
  State<BlackoutSpotlightOverlay> createState() =>
      _BlackoutSpotlightOverlayState();
}

class _BlackoutSpotlightOverlayState extends State<BlackoutSpotlightOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flickerController;

  @override
  void initState() {
    super.initState();
    _flickerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _flickerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _flickerController,
        builder: (context, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: _BlackoutSpotlightPainter(
              game: widget.game,
              opacity: widget.opacity,
              flickerT: _flickerController.value,
            ),
          );
        },
      ),
    );
  }
}

class _BlackoutSpotlightPainter extends CustomPainter {
  const _BlackoutSpotlightPainter({
    required this.game,
    required this.opacity,
    required this.flickerT,
  });

  final VoidRelayGame game;
  final double opacity;
  final double flickerT;

  static const double _baseRadius = 120.0;
  static const double _centerYOffset = -14.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final darkness = opacity.clamp(0.94, 1.0);
    final center = _resolvePlayerScreenCenter(size);
    if (center == null) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.black.withValues(alpha: darkness),
      );
      return;
    }

    final flicker = math.sin(flickerT * math.pi * 2) * 4.0;
    final radius = (_baseRadius + flicker).clamp(90.0, 140.0);

    canvas.saveLayer(Offset.zero & size, Paint());

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black.withValues(alpha: darkness),
    );

    final holePaint = Paint()
      ..blendMode = BlendMode.dstOut
      ..shader = ui.Gradient.radial(
        center,
        radius,
        const [Color(0xFFFFFFFF), Color(0xCCFFFFFF), Color(0x00000000)],
        const [0.0, 0.45, 1.0],
      );

    canvas.drawCircle(center, radius, holePaint);
    canvas.restore();
  }

  Offset? _resolvePlayerScreenCenter(Size screenSize) {
    final world = game.gameWorld;
    final player = world?.player;
    if (player == null) return null;

    final visibleWorldRect = game.camera.visibleWorldRect;
    if (visibleWorldRect.width <= 0 || visibleWorldRect.height <= 0) {
      return null;
    }

    final playerWorldX = player.position.x;
    final playerWorldY = player.position.y;

    final normalizedX =
        (playerWorldX - visibleWorldRect.left) / visibleWorldRect.width;
    final normalizedY =
        (playerWorldY - visibleWorldRect.top) / visibleWorldRect.height;

    final screenX = (normalizedX * screenSize.width).clamp(
      0.0,
      screenSize.width,
    );
    final screenY = (normalizedY * screenSize.height + _centerYOffset).clamp(
      0.0,
      screenSize.height,
    );

    return Offset(screenX, screenY);
  }

  @override
  bool shouldRepaint(covariant _BlackoutSpotlightPainter oldDelegate) {
    return oldDelegate.opacity != opacity || oldDelegate.flickerT != flickerT;
  }
}
