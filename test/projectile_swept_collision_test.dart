import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:void_relay/weapons/projectile_component.dart';

void main() {
  group('Projectile swept collision', () {
    test('sweptWorldRect covers previous and current world rects', () {
      final projectile = ProjectileComponent()
        ..size = Vector2(10, 4)
        ..position = Vector2.zero()
        ..velocity = Vector2(100, 0)
        ..lifetime = 10
        ..maxRange = 1000;

      projectile.update(0.1);

      final rect = projectile.sweptWorldRect;
      expect(rect.left, closeTo(-5, 0.0001));
      expect(rect.right, closeTo(15, 0.0001));
      expect(rect.top, closeTo(-2, 0.0001));
      expect(rect.bottom, closeTo(2, 0.0001));
    });
  });
}
