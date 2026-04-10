import 'dart:ui';

import 'package:flame/components.dart';

import '../../config/game_config.dart';
import '../../flame_game.dart';
import '../../player/player_component.dart';
import '../../sound_assets.dart';

class CoolingStation extends PositionComponent {
  static const double _width = 40.0;
  static const double _height = 56.0;

  final PlayerComponent player;
  bool _used = false;

  CoolingStation({required Vector2 position, required this.player})
    : super(
        position: position,
        size: Vector2(_width, _height),
        anchor: Anchor.bottomCenter,
      );

  @override
  void update(double dt) {
    super.update(dt);
    if (_used) return;
    if (toRect().overlaps(player.toRect())) {
      _used = true;
      final game = findGame();
      if (game is VoidRelayGame) {
        game.heatSystem?.coolHeat(GameConfig.coolingStationHeatReduce);
        game.playSfx(SoundAssets.cooling);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final baseColor = _used ? const Color(0xFF444455) : const Color(0xFF2266CC);
    final rimColor = _used ? const Color(0xFF667788) : const Color(0xFF00CCFF);

    // Тіло станції
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = baseColor,
    );

    // Рамка
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()
        ..color = rimColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    if (!_used) {
      // Сніжинкоподібний хрестик
      final cx = size.x / 2;
      final cy = size.y / 2;
      const r = 9.0;
      final iconPaint = Paint()
        ..color = const Color(0xFFAADDFF)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      canvas.drawLine(Offset(cx - r, cy), Offset(cx + r, cy), iconPaint);
      canvas.drawLine(Offset(cx, cy - r), Offset(cx, cy + r), iconPaint);
      final d = r * 0.65;
      canvas.drawLine(
        Offset(cx - d, cy - d),
        Offset(cx + d, cy + d),
        iconPaint,
      );
      canvas.drawLine(
        Offset(cx + d, cy - d),
        Offset(cx - d, cy + d),
        iconPaint,
      );
    }
  }
}
