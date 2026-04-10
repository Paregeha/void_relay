import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:void_relay/enemies/base_enemy.dart';
import 'package:void_relay/enemies/crawler/crawler.dart';
import 'package:void_relay/enemies/hover_drone/hover_drone.dart';
import 'package:void_relay/enemies/sentry_turret/sentry_turret.dart';

void main() {
  group('Enemy Movement Consistency Tests', () {
    test('BaseEnemy moves position based on velocity', () async {
      final enemy = BaseEnemy();
      await enemy.onLoad();
      enemy.useDefaultMovement = false;
      enemy.velocity = Vector2(100, 0);

      final initialPos = enemy.position.clone();
      enemy.update(0.1); // 0.1 seconds

      // Position should have moved: position += velocity * dt
      // Expected: (0 + 100*0.1, 0 + 0*0.1) = (10, 0)
      expect(enemy.position.x, closeTo(initialPos.x + 10.0, 0.01));
      expect(enemy.position.y, closeTo(initialPos.y, 0.01));
    });

    test('BaseEnemy applies default movement when enabled', () async {
      final enemy = BaseEnemy();
      await enemy.onLoad();
      expect(enemy.useDefaultMovement, true);
      expect(enemy.defaultSpeedX, -50.0);

      final initialPos = enemy.position.clone();
      enemy.update(0.1);

      // Should move left by 50*0.1 = 5 units
      expect(enemy.position.x, closeTo(initialPos.x - 5.0, 0.01));
    });

    test('Crawler disables default movement', () async {
      final crawler = Crawler();
      await crawler.onLoad();
      expect(crawler.useDefaultMovement, false);
    });

    test('HoverDrone disables default movement', () async {
      final drone = HoverDrone();
      await drone.onLoad();
      expect(drone.useDefaultMovement, false);
    });

    test('SentryTurret disables default movement and is stationary', () async {
      final turret = SentryTurret();
      await turret.onLoad();
      expect(turret.useDefaultMovement, false);

      final initialPos = turret.position.clone();
      turret.update(0.1);

      // Position should not change (velocity is zero)
      expect(turret.position.x, closeTo(initialPos.x, 0.01));
      expect(turret.position.y, closeTo(initialPos.y, 0.01));
    });

    test('Enemy velocity accumulation over multiple frames', () async {
      final enemy = BaseEnemy();
      await enemy.onLoad();
      enemy.useDefaultMovement = false;
      enemy.velocity = Vector2(50, 20);

      final initialPos = enemy.position.clone();

      // Simulate 5 frames of 0.016 seconds each (~60 fps)
      for (int i = 0; i < 5; i++) {
        enemy.update(0.016);
      }

      final totalTime = 0.016 * 5; // 0.08 seconds
      final expectedX = initialPos.x + (50 * totalTime);
      final expectedY = initialPos.y + (20 * totalTime);

      expect(enemy.position.x, closeTo(expectedX, 0.1));
      expect(enemy.position.y, closeTo(expectedY, 0.1));
    });

    test('Enemy health and damage system', () {
      final enemy = BaseEnemy();
      expect(enemy.health, 100.0);

      enemy.takeDamage(30.0);
      expect(enemy.health, 70.0);

      enemy.takeDamage(70.0);
      expect(enemy.health, 0.0);
    });

    test('BaseEnemy velocity zero maintains position', () async {
      final enemy = BaseEnemy();
      await enemy.onLoad();
      enemy.useDefaultMovement = false;
      enemy.velocity = Vector2.zero();

      final initialPos = enemy.position.clone();
      enemy.update(0.1);

      expect(enemy.position.x, closeTo(initialPos.x, 0.01));
      expect(enemy.position.y, closeTo(initialPos.y, 0.01));
    });

    test('Enemy movement is frame-time independent', () async {
      // Create two enemies
      final enemy1 = BaseEnemy();
      final enemy2 = BaseEnemy();

      await enemy1.onLoad();
      await enemy2.onLoad();

      enemy1.useDefaultMovement = false;
      enemy2.useDefaultMovement = false;

      enemy1.velocity = Vector2(100, 0);
      enemy2.velocity = Vector2(100, 0);

      // Simulate enemy1 with 2 frames of 0.05s
      enemy1.update(0.05);
      enemy1.update(0.05);

      // Simulate enemy2 with 1 frame of 0.1s
      enemy2.update(0.1);

      // Both should end up at the same position
      expect(enemy1.position.x, closeTo(enemy2.position.x, 0.01));
    });
  });
}
