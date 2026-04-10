import 'package:flame/components.dart';

import '../config/game_config.dart';
import 'base_weapon.dart';
import 'projectile_component.dart';
import 'weapon_manager.dart';

class BeamCutter extends BaseWeapon {
  @override
  String get displayName => 'Beam Cutter';

  @override
  bool get isAutomatic => false;

  @override
  double get fireInterval => GameConfig.beamCutterFireInterval;

  @override
  void fire(Vector2 position, Vector2 direction, Component parent) {
    final projectile = ProjectileComponent()
      ..position = position
      ..velocity = direction * GameConfig.beamCutterSpeed
      ..damage = GameConfig.beamCutterDamage
      ..lifetime = GameConfig.beamCutterLifetime;
    (parent as WeaponManager).addProjectile(projectile);
  }
}
