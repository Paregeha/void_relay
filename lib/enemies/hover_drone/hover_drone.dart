import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../config/game_config.dart';
import '../../core/utils/safe_asset_loader.dart';
import '../../flame_game.dart';
import '../../player/player_component.dart';
import '../../world/platform/platform_component.dart';
import '../base_enemy.dart';
import '../enemy_manager.dart';
import '../enemy_projectile_component.dart';
import 'hover_drone_ai.dart';

enum HoverDroneAnimState { hover, move, aim, shoot, death }

enum HoverDroneState {
  idleHover,
  patrolHover,
  aim,
  shoot,
  dying,
  falling,
  landed,
}

class HoverDrone extends BaseEnemy {
  static const String _droneSheetPath =
      'assets/sprites/enemies/hover_drone_sheet.png';

  // Real packed frame clips from hover_drone_sheet.png.
  // Row 0: hover(7), Row 1: shoot(7), Row 2: death(4)
  static const List<Rect> _hoverClips = [
    Rect.fromLTWH(75, 118, 168, 110),
    Rect.fromLTWH(282, 119, 163, 109),
    Rect.fromLTWH(479, 118, 167, 109),
    Rect.fromLTWH(680, 119, 162, 109),
    Rect.fromLTWH(874, 117, 172, 110),
    Rect.fromLTWH(1084, 118, 188, 110),
    Rect.fromLTWH(1296, 118, 186, 110),
  ];

  static const List<Rect> _shootClips = [
    Rect.fromLTWH(65, 338, 184, 110),
    Rect.fromLTWH(281, 337, 169, 111),
    Rect.fromLTWH(480, 338, 173, 110),
    Rect.fromLTWH(684, 337, 168, 111),
    Rect.fromLTWH(878, 337, 174, 110),
    Rect.fromLTWH(1083, 337, 179, 110),
    Rect.fromLTWH(1296, 337, 177, 110),
  ];

  static const List<Rect> _deathClips = [
    Rect.fromLTWH(190, 691, 216, 136),
    Rect.fromLTWH(634, 703, 198, 124),
    Rect.fromLTWH(923, 688, 210, 140),
    Rect.fromLTWH(1227, 688, 207, 140),
  ];

  PlayerComponent? player;
  List<PlatformComponent> platforms = const [];
  double floorY = GameConfig.defaultWorldHeight;
  late HoverDroneAI ai;
  HoverDroneAnimState _animState = HoverDroneAnimState.hover;
  HoverDroneState _state = HoverDroneState.idleHover;

  SpriteAnimationGroupComponent<HoverDroneAnimState>? _spriteGroup;
  double _fireCooldown = 0.0;
  double _shootAnimTimer = 0.0;
  double _deathTimer = 0.0;
  double _hoverBobTime = 0.0;

  static const double _shootAnimDuration = 0.16;
  static const double _deathAnimDuration = 0.42;
  static const double _hoverBobAmplitude = 1.6;
  static const double _hoverBobFrequency = 3.6;

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
    final game = findGame();
    if (game is VoidRelayGame && game.isGameplayInputBlocked) {
      return;
    }

    _hoverBobTime += dt;

    if (_isDeathPhase) {
      _updateDeathFall(dt);
      _updateVisualHoverOffset();
      _syncSpriteState();
      return;
    }

    _fireCooldown -= dt;
    if (_shootAnimTimer > 0) {
      _shootAnimTimer -= dt;
    }

    final playerRef = player;
    if (playerRef != null) {
      ai.update(this, playerRef, dt);
    }

