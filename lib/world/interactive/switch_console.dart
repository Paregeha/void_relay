import 'dart:ui';

import 'package:flame/components.dart';

import '../../player/player_component.dart';

class SwitchConsole extends PositionComponent {
  static const double _width = 34.0;
  static const double _height = 44.0;

  final PlayerComponent player;
  final double interactionRange;
  final void Function(bool isActive)? onToggled;

  bool isActive;
  double _pulseTimer = 0;

  SwitchConsole({
    required Vector2 position,
    required this.player,
    this.interactionRange = 64,
    this.onToggled,
    this.isActive = false,
  }) : super(
         position: position,
         size: Vector2(_width, _height),
         anchor: Anchor.bottomCenter,
       );

  void toggle() {
    isActive = !isActive;
    onToggled?.call(isActive);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _pulseTimer += dt;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final inRange = position.distanceTo(player.position) <= interactionRange;
    final t = (_pulseTimer * 2).remainder(2.0);
    final pulse = t < 1.0 ? 0.6 + t * 0.35 : 0.95 - (t - 1.0) * 0.35;

    final baseColor = isActive
        ? Color.fromRGBO(70, 255, 120, inRange ? pulse : 0.85)
        : Color.fromRGBO(210, 210, 210, inRange ? pulse : 0.75);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = Color.fromRGBO(20, 24, 28, 0.9),
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()
        ..color = baseColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    canvas.drawRect(
      Rect.fromLTWH(8, 9, size.x - 16, size.y - 18),
      Paint()
        ..color = isActive ? const Color(0xFF3DFF76) : const Color(0xFF5D636B),
    );

    if (inRange) {
      canvas.drawCircle(
        Offset(size.x / 2, -6),
        3.5,
        Paint()..color = Color.fromRGBO(120, 220, 255, pulse),
      );
    }
  }
}
