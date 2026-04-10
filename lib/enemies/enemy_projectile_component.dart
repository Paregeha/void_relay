import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../flame_game.dart';

class EnemyProjectileComponent extends PositionComponent {
  Vector2 velocity = Vector2.zero();
  double lifetime = GameConfig.enemyProjectileLifetime;
  double timeAlive = 0;
  double damage = GameConfig.enemyProjectileDamage;
  bool isAlive = true;

  @override
  Future<void> onLoad() async {
    size = Vector2(6, 6);
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
      onHit();
      return;
    }

    position += velocity * dt;
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = const Color(0xFFFF4444);
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y),
      paint,
    );
  }

  void onHit() {
    if (!isAlive) return;
    isAlive = false;
    removeFromParent();
  }
}
