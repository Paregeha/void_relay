import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../config/game_config.dart';
import '../../core/utils/safe_asset_loader.dart';
import '../../flame_game.dart';
import '../../player/player_component.dart';
import '../../world/platform/platform_component.dart';
import '../base_enemy.dart';
import '../enemy_projectile_component.dart';
import 'hover_drone_ai.dart';

enum HoverDroneAnimState { hover, move, aim, shoot, death }

enum DroneAnimationState { idle, fly, shoot }

enum DroneMoveDirection { left, right }

enum HoverDroneState {
  idleHover,
  patrolHover,
  aim,
  shoot,
  dying,
  falling,
  landed,
}

class _DroneAtlasFrame {
  const _DroneAtlasFrame({required this.frameIndex, required this.src});

  final int frameIndex;
  final Rect src;
}

class _DroneAtlasBundle {
  const _DroneAtlasBundle({
    required this.imagePath,
    required this.atlasPath,
    required this.image,
    required this.frames,
  });

  final String imagePath;
  final String atlasPath;
  final Image image;
  final List<_DroneAtlasFrame> frames;

  double get canonicalWidth {
    if (frames.isEmpty) return 0;
    return frames.map((f) => f.src.width).reduce((a, b) => a > b ? a : b);
  }

  double get canonicalHeight {
    if (frames.isEmpty) return 0;
    return frames.map((f) => f.src.height).reduce((a, b) => a > b ? a : b);
  }

  double get baseAspectRatio {
    if (frames.isEmpty) return 1.0;
    final first = frames.first.src;
    if (first.height <= 0) return 1.0;
    return first.width / first.height;
  }
}

class _DroneAtlasParseResult {
  const _DroneAtlasParseResult({
    required this.frames,
    required this.maxSrcBoundX,
    required this.maxSrcBoundY,
  });

  final List<_DroneAtlasFrame> frames;
  final double maxSrcBoundX;
  final double maxSrcBoundY;
}

class _DroneAnimationRenderer extends PositionComponent {
  _DroneAnimationRenderer({
    required this.bundle,
    required this.stepTimes,
    required this.loops,
    required this.hitboxSize,
    required this.baseAspectRatio,
    required this.desiredVisualWidth,
    required this.debugFrameVisualOffsets,
    required HoverDroneAnimState initialState,
  }) : _state = initialState;

  final _DroneAtlasBundle bundle;
  final Map<HoverDroneAnimState, double> stepTimes;
  final Map<HoverDroneAnimState, bool> loops;
  final Vector2 hitboxSize;
  final double baseAspectRatio;
  final double desiredVisualWidth;
  final Map<int, Offset> debugFrameVisualOffsets;

  HoverDroneAnimState _state;
  int _autoFrameIndex = 0;
  int _manualFrameIndex = 0;
  double _frameTimer = 0;
  bool _manualFrameMode = false;
  bool _flipX = false;

  void setState(HoverDroneAnimState next) {
    if (_state == next) return;
    _state = next;
    _autoFrameIndex = 0;
    if (!_manualFrameMode) {
      _manualFrameIndex = 0;
    }
    _frameTimer = 0;
  }

  void stepFrame(int delta) {
    final frames = bundle.frames;
    if (frames.isEmpty || delta == 0) return;

    _manualFrameMode = true;
    final length = frames.length;
    var next = (_manualFrameIndex + delta) % length;
    if (next < 0) {
      next += length;
    }
    _manualFrameIndex = next;
    _frameTimer = 0;
  }

  _DroneAtlasFrame? get currentFrame {
    final frames = bundle.frames;
    if (frames.isEmpty) return null;
    final frameIndex = _manualFrameMode ? _manualFrameIndex : _autoFrameIndex;
    return frames[frameIndex.clamp(0, frames.length - 1)];
  }

