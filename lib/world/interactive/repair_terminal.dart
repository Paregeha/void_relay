import 'dart:ui';

import 'package:flame/components.dart';

import '../../config/game_config.dart';

class RepairTerminal extends PositionComponent {
  static const double _width = 36.0;
  static const double _height = 52.0;
  static const double _completedVisualDuration = 0.9;

  final double interactionRange;
  final void Function()? onRepairCompleted;

  bool isRepairing = false;
  bool isRepaired = false;

  double _pulseTimer = 0;
  double _repairProgress = 0;
  double _completedTimer = 0;

  RepairTerminal({
    required Vector2 position,
    this.interactionRange = 64,
    this.onRepairCompleted,
  }) : super(
         position: position,
         size: Vector2(_width, _height),
         anchor: Anchor.bottomCenter,
       );

  bool get canStartRepair => !isRepairing && !isRepaired;

  void startRepair() {
    if (!canStartRepair) return;
    isRepairing = true;
    _repairProgress = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _pulseTimer += dt;

    if (isRepaired && !isRepairing) {
      _completedTimer += dt;
      if (_completedTimer >= _completedVisualDuration) {
        isRepaired = false;
        _completedTimer = 0;
        _repairProgress = 0;
      }
    }

    if (!isRepairing) return;

    _repairProgress += dt;
    if (_repairProgress >= GameConfig.doorRepairDuration) {
      isRepairing = false;
      isRepaired = true;
      _completedTimer = 0;
      _repairProgress = GameConfig.doorRepairDuration;
      onRepairCompleted?.call();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final t = (_pulseTimer * 2).remainder(2.0);
    final pulse = t < 1.0 ? 0.55 + t * 0.35 : 0.9 - (t - 1.0) * 0.35;

    final borderColor = isRepaired
        ? Color.fromRGBO(90, 255, 140, 0.95)
        : (isRepairing
              ? Color.fromRGBO(255, 210, 80, pulse)
              : Color.fromRGBO(170, 190, 210, 0.82));

    final coreColor = isRepaired
        ? const Color(0xFF34E07E)
        : (isRepairing ? const Color(0xFFFFC94B) : const Color(0xFF56616E));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = const Color(0xFF111821),
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    canvas.drawRect(
      Rect.fromLTWH(8, 10, size.x - 16, size.y - 24),
      Paint()..color = coreColor,
    );

    final progress = (GameConfig.doorRepairDuration <= 0)
        ? 0.0
        : (_repairProgress / GameConfig.doorRepairDuration).clamp(0.0, 1.0);

    canvas.drawRect(
      Rect.fromLTWH(6, size.y - 10, size.x - 12, 5),
      Paint()..color = const Color(0x445A6878),
    );

    canvas.drawRect(
      Rect.fromLTWH(6, size.y - 10, (size.x - 12) * progress, 5),
      Paint()
        ..color = isRepaired
            ? const Color(0xFF45F58B)
            : const Color(0xFFFFD268),
    );
  }
}
