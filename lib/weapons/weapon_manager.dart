import 'dart:math' as math;

import 'package:flame/components.dart';

import '../enemies/enemy_manager.dart';
import '../flame_game.dart';
import '../player/player_component.dart';
import '../sound_assets.dart';
import 'base_weapon.dart';
import 'projectile_component.dart';

class WeaponManager extends Component {
  final Component owner;
  final List<BaseWeapon> _loadout = [];
  int _currentWeaponIndex = 0;
  List<ProjectileComponent> projectiles = [];
  EnemyManager? enemyManager;

  // Mild aim assist tuning (not 100% lock-on)
  static const double _aimAssistRange = 220.0;
  static const double _aimAssistBlend = 0.35;
  static const double _aimAssistInaccuracyRadians = 0.08;
  static final math.Random _random = math.Random();

  bool _triggerHeld = false;
  bool _triggerHeldPrevFrame = false;
  double _fireCooldown = 0.0;

  WeaponManager(this.owner);

  BaseWeapon? get currentWeapon {
    if (_loadout.isEmpty) return null;
    if (_currentWeaponIndex < 0 || _currentWeaponIndex >= _loadout.length) {
      _currentWeaponIndex = 0;
    }
    return _loadout[_currentWeaponIndex];
  }

  String get currentWeaponName => currentWeapon?.displayName ?? 'Unknown';

  int get currentWeaponSlot => _currentWeaponIndex + 1;

  int get loadoutSize => _loadout.length;

  BaseWeapon? get secondaryWeapon {
    if (_loadout.length < 2) return null;
    final secondaryIndex = (_currentWeaponIndex + 1) % _loadout.length;
    return _loadout[secondaryIndex];
  }

  String get secondaryWeaponName => secondaryWeapon?.displayName ?? '-';

  int? get secondaryWeaponSlot {
    if (_loadout.length < 2) return null;
    return ((_currentWeaponIndex + 1) % _loadout.length) + 1;
  }

  List<BaseWeapon> get loadoutWeapons =>
      List<BaseWeapon>.unmodifiable(_loadout);

  void setLoadout(List<BaseWeapon> weapons, {int initialIndex = 0}) {
    _loadout
      ..clear()
      ..addAll(weapons);
    if (_loadout.isEmpty) {
      _currentWeaponIndex = 0;
    } else {
      _currentWeaponIndex = initialIndex.clamp(0, _loadout.length - 1);
    }
    _fireCooldown = 0.0;
  }

  void setWeapon(BaseWeapon weapon) {
    setLoadout([weapon]);
  }

  void switchToNextWeapon() {
    if (_loadout.length <= 1) return;
    _currentWeaponIndex = (_currentWeaponIndex + 1) % _loadout.length;
    _fireCooldown = 0.0;
  }

  void switchToPreviousWeapon() {
    if (_loadout.length <= 1) return;
    _currentWeaponIndex = (_currentWeaponIndex - 1) % _loadout.length;
    if (_currentWeaponIndex < 0) {
      _currentWeaponIndex = _loadout.length - 1;
    }
    _fireCooldown = 0.0;
  }

  void switchToWeaponSlot(int slotIndex) {
    if (slotIndex < 0 || slotIndex >= _loadout.length) return;
    if (_currentWeaponIndex == slotIndex) return;
    _currentWeaponIndex = slotIndex;
    _fireCooldown = 0.0;
  }

  void setEnemyManager(EnemyManager em) {
    enemyManager = em;
  }

  /// Backward-compatible immediate fire call.
  void fire() {
    _tryFireOnce();
  }

  void setTriggerHeld(bool held) {
    _triggerHeld = held;
  }

