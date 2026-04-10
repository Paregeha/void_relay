import 'package:flame/components.dart';

import '../config/game_config.dart';
import 'base_weapon.dart';
import 'projectile_component.dart';
import 'weapon_manager.dart';

class PulseBlaster extends BaseWeapon {
  @override
  String get displayName => 'Pulse Blaster';

  @override
  bool get isAutomatic => true;

  @override
  double get fireInterval => GameConfig.pulseBlasterFireInterval;

  @override
  void fire(Vector2 position, Vector2 direction, Component parent) {
    final projectile = ProjectileComponent()
      ..position = position
      ..velocity = direction * GameConfig.pulseBlasterSpeed
      ..damage = GameConfig.pulseBlasterDamage
      ..lifetime = GameConfig.playerProjectileLifetime;
    (parent as WeaponManager).addProjectile(projectile);
  }
}
