import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/debug/render_trace.dart';
import '../../player/player_component.dart';

class PlatformComponent extends PositionComponent {
  PlatformComponent({required Vector2 position, required Vector2 size}) {
    this.position = position;
    this.size = size;
    anchor = Anchor.center;
  }

  @override
  void render(Canvas canvas) {
    if (PlayerComponent.debugTraceRenderSequence) {
      RenderTrace.log(
        'Platform.render priority=$priority pos=$position size=$size',
      );
    }
    if (PlayerComponent.debugHideLevelGeometry) {
      return;
    }

    final paint = Paint()..color = const Color(0xFF666666);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);

    if (PlayerComponent.debugDrawCollision) {
      final platformRectPaint = Paint()
        ..color = const Color(0xFF3399FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final platformTopPaint = Paint()
        ..color = const Color(0xFF00FF00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final rect = Rect.fromLTWH(0, 0, size.x, size.y);
      canvas.drawRect(rect, platformRectPaint);
      canvas.drawLine(Offset(0, 0), Offset(size.x, 0), platformTopPaint);
    }
  }
}