  @override
  void update(double dt) {
    super.update(dt);

    final game = findGame();
    if (game is VoidRelayGame && game.isGameplayInputBlocked) {
      _triggerHeld = false;
      _triggerHeldPrevFrame = false;
      return;
    }

    if (_fireCooldown > 0) {
      _fireCooldown -= dt;
    }

    final weapon = currentWeapon;
    if (weapon != null) {
      final justPressed = _triggerHeld && !_triggerHeldPrevFrame;

      if (weapon.isAutomatic) {
        if (_triggerHeld && _fireCooldown <= 0) {
          _tryFireOnce();
        }
      } else {
        // Semi-auto: one shot per press.
        if (justPressed && _fireCooldown <= 0) {
          _tryFireOnce();
        }
      }
    }

    _triggerHeldPrevFrame = _triggerHeld;

    if (enemyManager != null) {
      final projectilesToRemove = <ProjectileComponent>[];

      for (var projectile in projectiles) {
        if (!projectile.isAlive || !projectile.isMounted) continue;

        for (var enemy in enemyManager!.enemies) {
          if (!enemy.isMounted) continue;
          if (projectile.toRect().overlaps(enemy.toRect())) {
            enemy.takeDamage(projectile.damage);
            projectile.onHit();
            final game = findGame();
            if (game is VoidRelayGame) {
              game.playSfx(SoundAssets.hit);
              game.spawnHitSpark(projectile.absolutePosition);
            }
            projectilesToRemove.add(projectile);
            break;
          }
        }
      }

      for (var projectile in projectilesToRemove) {
        removeProjectile(projectile);
      }
    }
  }

  void _tryFireOnce() {
    final weapon = currentWeapon;
    if (weapon == null || owner is! PlayerComponent) return;

    final player = owner as PlayerComponent;
    final direction = player.facingDirection;

    // Muzzle point in player's local space (near weapon tip)
    final localMuzzle = Vector2(direction * 20.0, -8.0);

    // Start with horizontal direction and apply light aim assist.
    final baseDir = Vector2(direction.toDouble(), 0);
    final aimDir = _applyAimAssist(baseDir, player.absolutePosition);

    weapon.fire(localMuzzle, aimDir, this);
    _fireCooldown = weapon.fireInterval;

    final game = findGame();
    if (game is VoidRelayGame) {
      game.playSfx(SoundAssets.shot);
    }
  }

  Vector2 _applyAimAssist(Vector2 baseDir, Vector2 shooterWorldPos) {
    final manager = enemyManager;
    if (manager == null) return baseDir;

    BaseEnemyTarget? nearest;

    for (final enemy in manager.enemies) {
      if (!enemy.isMounted) continue;
      final toEnemy = enemy.absolutePosition - shooterWorldPos;
      final dist = toEnemy.length;
      if (dist <= 0 || dist > _aimAssistRange) continue;

      final norm = toEnemy / dist;
      // Only assist roughly in front of the player
      if (norm.dot(baseDir) < 0.4) continue;

      if (nearest == null || dist < nearest.distance) {
        nearest = BaseEnemyTarget(enemy.absolutePosition, dist);
      }
    }

    if (nearest == null) return baseDir;

    final targetDir = (nearest.position - shooterWorldPos)..normalize();
    final mixed = Vector2(
      baseDir.x * (1 - _aimAssistBlend) + targetDir.x * _aimAssistBlend,
      baseDir.y * (1 - _aimAssistBlend) + targetDir.y * _aimAssistBlend,
    )..normalize();

    // Add slight random spread so it is never perfect lock-on.
    final angle = math.atan2(mixed.y, mixed.x);
    final spread = (_random.nextDouble() * 2 - 1) * _aimAssistInaccuracyRadians;
    final finalAngle = angle + spread;

    return Vector2(math.cos(finalAngle), math.sin(finalAngle));
  }

  void addProjectile(ProjectileComponent projectile) {
    final parentComponent = owner.parent;

    // Convert local spawn position from player-space to world-space.
    if (owner is PositionComponent) {
      final player = owner as PositionComponent;
      projectile.position = player.absolutePosition + projectile.position;
    }

    projectiles.add(projectile);

    // Projectiles must live in world space, not as child of player.
    if (parentComponent != null) {
      parentComponent.add(projectile);
    } else {
      add(projectile);
    }
  }

  void removeProjectile(ProjectileComponent projectile) {
    projectiles.remove(projectile);
    if (projectile.isMounted) {
      projectile.removeFromParent();
    }
  }

  void clearProjectiles() {
    for (var p in projectiles) {
      if (p.isMounted) {
        p.removeFromParent();
      }
    }
    projectiles.clear();
  }
}

class BaseEnemyTarget {
  final Vector2 position;
  final double distance;

  BaseEnemyTarget(this.position, this.distance);
}