  Rect get currentVisualRectLocal {
    final frame = currentFrame;
    if (frame == null) {
      final fallbackHeight =
          desiredVisualWidth / (baseAspectRatio <= 0 ? 1.0 : baseAspectRatio);
      return Rect.fromCenter(
        center: Offset(size.x / 2, size.y / 2),
        width: desiredVisualWidth,
        height: fallbackHeight,
      );
    }
    final aspectRatio = baseAspectRatio <= 0 ? 1.0 : baseAspectRatio;
    final visualHeight = desiredVisualWidth / aspectRatio;
    final perFrameOffset =
        debugFrameVisualOffsets[frame.frameIndex] ?? Offset.zero;
    return Rect.fromCenter(
      center: Offset(size.x / 2, size.y / 2) + perFrameOffset,
      width: desiredVisualWidth,
      height: visualHeight,
    );
  }

  void setFlipX(bool value) {
    _flipX = value;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Renderer local space is the drone hitbox; sprite is drawn into separate visual rect.
    size = hitboxSize.clone();
  }

  @override
  void update(double dt) {
    final frames = bundle.frames;
    if (frames.isEmpty) return;
    if (_manualFrameMode) return;

    final stepTime = stepTimes[_state] ?? 0.1;
    if (stepTime <= 0) return;

    _frameTimer += dt;
    while (_frameTimer >= stepTime) {
      _frameTimer -= stepTime;
      final loop = loops[_state] ?? true;
      if (loop) {
        _autoFrameIndex = (_autoFrameIndex + 1) % frames.length;
      } else if (_autoFrameIndex < frames.length - 1) {
        _autoFrameIndex += 1;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final frame = currentFrame;
    if (frame == null) return;
    final sourceRect = frame.src;
    final renderRect = currentVisualRectLocal;

    final paint = Paint()
      ..isAntiAlias = false
      ..filterQuality = FilterQuality.none;

    if (_flipX) {
      canvas.save();
      canvas.translate(renderRect.center.dx, renderRect.center.dy);
      canvas.scale(-1, 1);
      canvas.translate(-renderRect.center.dx, -renderRect.center.dy);
      canvas.drawImageRect(bundle.image, sourceRect, renderRect, paint);
      canvas.restore();
    } else {
      canvas.drawImageRect(bundle.image, sourceRect, renderRect, paint);
    }

    // Debug render overlays were intentionally removed.
  }
}

class HoverDrone extends BaseEnemy {
  static const List<String> _droneIdleImageCandidates = [
    'assets/sprites/enemies/drone_idle.png',
  ];
  static const List<String> _droneIdleAtlasCandidates = [
    'assets/sprites/enemies/drone_idle_atlas.json',
    'assets/sprites/enemies/drone_idle.json',
  ];
  static const double _droneRenderWidth = 120.0;
  static const List<int> _activeFrameIndexes = [
    0,
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
  ];
  static const int _atlasGridColumns = 4;
  static const int _atlasGridRows = 6;
  static const double _atlasCellWidth = 768.0;
  static const double _atlasCellHeight = 448.0;
  static const double _droneBaseAspectRatio =
      _atlasCellWidth / _atlasCellHeight;
  static const double _droneAnimationFps = 14.0;
  static const double _droneAnimationStepTime = 1.0 / _droneAnimationFps;
  static const Map<int, Offset> _debugFrameVisualOffsets = {
    0: Offset.zero,
    1: Offset.zero,
  };

  PlayerComponent? player;
  List<PlatformComponent> platforms = const [];
  double floorY = GameConfig.defaultWorldHeight;
  late HoverDroneAI ai;
  HoverDroneAnimState _animState = HoverDroneAnimState.hover;
  DroneMoveDirection _lastMoveDirection = DroneMoveDirection.left;
  DroneAnimationState _debugAnimationState = DroneAnimationState.idle;
  bool _hasDebugAnimationOverride = true;
  HoverDroneState _state = HoverDroneState.idleHover;

  _DroneAnimationRenderer? _renderer;
  double _fireCooldown = 0.0;
  double _shootAnimTimer = 0.0;
  double _deathTimer = 0.0;
  double _hoverBobTime = 0.0;
  bool _isFinalizedDead = false;

  static const double _shootAnimDuration = 0.16;
  static const double _deathAnimDuration = 0.21;
  static const double _hoverBobAmplitude = 1.6;
  static const double _hoverBobFrequency = 3.6;

  @override
  bool get saveFacingRight => _lastMoveDirection == DroneMoveDirection.right;

  @override
  void applySaveFacingRight(bool value) {
    _lastMoveDirection = value
        ? DroneMoveDirection.right
        : DroneMoveDirection.left;
    _syncSpriteState();
  }

  @override
  String get saveState => _state.name;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    size = Vector2(24, 24);
    useDefaultMovement = false;
    maxHealth = GameConfig.hoverDroneHealth;
    health = maxHealth;
    ai = HoverDroneAI();
    _fireCooldown = 0.0;
    await _tryInitSpriteAnimation();
  }

  @override
  void update(double dt) {
    if (_isFinalizedDead) {
      return;
    }

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
    _updateLastMoveDirection();
    _updateVisualHoverOffset();
    _syncSpriteState();

    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    // BaseEnemy draws a blue placeholder — skip it when real sprites are loaded.
    if (_renderer == null) {
      super.render(canvas);
    }
  }

  @override
  Rect get healthBarBoundsLocal {
    final renderer = _renderer;
    if (renderer == null) {
      final fallbackHeight = _droneRenderWidth / _droneBaseAspectRatio;
      return Rect.fromCenter(
        center: Offset(size.x / 2, size.y / 2),
        width: _droneRenderWidth,
        height: fallbackHeight,
      );
    }

    final rect = renderer.currentVisualRectLocal;
    final topLeft =
        renderer.position -
        Vector2(
          renderer.anchor.x * renderer.size.x,
          renderer.anchor.y * renderer.size.y,
        );
    return rect.shift(Offset(topLeft.x, topLeft.y));
  }

  void _updateAnimationState() {
    if (_hasDebugAnimationOverride) {
      _animState = _mapDebugToAnimState(_debugAnimationState);
      return;
    }

    // Drone uses idle visual by default for all gameplay states.
    _animState = HoverDroneAnimState.hover;
  }

  void setDebugAnimationState(DroneAnimationState state) {
    if (_hasDebugAnimationOverride && _debugAnimationState == state) {
      return;
    }
    _debugAnimationState = state;
    _hasDebugAnimationOverride = true;

    final nextAnimState = _mapDebugToAnimState(_debugAnimationState);
    _animState = nextAnimState;
    _renderer?.setState(nextAnimState);
  }

  void cycleDebugAnimationState() {
    final states = DroneAnimationState.values;
    final nextIndex = (_debugAnimationState.index + 1) % states.length;
    setDebugAnimationState(states[nextIndex]);
  }

  HoverDroneAnimState _mapDebugToAnimState(DroneAnimationState state) {
    switch (state) {
      case DroneAnimationState.idle:
        return HoverDroneAnimState.hover;
      case DroneAnimationState.fly:
        return HoverDroneAnimState.move;
      case DroneAnimationState.shoot:
        return HoverDroneAnimState.shoot;
    }
  }

  void stepDebugFrameNext() {
    _renderer?.stepFrame(1);
    _logManualFrameSwitch();
  }

  void stepDebugFramePrevious() {
    _renderer?.stepFrame(-1);
    _logManualFrameSwitch();
  }

  void _logManualFrameSwitch() {
    final frame = _renderer?.currentFrame;
    if (frame == null) {
      return;
    }
  }

  void _updateStateFromAi() {
    if (_shootAnimTimer > 0) {
      _state = HoverDroneState.shoot;
      return;
    }

    switch (ai.movementState) {
      case HoverDroneAiState.patrol:
      case HoverDroneAiState.engaged:
        _state = HoverDroneState.idleHover;
        return;
      case HoverDroneAiState.approach:
        _state = HoverDroneState.patrolHover;
        return;
      case HoverDroneAiState.holdDistance:
      case HoverDroneAiState.shoot:
        _state = HoverDroneState.aim;
        return;
    }
  }

  Future<void> _tryInitSpriteAnimation() async {
    final bundle = await _loadDroneAtlasBundle();
    if (bundle == null) {
      _renderer = null;
      return;
    }

    _renderer =
        _DroneAnimationRenderer(
            bundle: bundle,
            stepTimes: const {
              HoverDroneAnimState.hover: _droneAnimationStepTime,
              HoverDroneAnimState.move: _droneAnimationStepTime,
              HoverDroneAnimState.aim: _droneAnimationStepTime,
              HoverDroneAnimState.shoot: _droneAnimationStepTime,
              HoverDroneAnimState.death: _droneAnimationStepTime,
            },
            loops: const {
              HoverDroneAnimState.hover: true,
              HoverDroneAnimState.move: true,
              HoverDroneAnimState.aim: true,
              HoverDroneAnimState.shoot: true,
              HoverDroneAnimState.death: true,
            },
            hitboxSize: size,
            baseAspectRatio: _droneBaseAspectRatio,
            desiredVisualWidth: _droneRenderWidth,
            debugFrameVisualOffsets: _debugFrameVisualOffsets,
            initialState: _animState,
          )
          ..anchor = Anchor.center
          ..position = size / 2;

    add(_renderer!);
    _renderer!.setFlipX(_lastMoveDirection == DroneMoveDirection.right);
  }

  void _updateLastMoveDirection() {
    if (ai.canShoot) {
      _lastMoveDirection = ai.facingRight
          ? DroneMoveDirection.right
          : DroneMoveDirection.left;
      return;
    }

    if (velocity.x > GameConfig.droneDirectionThreshold) {
      _lastMoveDirection = DroneMoveDirection.right;
    } else if (velocity.x < -GameConfig.droneDirectionThreshold) {
      _lastMoveDirection = DroneMoveDirection.left;
    }
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
    if (!ai.canShoot) return;

    final manager = parent;
    if (manager == null) return;

    final direction = playerRef.position - position;
    if (direction.length2 == 0) {
      return;
    }
    direction.normalize();

    final projectile = EnemyProjectileComponent()
      ..position = position.clone()
      ..velocity =
          direction *
          (GameConfig.hoverDroneProjectileSpeed *
              difficultyProjectileSpeedMultiplier)
      ..damage =
          GameConfig.hoverDroneProjectileDamage * difficultyDamageMultiplier
      ..lifetime = GameConfig.hoverDroneProjectileLifetime;

    try {
      final dynamic projectileHost = manager;
      projectileHost.addProjectile(projectile);
    } catch (_) {
      return;
    }
    final game = findGame();
    if (game is VoidRelayGame) {
      if (kDebugMode) {
        debugPrint(
          '[ENEMY_SHOT] type=drone projectile spawned at ${projectile.position}',
        );
      }
      unawaited(game.playEnemyBlasterShotSound());
      if (kDebugMode) {
        debugPrint('[AUDIO] blaster_enemy played for drone');
      }
    }
    _fireCooldown = GameConfig.hoverDroneFireInterval;
    _shootAnimTimer = _shootAnimDuration;
    _state = HoverDroneState.shoot;
  }

  @override
  void takeDamage(double damage) {
    if (_isFinalizedDead) {
      return;
    }
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
    if (kDebugMode) {
      debugPrint('[ANIMATION] death animation speed x2 for hover_drone');
    }
  }

  void _syncSpriteState() {
    _renderer?.setState(_animState);
    _renderer?.setFlipX(_lastMoveDirection == DroneMoveDirection.right);
  }

  void _updateVisualHoverOffset() {
    if (_renderer == null) return;
    final yOffset = _isDeathPhase
        ? 0.0
        : math.sin(_hoverBobTime * _hoverBobFrequency) * _hoverBobAmplitude;
    _renderer!.position = Vector2(size.x / 2, size.y / 2 + yOffset);
  }

  bool get _isDeathPhase =>
      _state == HoverDroneState.dying ||
      _state == HoverDroneState.falling ||
      _state == HoverDroneState.landed;

  void _updateDeathFall(double dt) {
    if (_isFinalizedDead) {
      return;
    }
    _animState = HoverDroneAnimState.death;
    _shootAnimTimer = 0;
    _fireCooldown = double.infinity;

    if (_state == HoverDroneState.landed) {
      _finalizeDeathAndRemove();
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

  void _finalizeDeathAndRemove() {
    if (_isFinalizedDead) {
      return;
    }
    _isFinalizedDead = true;
    health = 0;
    _state = HoverDroneState.landed;
    _shootAnimTimer = 0;
    _fireCooldown = double.infinity;
    velocity.setZero();
    removeFromParent();
  }

  Future<_DroneAtlasBundle?> _loadDroneAtlasBundle() async {
    final imageAsset = await _loadDroneImage();
    if (imageAsset == null) {
      return null;
    }

    final imagePath = imageAsset.$1;
    final image = imageAsset.$2;
    for (final atlasPath in _droneIdleAtlasCandidates) {
      try {
        final atlasRaw = await rootBundle.loadString(atlasPath);
        final parseResult = _parseAtlasFrames(atlasRaw, image);
        if (parseResult == null || parseResult.frames.isEmpty) {
          continue;
        }

        final hasFullBoundsCoverage =
            image.width >= parseResult.maxSrcBoundX &&
            image.height >= parseResult.maxSrcBoundY;
        if (!hasFullBoundsCoverage) {
          continue;
        }

        return _DroneAtlasBundle(
          imagePath: imagePath,
          atlasPath: atlasPath,
          image: image,
          frames: parseResult.frames,
        );
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  Future<(String, Image)?> _loadDroneImage() async {
    for (final path in _droneIdleImageCandidates) {
      final image = await loadUiImageSafe(path);
      if (image != null) {
        return (path, image);
      }
    }
    return null;
  }

  _DroneAtlasParseResult? _parseAtlasFrames(String atlasRaw, Image image) {
    final decoded = jsonDecode(atlasRaw);
    if (decoded is! List) {
      return null;
    }

    final indexedFrames = <_DroneAtlasFrame>[];
    var maxSrcBoundX = 0.0;
    var maxSrcBoundY = 0.0;
    final cellWidth = image.width / _atlasGridColumns;
    final cellHeight = image.height / _atlasGridRows;
    for (final frame in decoded) {
      if (frame is! Map) {
        continue;
      }

      final col = frame['col'];
      final row = frame['row'];
      final index = frame['frameIndex'];
      if (col is! num || row is! num || index is! num) {
        continue;
      }

      final srcX = col.toDouble() * cellWidth;
      final srcY = row.toDouble() * cellHeight;
      final right = srcX + cellWidth;
      final bottom = srcY + cellHeight;
      if (right > maxSrcBoundX) {
        maxSrcBoundX = right;
      }
      if (bottom > maxSrcBoundY) {
        maxSrcBoundY = bottom;
      }

      final srcRect = Rect.fromLTWH(srcX, srcY, cellWidth, cellHeight);
      if (!_clipFitsImageBounds(image, srcRect)) {
        continue;
      }

      final frameIndex = index.toInt();
      if (!_activeFrameIndexes.contains(frameIndex)) {
        continue;
      }

      indexedFrames.add(_DroneAtlasFrame(frameIndex: frameIndex, src: srcRect));
    }

    if (indexedFrames.isEmpty) {
      return null;
    }

    indexedFrames.sort((a, b) => a.frameIndex.compareTo(b.frameIndex));
    return _DroneAtlasParseResult(
      frames: indexedFrames,
      maxSrcBoundX: maxSrcBoundX,
      maxSrcBoundY: maxSrcBoundY,
    );
  }

  bool _clipFitsImageBounds(Image image, Rect clip) {
    return clip.left >= 0 &&
        clip.top >= 0 &&
        clip.right <= image.width &&
        clip.bottom <= image.height;
  }
}
