import 'dart:ui';

import 'package:flame/components.dart';

import '../../config/game_config.dart';
import '../../core/utils/safe_asset_loader.dart';
import '../../player/player_component.dart';
import '../base_enemy.dart';
import '../enemy_manager.dart';
import '../enemy_projectile_component.dart';
import 'hover_drone_ai.dart';

enum HoverDroneAnimState { idle, patrol, chase }

class HoverDrone extends BaseEnemy {
  PlayerComponent? player;
  late HoverDroneAI ai;
  HoverDroneAnimState _animState = HoverDroneAnimState.idle;
  double _animTime = 0;
  SpriteAnimationGroupComponent<HoverDroneAnimState>? _spriteGroup;
  double _fireCooldown = 0.0;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    size = Vector2(24, 24);
    useDefaultMovement = false;
    health = GameConfig.hoverDroneHealth;
    ai = HoverDroneAI();
    _fireCooldown = GameConfig.hoverDroneFireInterval;
    await _tryInitSpriteAnimation();
  }

  @override
  void update(double dt) {
    _animTime += dt;
    _fireCooldown -= dt;
    // AI updates velocity based on game state
    if (player != null) {
      ai.update(this, player!, dt);
    }
    // Animation state is updated from current velocity/AI state
    _updateAnimationState();
    if (_spriteGroup != null) {
      _spriteGroup!.current = _animState;
    }
    _tryShootAtPlayer();
    // Single unified position update via super.update()
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    if (_spriteGroup != null) {
      return;
    }
    final paint = Paint()..color = _resolvePlaceholderColor();
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
  }

  void _updateAnimationState() {
    switch (ai.currentState) {
      case 'patrol':
        _animState = HoverDroneAnimState.patrol;
        return;
      case 'chase':
        _animState = HoverDroneAnimState.chase;
        return;
      default:
        _animState = HoverDroneAnimState.idle;
    }
  }

  Color _resolvePlaceholderColor() {
    switch (_animState) {
      case HoverDroneAnimState.idle:
        return const Color(0xFFCC55CC);
      case HoverDroneAnimState.patrol:
        return _animTime % 0.24 < 0.12
            ? const Color(0xFFFF66FF)
            : const Color(0xFFDD55DD);
      case HoverDroneAnimState.chase:
        return const Color(0xFFFF33AA);
    }
  }

  Future<void> _tryInitSpriteAnimation() async {
    final image = await loadUiImageSafe(
      'assets/sprites/enemies/hover_drone_sheet.png',
    );
    if (image == null) {
      _spriteGroup = null;
      return;
    }

    final animations = <HoverDroneAnimState, SpriteAnimation>{
      HoverDroneAnimState.idle: SpriteAnimation.fromFrameData(
        image,
        SpriteAnimationData.sequenced(
          amount: 2,
          stepTime: 0.2,
          textureSize: Vector2(24, 24),
          texturePosition: Vector2.zero(),
        ),
      ),
      HoverDroneAnimState.patrol: SpriteAnimation.fromFrameData(
        image,
        SpriteAnimationData.sequenced(
          amount: 4,
          stepTime: 0.1,
          textureSize: Vector2(24, 24),
          texturePosition: Vector2(0, 24),
        ),
      ),
      HoverDroneAnimState.chase: SpriteAnimation.fromFrameData(
        image,
        SpriteAnimationData.sequenced(
          amount: 3,
          stepTime: 0.08,
          textureSize: Vector2(24, 24),
          texturePosition: Vector2(0, 48),
        ),
      ),
    };

    _spriteGroup = SpriteAnimationGroupComponent<HoverDroneAnimState>(
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

    if (ai.currentState != 'chase') return;

    final manager = parent;
    if (manager is! EnemyManager) return;

    final dir = playerRef.position - position;
    if (dir.length2 == 0) return;
    dir.normalize();

    final projectile = EnemyProjectileComponent()
      ..position = position.clone()
      ..velocity = dir * GameConfig.hoverDroneProjectileSpeed
      ..damage = GameConfig.hoverDroneProjectileDamage
      ..lifetime = GameConfig.hoverDroneProjectileLifetime;

    manager.addProjectile(projectile);
    _fireCooldown = GameConfig.hoverDroneFireInterval;
  }
}
