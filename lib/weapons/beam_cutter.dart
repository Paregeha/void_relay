import 'package:flame/components.dart';

import '../config/game_config.dart';
import 'base_weapon.dart';
import 'projectile_component.dart';
import 'weapon_manager.dart';

class BeamCutter extends BaseWeapon {
  static const WeaponShootConfig _shootConfig = WeaponShootConfig(
    fireCooldown: GameConfig.sniperGunFireCooldown,
    bulletSpeed: GameConfig.sniperGunBulletSpeed,
    bulletRange: GameConfig.sniperGunBulletRange,
    bulletDamage: GameConfig.sniperGunBulletDamage,
    bulletSpawnOffsetX: GameConfig.sniperGunBulletSpawnOffsetX,
    bulletSpawnOffsetY: GameConfig.sniperGunBulletSpawnOffsetY,
    automatic: false,
    bulletWidth: GameConfig.playerBulletWidth,
    bulletHeight: GameConfig.playerBulletHeight,
  );

  @override
  String get displayName => 'Beam Cutter';

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
      ..lifetime = GameConfig.beamCutterLifetime;
    (parent as WeaponManager).addProjectile(projectile);
  }
}
