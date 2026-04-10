import 'dart:ui';

import 'package:flame/components.dart';

import '../../config/game_config.dart';
import '../../core/utils/safe_asset_loader.dart';
import '../../player/player_component.dart';
import '../base_enemy.dart';
import '../enemy_manager.dart';
import '../enemy_projectile_component.dart';
import 'turret_ai.dart';

enum SentryTurretAnimState { idle, alert }

class SentryTurret extends BaseEnemy {
  PlayerComponent? player;
  late TurretAI ai;

  SentryTurretAnimState _animState = SentryTurretAnimState.idle;
  double _animTime = 0;
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
    _animTime += dt;
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
    super.render(canvas);
    if (_spriteGroup == null) {
      final paint = Paint()..color = _resolvePlaceholderColor();
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
    }
  }

  void _updateAnimationState(PlayerComponent playerRef) {
    final distance = (playerRef.position - position).length;
    if (distance < TurretAI.detectionRange) {
      _animState = SentryTurretAnimState.alert;
    } else {
      _animState = SentryTurretAnimState.idle;
    }
  }

  Color _resolvePlaceholderColor() {
    switch (_animState) {
      case SentryTurretAnimState.idle:
        return const Color(0xFFCCCC44);
      case SentryTurretAnimState.alert:
        return _animTime % 0.2 < 0.1
            ? const Color(0xFFFFFF66)
            : const Color(0xFFFFAA33);
    }
  }

  Future<void> _tryInitSpriteAnimation() async {
    final image = await loadUiImageSafe(
      'assets/sprites/enemies/sentry_turret_sheet.png',
    );
    if (image == null) {
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
