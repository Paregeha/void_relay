import 'package:flame/components.dart';

import '../../config/game_config.dart';

class TurretAI {
  bool isWithinDetectionRange(Vector2 turretPosition, Vector2 playerPosition) {
    return (playerPosition - turretPosition).length <=
        GameConfig.sentryTurretDetectionRange;
  }

  bool canShootStraight(
    Vector2 turretPosition,
    Vector2 playerPosition, {
    required bool facingRight,
    double verticalTolerance = GameConfig.sentryTurretVerticalTolerance,
  }) {
    if (!isWithinDetectionRange(turretPosition, playerPosition)) {
      return false;
    }

    final dx = playerPosition.x - turretPosition.x;
    final dy = (playerPosition.y - turretPosition.y).abs();
    final isPlayerInFront = facingRight ? dx > 0 : dx < 0;
    if (!isPlayerInFront) {
      return false;
    }

    final horizontalDistance = dx.abs();
    return horizontalDistance <= GameConfig.sentryTurretShootingRange &&
        dy <= verticalTolerance;
  }

  bool canShootLeftOnly(Vector2 turretPosition, Vector2 playerPosition) {
    return canShootStraight(turretPosition, playerPosition, facingRight: false);
  }
}
