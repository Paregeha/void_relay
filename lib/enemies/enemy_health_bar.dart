import 'dart:ui';

import 'package:flame/components.dart';

class EnemyHealthBar {
  static void render(
    Canvas canvas, {
    required double left,
    required double top,
    required double width,
    required double hp,
    required double maxHp,
    double height = 5.0,
  }) {
    if (maxHp <= 0 || width <= 0 || height <= 0) return;

    final ratio = (hp / maxHp).clamp(0.0, 1.0);

    final background = Rect.fromLTWH(left, top, width, height);
    final fill = Rect.fromLTWH(left, top, width * ratio, height);

    Color fillColor;
    if (ratio > 0.6) {
      fillColor = const Color(0xFF00C853);
    } else if (ratio > 0.3) {
      fillColor = const Color(0xFFFFD600);
    } else {
      fillColor = const Color(0xFFD50000);
    }

    canvas.drawRect(background, Paint()..color = const Color(0xB3000000));
    canvas.drawRect(fill, Paint()..color = fillColor);
    canvas.drawRect(
      background,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xCC000000),
    );
  }
}
