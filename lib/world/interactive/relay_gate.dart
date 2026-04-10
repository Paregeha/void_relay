import 'dart:ui';

import 'package:flame/components.dart';

import '../../flame_game.dart';
import '../../player/player_component.dart';

class RelayGate extends PositionComponent {
  static const double _width = 48.0;
  static const double _height = 72.0;

  final PlayerComponent player;
  final void Function()? onReached;

  bool _triggered = false;
  double _pulseTimer = 0;

  RelayGate({required Vector2 position, required this.player, this.onReached})
    : super(
        position: position,
        size: Vector2(_width, _height),
        anchor: Anchor.bottomCenter,
      );

  @override
  void update(double dt) {
    super.update(dt);
    _pulseTimer += dt;
    if (_triggered) return;

    final isOverlapping = toRect().overlaps(player.toRect());
    final game = findGame();
    final isDoorFailureActive =
        game is VoidRelayGame && game.isDoorFailureActive;

    if (isDoorFailureActive) {
      // Під час door failure gate лишається заблокованим.
      return;
    }

    if (isOverlapping) {
      _triggered = true;
      onReached?.call();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final game = findGame();
    final isDoorFailureActive =
        game is VoidRelayGame && game.isDoorFailureActive;

    final t = (_pulseTimer * 2).remainder(2.0);
    final alpha = isDoorFailureActive
        ? 0.95
        : (_triggered
              ? 0.25
              : (t < 1.0 ? 0.5 + t * 0.3 : 0.8 - (t - 1.0) * 0.3));

    // Заливка
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()
        ..color = isDoorFailureActive
            ? Color.fromRGBO(255, 70, 70, 0.28)
            : Color.fromRGBO(0, 255, 160, _triggered ? 0.08 : alpha * 0.25),
    );

    // Рамка
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()
        ..color = isDoorFailureActive
            ? Color.fromRGBO(255, 120, 120, 0.95)
            : (_triggered
                  ? const Color(0xFF224433)
                  : Color.fromRGBO(0, 255, 160, alpha))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    if (isDoorFailureActive) return;

    // Стрілка вправо (якщо не активовано)
    if (!_triggered) {
      final cx = size.x / 2;
      final cy = size.y / 2;
      final arrowPaint = Paint()
        ..color = Color.fromRGBO(0, 255, 160, alpha)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(cx - 10, cy), Offset(cx + 8, cy), arrowPaint);

      final path = Path()
        ..moveTo(cx - 4, cy - 8)
        ..lineTo(cx + 8, cy)
        ..lineTo(cx - 4, cy + 8);
      canvas.drawPath(path, arrowPaint);
    }
  }
}
