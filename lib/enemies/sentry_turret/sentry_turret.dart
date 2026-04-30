import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

import '../../config/game_config.dart';
import '../../core/utils/safe_asset_loader.dart';
import '../../player/player_component.dart';
import '../base_enemy.dart';
import '../enemy_manager.dart';
import '../enemy_projectile_component.dart';
import 'turret_ai.dart';

enum SentryTurretAnimState { idle, alert }

class SentryTurret extends BaseEnemy {
  static const List<String> _turretSheetPaths = [
    'assets/sprites/enemies/sentry_turret_sheet.png',
    'assets/sprites/enemies/turret_sheet.png',
  ];

  PlayerComponent? player;
  late TurretAI ai;

  SentryTurretAnimState _animState = SentryTurretAnimState.idle;
  SpriteAnimationGroupComponent<SentryTurretAnimState>? _spriteGroup;
  double _fireCooldown = 0.0;

  @override
  Future<void> onLoad() async {
    useDefaultMovement = false;
    await super.onLoad();
    size = Vector2(32, 32);
    health = GameConfig.sentryTurretHealth;
    velocity.setZero();
    ai = TurretAI();
    _fireCooldown = GameConfig.sentryTurretFireInterval;
    await _tryInitSpriteAnimation();
  }

  @override
  void update(double dt) {
    _fireCooldown -= dt;
    _updateAiAndAnimation(dt);
    if (_spriteGroup != null) {
      _spriteGroup!.current = _animState;
    }
    _tryShootAtPlayer();
    // Movement is unified in BaseEnemy.update().
    super.update(dt);
  }

  void _updateAiAndAnimation(double dt) {
    final playerRef = player;
    if (playerRef == null) {
      _animState = SentryTurretAnimState.idle;
      return;
    }
    ai.update(this, playerRef, dt);
    _updateAnimationState(playerRef);
  }

  @override
  void render(Canvas canvas) {
    if (_spriteGroup != null) {
      // Rendering is handled by sprite child; avoid placeholder square fallback.
      return;
    }

    // Fallback placeholder: draw a simple turret representation
    final paint = Paint()
      ..color = const Color(0xFFFF8C00)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.fill;

    // Draw base (circle)
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), size.x / 2.5, paint);

    // Draw barrel (line)
    final barrelLength = size.x * 0.6;
    final barrelPaint = Paint()
      ..color = const Color(0xFF666666)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.x / 2, size.y / 2),
      Offset(size.x / 2 + barrelLength, size.y / 2),
      barrelPaint,
    );
  }

  void _updateAnimationState(PlayerComponent playerRef) {
    final distance = (playerRef.position - position).length;
    if (distance < TurretAI.detectionRange) {
      _animState = SentryTurretAnimState.alert;
    } else {
      _animState = SentryTurretAnimState.idle;
    }
  }

  Future<void> _tryInitSpriteAnimation() async {
    final image = await _loadTurretSheet();
    if (image == null) {
      // Fallback: no sprite available, render will be custom placeholder
      if (kDebugMode) {
        debugPrint(
          'SENTRY_TURRET: No sprite sheet available, using placeholder render',
        );
      }
      _spriteGroup = null;
      return;
    }

    final animations = <SentryTurretAnimState, SpriteAnimation>{
      SentryTurretAnimState.idle: SpriteAnimation.fromFrameData(
        image,
        SpriteAnimationData.sequenced(
          amount: 2,
          stepTime: 0.24,
          textureSize: Vector2(32, 32),
          texturePosition: Vector2.zero(),
        ),
      ),
      SentryTurretAnimState.alert: SpriteAnimation.fromFrameData(
        image,
        SpriteAnimationData.sequenced(
          amount: 3,
          stepTime: 0.1,
          textureSize: Vector2(32, 32),
          texturePosition: Vector2(0, 32),
        ),
      ),
    };

    _spriteGroup = SpriteAnimationGroupComponent<SentryTurretAnimState>(
      animations: animations,
      current: _animState,
      size: size,
    );
    add(_spriteGroup!);
  }

  Future<Image?> _loadTurretSheet() async {
    for (final path in _turretSheetPaths) {
      final image = await loadUiImageSafe(path);
      if (image != null) {
        if (kDebugMode) {
          debugPrint('SENTRY_TURRET sprite loaded: $path');
        }
        return image;
      }
    }

    if (kDebugMode) {
      debugPrint(
        'SENTRY_TURRET sprite missing. Expected one of: ${_turretSheetPaths.join(', ')}',
      );
    }
    return null;
  }

  void _tryShootAtPlayer() {
    final playerRef = player;
    if (playerRef == null) return;
    if (_fireCooldown > 0) return;

    final toPlayer = playerRef.position - position;
    if (toPlayer.length > TurretAI.detectionRange || toPlayer.length2 == 0) {
      return;
    }

    final manager = parent;
    if (manager is! EnemyManager) return;

    toPlayer.normalize();
    final projectile = EnemyProjectileComponent()
      ..position = position.clone()
      ..velocity = toPlayer * GameConfig.sentryTurretProjectileSpeed
      ..damage = GameConfig.sentryTurretProjectileDamage
      ..lifetime = GameConfig.sentryTurretProjectileLifetime;

    manager.addProjectile(projectile);
    _fireCooldown = GameConfig.sentryTurretFireInterval;
  }
}
