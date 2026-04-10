import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../flame_game.dart';

class ProjectileComponent extends PositionComponent {
  Vector2 velocity = Vector2.zero();
  double lifetime = GameConfig.playerProjectileLifetime;
  double timeAlive = 0;
  double damage = GameConfig.pulseBlasterDamage;
  bool isAlive = true;

  @override
  Future<void> onLoad() async {
    size = Vector2(8, 8);
    anchor = Anchor.center;
  }

  @override
  void update(double dt) {
    super.update(dt);

    final game = findGame();
    if (game is VoidRelayGame && game.isGameplayInputBlocked) {
      return;
    }

    if (!isAlive) return;

    timeAlive += dt;
    if (timeAlive > lifetime) {
      removeFromParent();
      isAlive = false;
      return;
    }
    position += velocity * dt;
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = const Color(0xFFFFFF00);
    canvas.drawRect(
      Rect.fromCenter(center: Offset(0, 0), width: size.x, height: size.y),
      paint,
    );
  }

  void onHit() {
    if (isAlive) {
      isAlive = false;
      removeFromParent();
    }
  }
}