    _updateStateFromAi();
    _tryShootAtPlayer();
    _updateAnimationState();
    _updateVisualHoverOffset();
    _syncSpriteState();

    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    // BaseEnemy draws a blue placeholder — skip it when real sprites are loaded.
    if (_spriteGroup == null) {
      super.render(canvas);
    }
  }

  void _updateAnimationState() {
    switch (_state) {
      case HoverDroneState.idleHover:
        _animState = HoverDroneAnimState.hover;
        return;
      case HoverDroneState.patrolHover:
        _animState = HoverDroneAnimState.move;
        return;
      case HoverDroneState.aim:
        _animState = HoverDroneAnimState.aim;
        return;
      case HoverDroneState.shoot:
        _animState = HoverDroneAnimState.shoot;
        return;
      case HoverDroneState.dying:
      case HoverDroneState.falling:
      case HoverDroneState.landed:
        _animState = HoverDroneAnimState.death;
        return;
    }
  }

  void _updateStateFromAi() {
    if (_shootAnimTimer > 0) {
      _state = HoverDroneState.shoot;
      return;
    }

    switch (ai.currentState) {
      case 'patrol':
        _state = HoverDroneState.patrolHover;
        return;
      case 'chase':
        _state = HoverDroneState.aim;
        return;
      default:
        _state = HoverDroneState.idleHover;
    }
  }

  Future<void> _tryInitSpriteAnimation() async {
    final image = await loadUiImageSafe(_droneSheetPath);
    if (image == null) {
      _spriteGroup = null;
      return;
    }

    if (!_clipsFitImageBounds(image, _hoverClips) ||
        !_clipsFitImageBounds(image, _shootClips) ||
        !_clipsFitImageBounds(image, _deathClips)) {
      _spriteGroup = null;
      return;
    }

    final animations = <HoverDroneAnimState, SpriteAnimation>{
      HoverDroneAnimState.hover: _buildClipAnimation(
        image,
        clips: _hoverClips,
        stepTime: 0.11,
      ),
      HoverDroneAnimState.move: _buildClipAnimation(
        image,
        clips: _hoverClips,
        stepTime: 0.1,
      ),
      HoverDroneAnimState.aim: _buildClipAnimation(
        image,
        clips: _hoverClips,
        stepTime: 0.1,
      ),
      HoverDroneAnimState.shoot: _buildClipAnimation(
        image,
        clips: _shootClips,
        stepTime: 0.08,
        loop: false,
      ),
      HoverDroneAnimState.death: _buildClipAnimation(
        image,
        clips: _deathClips,
        stepTime: 0.1,
        loop: false,
      ),
    };

    _spriteGroup = SpriteAnimationGroupComponent<HoverDroneAnimState>(
      animations: animations,
      current: _animState,
      size: size,
      anchor: Anchor.center,
      position: size / 2,
    );
    add(_spriteGroup!);
  }

  void _tryShootAtPlayer() {
    if (_state == HoverDroneState.dying ||
        _state == HoverDroneState.falling ||
        _state == HoverDroneState.landed) {
      return;
    }
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
    _shootAnimTimer = _shootAnimDuration;
    _state = HoverDroneState.shoot;
  }

  @override
  void takeDamage(double damage) {
    if (_state == HoverDroneState.dying ||
        _state == HoverDroneState.falling ||
        _state == HoverDroneState.landed) {
      return;
    }

    health -= damage;
    if (health > 0) {
      return;
    }

    health = 0;
    _state = HoverDroneState.dying;
    _animState = HoverDroneAnimState.death;
    _deathTimer = _deathAnimDuration;
    _shootAnimTimer = 0;
    _fireCooldown = double.infinity;
    velocity.x = 0;
    velocity.y = 0;
  }

  void _syncSpriteState() {
    if (_spriteGroup == null) return;
    _spriteGroup!.current = _animState;
  }

  void _updateVisualHoverOffset() {
    if (_spriteGroup == null) return;
    final yOffset = _isDeathPhase
        ? 0.0
        : math.sin(_hoverBobTime * _hoverBobFrequency) * _hoverBobAmplitude;
    _spriteGroup!.position = Vector2(size.x / 2, size.y / 2 + yOffset);
  }

  bool get _isDeathPhase =>
      _state == HoverDroneState.dying ||
      _state == HoverDroneState.falling ||
      _state == HoverDroneState.landed;

  void _updateDeathFall(double dt) {
    _animState = HoverDroneAnimState.death;
    _shootAnimTimer = 0;
    _fireCooldown = double.infinity;

    if (_state == HoverDroneState.landed) {
      velocity.setZero();
      return;
    }

    _applyGravity(dt);
    super.update(dt);
    _resolveLanding(dt);

    if (_state == HoverDroneState.dying) {
      _deathTimer -= dt;
      if (_deathTimer <= 0) {
        _state = HoverDroneState.falling;
      }
    }
  }

  void _applyGravity(double dt) {
    velocity.y += GameConfig.gravity * dt;
    if (velocity.y > GameConfig.maxFallSpeed) {
      velocity.y = GameConfig.maxFallSpeed;
    }
  }

  void _resolveLanding(double dt) {
    if (velocity.y < 0) return;

    final droneRect = toRect();
    final prevBottom = droneRect.bottom - velocity.y * dt;

    for (final platform in platforms) {
      final platformRect = platform.toRect();
      final horizontalOverlap =
          droneRect.right >
              platformRect.left + GameConfig.platformCollisionTolerance &&
          droneRect.left <
              platformRect.right - GameConfig.platformCollisionTolerance;
      if (!horizontalOverlap) continue;

      final crossedTop =
          prevBottom <=
              platformRect.top + GameConfig.platformCollisionTolerance &&
          droneRect.bottom >= platformRect.top;
      if (!crossedTop) continue;

      position.y = platformRect.top - size.y / 2;
      _setLandedState();
      return;
    }

    if (droneRect.bottom >= floorY) {
      position.y = floorY - size.y / 2;
      _setLandedState();
    }
  }

  void _setLandedState() {
    velocity.setZero();
    _state = HoverDroneState.landed;
  }

  SpriteAnimation _buildClipAnimation(
    Image image, {
    required List<Rect> clips,
    required double stepTime,
    bool loop = true,
  }) {
    final sprites = clips
        .map(
          (clip) => Sprite(
            image,
            srcPosition: Vector2(clip.left, clip.top),
            srcSize: Vector2(clip.width, clip.height),
          ),
        )
        .toList(growable: false);
    return SpriteAnimation.spriteList(sprites, stepTime: stepTime, loop: loop);
  }

  bool _clipsFitImageBounds(Image image, List<Rect> clips) {
    for (final clip in clips) {
      if (clip.left < 0 ||
          clip.top < 0 ||
          clip.right > image.width ||
          clip.bottom > image.height) {
        return false;
      }
    }
    return true;
  }
}
