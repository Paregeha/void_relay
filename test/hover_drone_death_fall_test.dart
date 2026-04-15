import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:void_relay/enemies/hover_drone/hover_drone.dart';
import 'package:void_relay/world/platform/platform_component.dart';

void main() {
  group('HoverDrone death fall behavior', () {
    test('drone starts falling under gravity after death', () async {
      final drone = HoverDrone();
      await drone.onLoad();
      drone.position = Vector2(120, 80);
      drone.floorY = 400;

      final startY = drone.position.y;
      drone.takeDamage(999);
      drone.update(0.1);

      expect(drone.health, 0);
      expect(drone.position.y, greaterThan(startY));
      expect(drone.velocity.y, greaterThan(0));
    });

    test('drone lands on platform and remains as wreck', () async {
      final drone = HoverDrone();
      await drone.onLoad();
      drone.position = Vector2(100, 40);
      drone.floorY = 500;
      drone.platforms = [
        PlatformComponent(position: Vector2(100, 160), size: Vector2(220, 20)),
      ];

      drone.takeDamage(999);

      for (var i = 0; i < 120; i++) {
        drone.update(1 / 60);
      }

      const expectedPlatformTop = 150.0; // centerY(160) - halfHeight(10)
      const expectedDroneCenterY =
          expectedPlatformTop - 12.0; // half drone size
      expect(drone.position.y, closeTo(expectedDroneCenterY, 0.1));
      expect(drone.velocity.y, 0);

      final landedY = drone.position.y;
      drone.update(0.5);
      expect(drone.position.y, closeTo(landedY, 0.001));
      expect(drone.velocity.y, 0);
    });
  });
}
