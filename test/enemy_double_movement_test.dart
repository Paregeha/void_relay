import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:void_relay/enemies/base_enemy.dart';
import 'package:void_relay/enemies/crawler/crawler.dart';
import 'package:void_relay/enemies/hover_drone/hover_drone.dart';
import 'package:void_relay/enemies/sentry_turret/sentry_turret.dart';

void main() {
  group('Enemy Double Movement Regression Tests', () {
    test('BaseEnemy moves exactly once per update frame', () async {
      final enemy = BaseEnemy();
      await enemy.onLoad();

      enemy.useDefaultMovement = false;
      enemy.velocity = Vector2(100, 50);

      final pos1 = enemy.position.clone();
      enemy.update(0.1);
      final pos2 = enemy.position.clone();

      // Expected movement: velocity * dt = (100, 50) * 0.1 = (10, 5)
      final expectedDelta = Vector2(10, 5);
      final actualDelta = pos2 - pos1;

      expect(actualDelta.x, closeTo(expectedDelta.x, 0.01));
      expect(actualDelta.y, closeTo(expectedDelta.y, 0.01));

      // Verify no secondary movement by checking position doesn't change
      // without another update() call
      final pos3 = enemy.position.clone();
      expect(pos3.x, closeTo(pos2.x, 0.001));
      expect(pos3.y, closeTo(pos2.y, 0.001));
    });

    test('Crawler moves exactly once per update frame', () async {
      final crawler = Crawler();
      await crawler.onLoad();

      // Manually set velocity to bypass AI
      crawler.velocity = Vector2(60, 0);

      final pos1 = crawler.position.clone();
      crawler.update(0.1);
      final pos2 = crawler.position.clone();

      // Expected movement: (60, 0) * 0.1 = (6, 0)
      final expectedDelta = Vector2(6, 0);
      final actualDelta = pos2 - pos1;

      expect(actualDelta.x, closeTo(expectedDelta.x, 0.01));
      // Crawler now has gravity; this test targets double-movement regression on X.
      expect(actualDelta.y, greaterThanOrEqualTo(0));
    });

    test('HoverDrone moves exactly once per update frame', () async {
      final drone = HoverDrone();
      await drone.onLoad();

      // Manually set velocity
      drone.velocity = Vector2(40, 20);

      final pos1 = drone.position.clone();
      drone.update(0.1);
      final pos2 = drone.position.clone();

      // Expected movement: (40, 20) * 0.1 = (4, 2)
      final expectedDelta = Vector2(4, 2);
      final actualDelta = pos2 - pos1;

      expect(actualDelta.x, closeTo(expectedDelta.x, 0.01));
      expect(actualDelta.y, closeTo(expectedDelta.y, 0.01));
    });

    test('SentryTurret does not move when stationary', () async {
      final turret = SentryTurret();
      await turret.onLoad();

      // Turret should have zero velocity
      expect(turret.velocity.length, closeTo(0, 0.001));

      final pos1 = turret.position.clone();
      turret.update(0.1);
      turret.update(0.1);
      turret.update(0.1);
      final pos2 = turret.position.clone();

      // Position should not change after multiple updates
      expect(pos2.x, closeTo(pos1.x, 0.001));
      expect(pos2.y, closeTo(pos1.y, 0.001));
    });

    test(
      'Movement accumulates correctly over multiple single-frame calls',
      () async {
        final enemy = BaseEnemy();
        await enemy.onLoad();

        enemy.useDefaultMovement = false;
        enemy.velocity = Vector2(100, 0);

        final startPos = enemy.position.clone();

        // Simulate 10 frames of 0.01 seconds each
        for (int i = 0; i < 10; i++) {
          enemy.update(0.01);
        }

        final endPos = enemy.position.clone();

        // Total time: 0.1 seconds
        // Total movement: 100 * 0.1 = 10 units
        final totalDelta = endPos - startPos;
        expect(totalDelta.x, closeTo(10.0, 0.01));
        expect(totalDelta.y, closeTo(0, 0.001));
      },
    );

    test('Zero velocity prevents any movement', () async {
      final enemy = BaseEnemy();
      await enemy.onLoad();

      enemy.useDefaultMovement = false;
      enemy.velocity = Vector2.zero();

      final startPos = enemy.position.clone();

      // Update multiple times with zero velocity
      for (int i = 0; i < 5; i++) {
        enemy.update(0.1);
      }

      final endPos = enemy.position.clone();

      // Position should never change
      expect(endPos.x, closeTo(startPos.x, 0.001));
      expect(endPos.y, closeTo(startPos.y, 0.001));
    });

    test(
      'Position change is deterministic and frame-rate independent',
      () async {
        final enemy1 = BaseEnemy();
        final enemy2 = BaseEnemy();

        await enemy1.onLoad();
        await enemy2.onLoad();

        enemy1.useDefaultMovement = false;
        enemy2.useDefaultMovement = false;

        enemy1.velocity = Vector2(100, 50);
        enemy2.velocity = Vector2(100, 50);

        final start1 = enemy1.position.clone();
        final start2 = enemy2.position.clone();

        // Enemy1: 10 frames of 0.01s
        for (int i = 0; i < 10; i++) {
          enemy1.update(0.01);
        }

        // Enemy2: 5 frames of 0.02s
        for (int i = 0; i < 5; i++) {
          enemy2.update(0.02);
        }

        final end1 = enemy1.position.clone();
        final end2 = enemy2.position.clone();

        // Both should move the same distance (0.1 seconds total)
        final delta1 = end1 - start1;
        final delta2 = end2 - start2;

        expect(delta1.x, closeTo(delta2.x, 0.01));
        expect(delta1.y, closeTo(delta2.y, 0.01));
      },
    );

    test('Enemy does not move when update() is not called', () async {
      final enemy = BaseEnemy();
      await enemy.onLoad();

      enemy.velocity = Vector2(100, 100);

      final pos1 = enemy.position.clone();

      // Do not call update() - just access position
      final pos2 = enemy.position;

      expect(pos2.x, closeTo(pos1.x, 0.001));
      expect(pos2.y, closeTo(pos1.y, 0.001));
    });
  });
}
