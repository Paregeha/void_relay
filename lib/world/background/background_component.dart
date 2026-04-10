import 'dart:ui';

import 'package:flame/components.dart';

class BackgroundComponent extends PositionComponent {
  final Vector2 roomSize;

  double _cameraX = 0.0;

  BackgroundComponent({required this.roomSize}) : super(priority: -1000);

  @override
  Future<void> onLoad() async {
    size = roomSize;
    position = Vector2.zero();
    anchor = Anchor.topLeft;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final game = findGame();
    if (game == null) return;
    _cameraX = game.camera.viewfinder.position.x;
  }

  @override
  void render(Canvas canvas) {
    // Base dark gradient feel with layered parallax strips.
    _drawLayer(
      canvas,
      y: 0,
      height: roomSize.y,
      color: const Color(0xFF0A0F1E),
      parallaxFactor: 0.08,
    );

    _drawLayer(
      canvas,
      y: roomSize.y * 0.18,
      height: roomSize.y * 0.42,
      color: const Color(0xFF111B30),
      parallaxFactor: 0.16,
    );

    _drawLayer(
      canvas,
      y: roomSize.y * 0.40,
      height: roomSize.y * 0.35,
      color: const Color(0xFF1A2740),
      parallaxFactor: 0.24,
    );

    _drawSilhouetteBand(
      canvas,
      y: roomSize.y * 0.62,
      bandHeight: roomSize.y * 0.26,
      color: const Color(0xFF24324E),
      parallaxFactor: 0.30,
      step: 170,
    );

    _drawSilhouetteBand(
      canvas,
      y: roomSize.y * 0.70,
      bandHeight: roomSize.y * 0.24,
      color: const Color(0xFF2A3B5C),
      parallaxFactor: 0.38,
      step: 120,
    );
  }

  void _drawLayer(
    Canvas canvas, {
    required double y,
    required double height,
    required Color color,
    required double parallaxFactor,
  }) {
    final shift = -_cameraX * parallaxFactor;
    final paint = Paint()..color = color;

    canvas.drawRect(
      Rect.fromLTWH(shift - roomSize.x, y, roomSize.x * 3, height),
      paint,
    );
  }

  void _drawSilhouetteBand(
    Canvas canvas, {
    required double y,
    required double bandHeight,
    required Color color,
    required double parallaxFactor,
    required double step,
  }) {
    final shift = -_cameraX * parallaxFactor;
    final paint = Paint()..color = color;

    for (double x = -roomSize.x; x < roomSize.x * 2; x += step) {
      final width = step * 0.65;
      final height = bandHeight * (0.65 + ((x / step).abs() % 3) * 0.12);
      canvas.drawRect(
        Rect.fromLTWH(shift + x, y + (bandHeight - height), width, height),
        paint,
      );
    }
  }
}
