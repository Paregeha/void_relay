import 'dart:ui';
import 'package:flame/components.dart';

class PlatformComponent extends PositionComponent {
  PlatformComponent({required Vector2 position, required Vector2 size}) {
    this.position = position;
    this.size = size;
    anchor = Anchor.center;
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = const Color(0xFF666666);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
  }
}
