import 'package:flame/components.dart';

import '../config/game_config.dart';
import 'base_weapon.dart';
import 'projectile_component.dart';
import 'weapon_manager.dart';

class PulseBlaster extends BaseWeapon {
  static const WeaponShootConfig _shootConfig = WeaponShootConfig(
    fireCooldown: GameConfig.autoGunFireCooldown,
    bulletSpeed: GameConfig.autoGunBulletSpeed,
    bulletRange: GameConfig.autoGunBulletRange,
    bulletDamage: GameConfig.autoGunBulletDamage,
    bulletSpawnOffsetX: GameConfig.autoGunBulletSpawnOffsetX,
    bulletSpawnOffsetY: GameConfig.autoGunBulletSpawnOffsetY,
    automatic: true,
    bulletWidth: GameConfig.playerBulletWidth,
    bulletHeight: GameConfig.playerBulletHeight,
  );

  @override
  String get displayName => 'Pulse Blaster';

  @override
  WeaponShootConfig get shootConfig => _shootConfig;

  @override
  void fire(Vector2 position, Vector2 direction, Component parent) {
    final projectile = ProjectileComponent()
      ..position = position
      ..velocity = direction * shootConfig.bulletSpeed
      ..damage = shootConfig.bulletDamage
      ..maxRange = shootConfig.bulletRange
      ..size = Vector2(shootConfig.bulletWidth, shootConfig.bulletHeight)
      ..lifetime = GameConfig.playerProjectileLifetime;
    (parent as WeaponManager).addProjectile(projectile);
  }
}
