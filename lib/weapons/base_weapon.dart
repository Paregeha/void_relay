import 'package:flame/components.dart';

abstract class BaseWeapon {
  String get displayName;

  /// true => fires while trigger is held, false => one shot per press.
  bool get isAutomatic;

  /// Minimum time between shots in seconds.
  double get fireInterval;

  void fire(Vector2 position, Vector2 direction, Component parent);
}
