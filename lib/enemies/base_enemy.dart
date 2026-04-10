import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../flame_game.dart';

class BaseEnemy extends PositionComponent {
  Vector2 velocity = Vector2.zero();
  double health = GameConfig.baseEnemyHealth;
  bool useDefaultMovement = true;
  double defaultSpeedX = GameConfig.enemyDefaultSpeedX;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Single unified position update path for all enemies.
    anchor = Anchor.center;
    if (useDefaultMovement) {
      velocity.x = defaultSpeedX;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final game = findGame();
    if (game is VoidRelayGame && game.isGameplayInputBlocked) {
      return;
    }
    if (useDefaultMovement) {
      velocity.x = defaultSpeedX;
    }
    // Unified enemy movement integration path.
    position += velocity * dt;
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = const Color(0xFF0000FF);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
  }

  void takeDamage(double damage) {
    health -= damage;
    if (health <= 0) {
      removeFromParent();
    }
  }

  void onPlayerDetected() {
    // Hook for future logic
  }
}
