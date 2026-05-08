import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

import '../enemies/base_enemy.dart';
import '../enemies/basic_enemy/basic_enemy_component.dart';
import '../enemies/basic_enemy/enemy_config.dart';
import '../enemies/enemy_manager.dart';
import '../enemies/sentry_turret/sentry_turret.dart';
import '../flame_game.dart';
import '../player/player_component.dart';
import '../sound_assets.dart';
import 'base_weapon.dart';
import 'projectile_component.dart';

class WeaponManager extends Component {
  static const int projectileRenderPriority = 200;
  static const bool _debugPlayerShootSpawnLogs = false;

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
  String? _lastBlockedShootReason;
  final List<ProjectileComponent> _projectilesToRemove =
      <ProjectileComponent>[];

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
    if (held != _triggerHeld && owner is PlayerComponent) {
      final player = owner as PlayerComponent;
      final action = held ? 'pressed' : 'released';
      if (false)
        print('[PlayerShoot] $action weapon=${player.currentWeapon.name}');
      if (!held) {
        _lastBlockedShootReason = null;
      }
    }
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

    final weapon = _resolveActiveWeapon();
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

    final manager = enemyManager;
    if (manager != null) {
      _projectilesToRemove.clear();

      for (var projectile in projectiles) {
        if (!projectile.isAlive) {
          _projectilesToRemove.add(projectile);
          continue;
        }

        if (!projectile.isMounted) {
          if (projectile.hasMountedOnce) {
            _projectilesToRemove.add(projectile);
          }
          continue;
        }

        final bulletRect = projectile.sweptWorldRect;

        for (var enemy in manager.enemies) {
          if (!enemy.isMounted) continue;
          if (enemy.health <= 0) continue;
          final enemyRect = enemy is Enemy3Component
              ? enemy.worldHitboxRect
              : enemy is SentryTurret
              ? enemy.worldHitboxRect
              : enemy.toRect();

          if (bulletRect.overlaps(enemyRect)) {
            enemy.takeDamage(projectile.damage);
            if (enemy is Enemy3Component && Enemy3Config.debugLogs) {
              enemy3Log('Enemy3 hitbox=$enemyRect bulletRect=$bulletRect');
            }
            projectile.onHit();
            final game = findGame();
            if (game is VoidRelayGame) {
              game.playSfx(SoundAssets.hit);
              game.spawnHitSpark(projectile.absolutePosition);
            }
            _projectilesToRemove.add(projectile);
            break;
          }
        }
      }

      for (var projectile in _projectilesToRemove) {
        removeProjectile(projectile);
      }
    }
  }

  void _tryFireOnce() {
    final weapon = _resolveActiveWeapon();
    if (weapon == null || owner is! PlayerComponent) return;

    final player = owner as PlayerComponent;
    if (_fireCooldown > 0) {
      _logBlockedShoot(reason: 'cooldown', player: player);
      return;
    }

    final blockedReason = _blockedShootReason(player);
    if (blockedReason != null) {
      _logBlockedShoot(reason: blockedReason, player: player);
      return;
    }

    final direction = player.facingDirection;
    final shootConfig = weapon.shootConfig;

    // Muzzle point in player's local space (near weapon tip)
    final localMuzzle = Vector2(
      direction * shootConfig.bulletSpawnOffsetX,
      shootConfig.bulletSpawnOffsetY,
    );

    // Start with horizontal direction and apply light aim assist.
    final baseDir = Vector2(direction.toDouble(), 0);
    final aimDir = _applyAimAssist(baseDir, player.absolutePosition);

    final projectileCountBefore = projectiles.length;
    weapon.fire(localMuzzle, aimDir, this);
    final didSpawnProjectile = projectiles.length > projectileCountBefore;
    if (!didSpawnProjectile) {
      _logBlockedShoot(reason: 'spawn_failed', player: player);
      return;
    }

    _fireCooldown = weapon.fireInterval;
    _lastBlockedShootReason = null;

    final spawnWorld = player.absolutePosition + localMuzzle;
    if (_debugPlayerShootSpawnLogs) {
      debugPrint(
        '[PlayerShoot] spawn=$spawnWorld '
        'weapon=${player.currentWeapon.name} '
        'offsetY=${shootConfig.bulletSpawnOffsetY}',
      );
    }
    final bulletDirectionX = aimDir.x;
    final isFlipped = bulletDirectionX < 0;
    if (false)
      print(
        '[PlayerShoot] bullet spawned weapon=${player.currentWeapon.name} '
        'directionX=${bulletDirectionX.toStringAsFixed(2)} '
        'isFlipped=$isFlipped '
        'pos=(${spawnWorld.x.toStringAsFixed(1)},${spawnWorld.y.toStringAsFixed(1)}) '
        'speed=${shootConfig.bulletSpeed.toStringAsFixed(1)} '
        'range=${shootConfig.bulletRange.toStringAsFixed(1)} '
        'damage=${shootConfig.bulletDamage.toStringAsFixed(1)}',
      );

    final game = findGame();
    if (game is VoidRelayGame) {
      game.playBlasterShotSound();
    }
  }

  BaseWeapon? _resolveActiveWeapon() {
    if (_loadout.isEmpty) return null;
    if (owner is! PlayerComponent) {
      return currentWeapon;
    }

    final player = owner as PlayerComponent;
    final wantAutomatic = player.currentWeapon == WeaponType.autoGun;

    for (final weapon in _loadout) {
      if (weapon.isAutomatic == wantAutomatic) {
        return weapon;
      }
    }

    return currentWeapon;
  }

  String? _blockedShootReason(PlayerComponent player) {
    if (!player.isAlive ||
        player.currentAnimState == PlayerAnimState.death ||
        player.isDead) {
      return 'death';
    }

    if (!player.isOnGround) {
      return player.currentAnimState == PlayerAnimState.jump
          ? 'jumping'
          : 'not_grounded';
    }

    if (player.currentAnimState != PlayerAnimState.idle &&
        player.currentAnimState != PlayerAnimState.run) {
      return 'state_${player.currentAnimState.name}';
    }

    return null;
  }

  void _logBlockedShoot({
    required String reason,
    required PlayerComponent player,
  }) {
    if (_lastBlockedShootReason == reason) return;
    _lastBlockedShootReason = reason;
    if (false)
      print(
        '[PlayerShoot] blocked reason=$reason '
        'weapon=${player.currentWeapon.name} '
        'anim=${player.currentAnimState.name} '
        'grounded=${player.isOnGround} cooldown=${_fireCooldown.toStringAsFixed(2)}',
      );
  }

  Vector2 _applyAimAssist(Vector2 baseDir, Vector2 shooterWorldPos) {
    final manager = enemyManager;
    if (manager == null) return baseDir;

    BaseEnemyTarget? nearest;

    for (final enemy in manager.enemies) {
      if (!enemy.isMounted) continue;
      final aimTarget = _enemyAimTarget(enemy);
      final toEnemy = aimTarget - shooterWorldPos;
      final dist = toEnemy.length;
      if (dist <= 0 || dist > _aimAssistRange) continue;

      final norm = toEnemy / dist;
      // Only assist roughly in front of the player
      if (norm.dot(baseDir) < 0.4) continue;

      if (nearest == null || dist < nearest.distance) {
        nearest = BaseEnemyTarget(aimTarget, dist);
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

  Vector2 _enemyAimTarget(BaseEnemy enemy) {
    if (enemy is Enemy3Component) {
      final rect = enemy.worldHitboxRect;
      return Vector2(rect.center.dx, rect.center.dy);
    }
    if (enemy is SentryTurret) {
      final rect = enemy.worldHitboxRect;
      return Vector2(rect.center.dx, rect.center.dy);
    }

    final rect = enemy.toRect();
    return Vector2(rect.center.dx, rect.center.dy);
  }

  void addProjectile(ProjectileComponent projectile) {
    final parentComponent = owner.parent;

    // Convert local spawn position from player-space to world-space.
    if (owner is PositionComponent) {
      final player = owner as PositionComponent;
      projectile.position = player.absolutePosition + projectile.position;
    }

    projectile.priority = projectileRenderPriority;
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
