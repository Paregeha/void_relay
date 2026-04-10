import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:void_relay/player/player_component.dart';
import 'package:void_relay/systems/collision_handler.dart';
import 'package:void_relay/world/platform/platform_component.dart';

void main() {
  group('Player-platform collision regression', () {
    test('lands on floor after deep downward step (no tunneling)', () async {
      final player = PlayerComponent();
      await player.onLoad();

      final floor = PlatformComponent(
        position: Vector2(480, 490),
        size: Vector2(960, 100),
      );

      // Simulate a frame where player moved deep into the floor while falling.
      player.position = Vector2(200, 468); // bottom = 500
      player.velocity = Vector2(0, 500);
      player.isOnGround = false;

      final collisions = CollisionHandler(player: player, platforms: [floor]);
      collisions.update(0.2);

      expect(player.position.y, closeTo(408, 0.001));
      expect(player.velocity.y, closeTo(0, 0.001));
      expect(player.isOnGround, isTrue);
    });

    test('corrects player that starts slightly embedded from above', () async {
      final player = PlayerComponent();
      await player.onLoad();

      final floor = PlatformComponent(
        position: Vector2(480, 490),
        size: Vector2(960, 100),
      );

      // Spawn-like case: player center is too low and intersects floor.
      player.position = Vector2(120, 420); // bottom = 452 (> floor top 440)
      player.velocity = Vector2.zero();
      player.isOnGround = false;

      final collisions = CollisionHandler(player: player, platforms: [floor]);
      collisions.update(1 / 60);

      expect(player.position.y, closeTo(408, 0.001));
      expect(player.velocity.y, closeTo(0, 0.001));
      expect(player.isOnGround, isTrue);
    });

    test('blocks jump into ceiling and resets upward velocity', () async {
      final player = PlayerComponent();
      await player.onLoad();

      final ceiling = PlatformComponent(
        position: Vector2(480, 10),
        size: Vector2(960, 20),
      );

      // Player top enters the ceiling from below during an upward frame.
      player.position = Vector2(240, 30); // top = -2
      player.velocity = Vector2(0, -320);
      player.isOnGround = false;

      final collisions = CollisionHandler(player: player, platforms: [ceiling]);
      collisions.update(0.1);

      // Ceiling bottom is y=20; player center must be pushed to 52 (20 + 32).
      expect(player.position.y, closeTo(52, 0.001));
      expect(player.velocity.y, closeTo(0, 0.001));
      expect(player.isOnGround, isFalse);
    });

    test('side contact with platform edge does not snap player on Y', () async {
      final player = PlayerComponent();
      await player.onLoad();

      final lowPlatform = PlatformComponent(
        position: Vector2(290, 440),
        size: Vector2(180, 24),
      );

      // Player runs into the platform side near its top edge.
      // Before fix this could trigger embeddedFromAbove and snap Y.
      player.position = Vector2(194, 408); // bottom = 440, top = 376
      player.velocity = Vector2(200, 0);
      player.isOnGround = true;

      final collisions = CollisionHandler(
        player: player,
        platforms: [lowPlatform],
      );
      collisions.update(1 / 60);

      expect(player.position.y, closeTo(408, 0.001));
      expect(player.velocity.y, closeTo(0, 0.001));
    });

    test('moving into platform side blocks horizontal movement', () async {
      final player = PlayerComponent();
      await player.onLoad();

      final platform = PlatformComponent(
        position: Vector2(290, 440),
        size: Vector2(180, 24),
      );

      // Post-move state: player entered platform from the left side.
      player.position = Vector2(189, 408); // right = 205, side at x=200
      player.velocity = Vector2(400, 0);
      player.isOnGround = true;

      final collisions = CollisionHandler(
        player: player,
        platforms: [platform],
      );
      collisions.update(1 / 60);

      expect(player.position.x, closeTo(183.9, 0.001));
      expect(player.velocity.x, closeTo(0, 0.001));
      expect(player.position.y, closeTo(408, 0.001));
    });

    test(
      'partially embedded side contact is clamped and does not pass through',
      () async {
        final player = PlayerComponent();
        await player.onLoad();

        final platform = PlatformComponent(
          position: Vector2(290, 440),
          size: Vector2(180, 24),
        );

        // Already a bit inside platform side after movement integration.
        player.position = Vector2(214, 408); // left = 198, right = 230
        player.velocity = Vector2(180, 0);
        player.isOnGround = true;

        final collisions = CollisionHandler(
          player: player,
          platforms: [platform],
        );
        collisions.update(1 / 60);

        expect(player.position.x, closeTo(183.9, 0.001));
        expect(player.velocity.x, closeTo(0, 0.001));
        expect(player.position.y, closeTo(408, 0.001));
      },
    );

    test('holding movement into side stays stable without jitter', () async {
      final player = PlayerComponent();
      await player.onLoad();

      final platform = PlatformComponent(
        position: Vector2(290, 440),
        size: Vector2(180, 24),
      );

      final collisions = CollisionHandler(
        player: player,
        platforms: [platform],
      );

      player.position = Vector2(183.9, 408);
      player.isOnGround = true;

      for (var i = 0; i < 20; i++) {
        // Simulate controller that keeps pushing right every frame.
        player.velocity = Vector2(220, 0);
        player.position += player.velocity * (1 / 60);
        collisions.update(1 / 60);
      }

      expect(player.position.x, closeTo(183.9, 0.02));
      expect(player.position.y, closeTo(408, 0.001));
      expect(player.velocity.x, closeTo(0, 0.001));
    });
  });
}
