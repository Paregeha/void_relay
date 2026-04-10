import 'package:flutter_test/flutter_test.dart';
import 'package:void_relay/enemies/base_enemy.dart';
import 'package:void_relay/weapons/projectile_component.dart';

class _SpyEnemy extends BaseEnemy {
  bool removeTriggered = false;

  @override
  void removeFromParent() {
    // Keep test independent from Flame tree/mount state.
    removeTriggered = true;
  }
}

void main() {
  group('Projectile -> Enemy integration regression', () {
    test('projectile hit reduces enemy HP', () {
      final enemy = _SpyEnemy()..health = 40.0;
      final projectile = ProjectileComponent()..damage = 12.0;

      enemy.takeDamage(projectile.damage);

      expect(enemy.health, closeTo(28.0, 0.0001));
      expect(enemy.removeTriggered, isFalse);
    });

    test('enemy is removed when HP reaches zero', () {
      final enemy = _SpyEnemy()..health = 10.0;
      final projectile = ProjectileComponent()..damage = 10.0;

      enemy.takeDamage(projectile.damage);

      expect(enemy.health, lessThanOrEqualTo(0.0));
      expect(enemy.removeTriggered, isTrue);
    });
  });
}
