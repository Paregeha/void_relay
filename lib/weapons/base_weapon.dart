import 'package:flame/components.dart';

class WeaponShootConfig {
  const WeaponShootConfig({
    required this.fireCooldown,
    required this.bulletSpeed,
    required this.bulletRange,
    required this.bulletDamage,
    required this.bulletSpawnOffsetX,
    required this.bulletSpawnOffsetY,
    required this.automatic,
    required this.bulletWidth,
    required this.bulletHeight,
  });

  final double fireCooldown;
  final double bulletSpeed;
  final double bulletRange;
  final double bulletDamage;
  final double bulletSpawnOffsetX;
  final double bulletSpawnOffsetY;
  final bool automatic;
  final double bulletWidth;
  final double bulletHeight;
}

abstract class BaseWeapon {
  String get displayName;

  WeaponShootConfig get shootConfig;

  /// true => fires while trigger is held, false => one shot per press.
  bool get isAutomatic => shootConfig.automatic;

  /// Minimum time between shots in seconds.
  double get fireInterval => shootConfig.fireCooldown;

  void fire(Vector2 position, Vector2 direction, Component parent);
}
