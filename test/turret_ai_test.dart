import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:void_relay/config/game_config.dart';
import 'package:void_relay/enemies/sentry_turret/turret_ai.dart';

void main() {
  group('TurretAI straight shooting', () {
    final ai = TurretAI();

    test('does not detect player outside detection range', () {
      final turret = Vector2(500, 200);
      final player = Vector2(
        500 - (GameConfig.sentryTurretDetectionRange + 10),
        200,
      );

      expect(ai.isWithinDetectionRange(turret, player), isFalse);
      expect(ai.canShootStraight(turret, player, facingRight: false), isFalse);
      expect(ai.canShootLeftOnly(turret, player), isFalse);
    });

    test('shoots only when player is on the left within ranges', () {
      final turret = Vector2(500, 200);
      final player = Vector2(
        500 - (GameConfig.sentryTurretShootingRange - 20),
        200 + (GameConfig.sentryTurretVerticalTolerance - 10),
      );

      expect(ai.isWithinDetectionRange(turret, player), isTrue);
      expect(ai.canShootStraight(turret, player, facingRight: false), isTrue);
      expect(ai.canShootLeftOnly(turret, player), isTrue);
    });

    test('does not shoot when player is on the right', () {
      final turret = Vector2(500, 200);
      final player = Vector2(560, 200);

      expect(ai.canShootStraight(turret, player, facingRight: false), isFalse);
      expect(ai.canShootLeftOnly(turret, player), isFalse);
    });

    test('does not shoot when vertical tolerance is exceeded', () {
      final turret = Vector2(500, 200);
      final player = Vector2(
        500 - (GameConfig.sentryTurretShootingRange - 20),
        200 + GameConfig.sentryTurretVerticalTolerance + 1,
      );

      expect(ai.canShootStraight(turret, player, facingRight: false), isFalse);
      expect(ai.canShootLeftOnly(turret, player), isFalse);
    });

    test('right-facing turret shoots only to the right', () {
      final turret = Vector2(500, 200);
      final playerRight = Vector2(560, 200);
      final playerLeft = Vector2(440, 200);

      expect(
        ai.canShootStraight(turret, playerRight, facingRight: true),
        isTrue,
      );
      expect(
        ai.canShootStraight(turret, playerLeft, facingRight: true),
        isFalse,
      );
    });
  });
}
