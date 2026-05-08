import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../config/game_config.dart';
import '../../core/debug/debug_collision_config.dart';
import '../../core/utils/safe_asset_loader.dart';
import '../../flame_game.dart';
import '../../player/player_component.dart';
import '../../world/platform/platform_component.dart';
import '../base_enemy.dart';
import '../enemy_manager.dart';
import '../enemy_projectile_component.dart';
import 'enemy_config.dart';

enum EnemyState { idle, run }

enum Enemy3AiState {
  idle,
  chase,
  moveToDropEdge,
  fallingToPlayerLevel,
  shootStraight,
}

class _EnemyAtlasFrame {
  const _EnemyAtlasFrame({
    required this.frameIndex,
    required this.row,
    required this.col,
    required this.rawX,
    required this.rawY,
    required this.originalX,
    required this.originalY,
    required this.src,
  });

  final int frameIndex;
  final int row;
  final int col;
  final double rawX;
  final double rawY;
  final double originalX;
  final double originalY;
  final Rect src;
}

class _EnemyAtlasBundle {
  const _EnemyAtlasBundle({
    required this.imagePath,
    required this.atlasPath,
    required this.image,
    required this.frames,
  });

  final String imagePath;
  final String atlasPath;
  final Image image;
  final List<_EnemyAtlasFrame> frames;

  double get canonicalWidth {
    if (frames.isEmpty) return 0;
    return frames.map((f) => f.src.width).reduce((a, b) => a > b ? a : b);
  }

  double get canonicalHeight {
    if (frames.isEmpty) return 0;
    return frames.map((f) => f.src.height).reduce((a, b) => a > b ? a : b);
  }
}

class _EnemyAnimationRenderer extends PositionComponent {
  _EnemyAnimationRenderer({
    required this.bundles,
    required this.stepTimes,
    required this.desiredVisualHeight,
    required EnemyState initialState,
  }) : _state = initialState;

  final Map<EnemyState, _EnemyAtlasBundle> bundles;
  final Map<EnemyState, double> stepTimes;
  final double desiredVisualHeight;

  EnemyState _state;
  int _frameIndex = 0;
  double _frameTimer = 0;
  bool _facingRight = true;
  bool _paused = false;
  Rect? _lastDestRect;
  double? _lastScale;
  double _atlasScale = 1.0;
  bool _isInitialized = false;

  EnemyState get currentState => _state;
  int get currentFrameIndex => _frameIndex;

  Rect? get currentFrameRect {
    final bundle = bundles[_state];
    if (bundle == null || bundle.frames.isEmpty) return null;
    return bundle.frames[_frameIndex.clamp(0, bundle.frames.length - 1)].src;
  }

  Size? get currentCanonicalFrameSize {
    final bundle = _currentBundle;
    if (bundle == null) return null;
    return Size(bundle.canonicalWidth, bundle.canonicalHeight);
  }

  Rect? get currentDestRect {
    final bundle = _currentBundle;
    final frame = _currentFrame;
    if (bundle == null || frame == null) return null;
    return _computeDestRect(frame);
  }

  double? get currentScale {
    if (_currentBundle == null) return null;
    return _computeScale();
  }

  Rect? get lastDestRect => _lastDestRect;
  double? get lastScale => _lastScale;
  bool get isInitialized => _isInitialized;

  _EnemyAtlasBundle? get _currentBundle {
    final bundle = bundles[_state];
    if (bundle == null || bundle.frames.isEmpty) return null;
    return bundle;
  }

  _EnemyAtlasFrame? get _currentFrame {
    final bundle = _currentBundle;
    if (bundle == null) return null;
    return bundle.frames[_frameIndex.clamp(0, bundle.frames.length - 1)];
  }

  double _computeScaleForBundle(_EnemyAtlasBundle bundle) {
    final canonicalHeight = bundle.canonicalHeight;
    if (canonicalHeight <= 0) return 1.0;
    return desiredVisualHeight / canonicalHeight;
  }

  void _applyStateLayout() {
    final bundle = _currentBundle;
    if (bundle == null) return;

    _atlasScale = _computeScaleForBundle(bundle);
    size = Vector2(bundle.canonicalWidth * _atlasScale, desiredVisualHeight);
  }

  double _computeScale() {
    return _atlasScale;
  }

  Rect _computeDestRect(_EnemyAtlasFrame frame) {
    final scale = _computeScale();
    final destWidth = frame.src.width * scale;
    final destHeight = frame.src.height * scale;
    final offsetX = _facingRight
        ? Enemy3Config.visualOffsetX
        : -Enemy3Config.visualOffsetX;

    return Rect.fromLTWH(
      (size.x - destWidth) / 2 + offsetX,
      size.y - destHeight + Enemy3Config.visualOffsetY,
      destWidth,
      destHeight,
    );
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _applyStateLayout();
    _isInitialized = true;
  }

  void setState(EnemyState state) {
    if (_state == state) return;
    _state = state;
    _frameIndex = 0;
    _frameTimer = 0;
    if (_isInitialized) {
      _applyStateLayout();
    }
  }

  void setFacingRight(bool value) {
    _facingRight = value;
  }

  void setPaused(bool value) {
    _paused = value;
  }

  int frameCountForState(EnemyState state) {
    final bundle = bundles[state];
    return bundle?.frames.length ?? 0;
  }

  void setFrameIndex(int index) {
    final bundle = bundles[_state];
    if (bundle == null || bundle.frames.isEmpty) {
      _frameIndex = 0;
      return;
    }
    _frameIndex = index.clamp(0, bundle.frames.length - 1);
    _frameTimer = 0;
  }

  void nextFrame() {
    final bundle = bundles[_state];
    if (bundle == null || bundle.frames.isEmpty) return;
    _frameIndex = (_frameIndex + 1) % bundle.frames.length;
    _frameTimer = 0;
  }

  void previousFrame() {
    final bundle = bundles[_state];
    if (bundle == null || bundle.frames.isEmpty) return;
    _frameIndex = _frameIndex - 1;
    if (_frameIndex < 0) {
      _frameIndex = bundle.frames.length - 1;
    }
    _frameTimer = 0;
  }

  @override
  void update(double dt) {
    if (_paused) return;
    final bundle = bundles[_state];
    if (bundle == null || bundle.frames.isEmpty) return;

    final stepTime = stepTimes[_state] ?? 0.1;
    if (stepTime <= 0) return;

    _frameTimer += dt;
    while (_frameTimer >= stepTime) {
      _frameTimer -= stepTime;
      _frameIndex = (_frameIndex + 1) % bundle.frames.length;
    }
  }

  @override
  void render(Canvas canvas) {
    final bundle = _currentBundle;
    final frame = _currentFrame;
    if (bundle == null || frame == null) return;

    final sourceRect = frame.src;
    final destRect = _computeDestRect(frame);
    _lastDestRect = destRect;
    _lastScale = _computeScale();

    final imageSize = Size(
      bundle.image.width.toDouble(),
      bundle.image.height.toDouble(),
    );
    final sourceInBounds =
        sourceRect.left >= 0 &&
        sourceRect.top >= 0 &&
        sourceRect.right <= imageSize.width &&
        sourceRect.bottom <= imageSize.height;
    final componentBounds = Rect.fromLTWH(0, 0, size.x, size.y);
    final isVisible =
        destRect.width > 0 &&
        destRect.height > 0 &&
        destRect.overlaps(componentBounds);

    final owner = parent is Enemy3Component ? parent as Enemy3Component : null;
    final isDebugTarget =
        owner != null && identical(Enemy3Component.debugTarget, owner);

    if ((Enemy3Config.limitFramesForDebug && isDebugTarget) ||
        !sourceInBounds) {
      enemy3Log(
        'imageSize=$imageSize '
        'frameIndex=$_frameIndex '
        'sourceRect=$sourceRect '
        'destRect=$destRect '
        'componentSize=$size '
        'visible=$isVisible',
      );
    }

    if (!sourceInBounds) {
      enemy3Log('frame skipped: sourceRect out of image bounds');
      return;
    }

    if (Enemy3Config.debugRenderBounds) {
      canvas.drawRect(
        componentBounds,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFF00FF00),
      );
      canvas.drawRect(
        destRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFFFF0000),
      );
    }

    if (Enemy3Config.debugContours) {
      // Component bounds (green)
      canvas.drawRect(
        componentBounds,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFF00FF00),
      );

      // Visual destRect (red)
      canvas.drawRect(
        destRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFFFF0000),
      );

      // Feet baseline marker (yellow) in renderer local bottomCenter
      final feet = Offset(size.x / 2, size.y);
      final feetPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFFFFFF00);
      canvas.drawLine(
        Offset(feet.dx - 6, feet.dy),
        Offset(feet.dx + 6, feet.dy),
        feetPaint,
      );
      canvas.drawLine(
        Offset(feet.dx, feet.dy - 6),
        Offset(feet.dx, feet.dy + 6),
        feetPaint,
      );

      // Enemy center line for body-centering diagnostics.
      canvas.drawLine(
        Offset(size.x / 2, 0),
        Offset(size.x / 2, size.y),
        feetPaint,
      );

      // Platform contact line (orange) from last landing top in world coordinates.
      final owner = parent is Enemy3Component
          ? parent as Enemy3Component
          : null;
      if (owner != null && owner._lastPlatformTopY != null) {
        final localPlatformY =
            owner._lastPlatformTopY! - owner.position.y + size.y;
        canvas.drawLine(
          Offset(0, localPlatformY),
          Offset(size.x, localPlatformY),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = const Color(0xFFFFA500),
        );
      }
    }

    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;

    final shouldFlip = !Enemy3Config.limitFramesForDebug && !_facingRight;

    canvas.save();
    try {
      if (shouldFlip) {
        // Mirror around local center X so position.x/anchor remain stable.
        canvas.translate(size.x / 2, 0);
        canvas.scale(-1, 1);
        canvas.translate(-size.x / 2, 0);
      }

      if (Enemy3Config.limitFramesForDebug && isDebugTarget) {
        enemy3Log(
          'DRAW frameIndex=$_frameIndex '
          'imageHash=${bundle.image.hashCode} '
          'sourceRect=$sourceRect '
          'destRect=$destRect',
        );
        enemy3Log('before drawImageRect frameIndex=$_frameIndex');
      }

      canvas.drawImageRect(bundle.image, sourceRect, destRect, paint);

      if (Enemy3Config.limitFramesForDebug && isDebugTarget) {
        enemy3Log('after drawImageRect frameIndex=$_frameIndex');
      }

      if (Enemy3Config.debugShowFrameRect) {
        canvas.drawRect(
          destRect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = const Color(0x66FFAA00),
        );
      }
    } finally {
      canvas.restore();
    }
  }
}

class Enemy3Component extends BaseEnemy {
  static final Map<String, _EnemyAtlasBundle?> _bundleCache = {};
  static final List<Enemy3Component> _instances = <Enemy3Component>[];
  static final Set<int> _prevDebugKeyIds = <int>{};
  static Enemy3Component? debugTarget;

  PlayerComponent? player;
  List<PlatformComponent> platforms = const [];
  double? spawnPlatformTopY;

  double _fireCooldown = 0;
  double _velocityY = 0;
  bool _isOnGround = false;
  bool _didLogFalling = false;
  double? _lastPlatformTopY;
  bool _facingRight = true;
  EnemyState _state = EnemyState.idle;
  Enemy3AiState _aiState = Enemy3AiState.idle;
  EnemyState _debugState = EnemyState.idle;
  int _debugFrameIndex = 0;
  _EnemyAnimationRenderer? _renderer;
  bool _debugAnimationPaused = false;
  int _lastLoggedMoveDirection = 0;

  bool get _isDebugTarget => identical(debugTarget, this);

  Enemy3AiState get aiState => _aiState;

  bool get isGroundedForSave => _isOnGround;

  @override
  bool get saveFacingRight => _facingRight;

  @override
  void applySaveFacingRight(bool value) {
    _facingRight = value;
    _syncVisualFacing();
  }

  @override
  String get saveState => _aiState.name;

  void restoreGroundSavePose({
    required double feetX,
    required double feetY,
    required bool facingRight,
    required bool isGrounded,
    required double velocityX,
    required double velocityY,
  }) {
    position.x = feetX;
    position.y = feetY;
    _velocityY = velocityY;
    velocity.x = velocityX;
    _isOnGround = isGrounded;
    _facingRight = facingRight;
    _syncVisualFacing();

    if (_isOnGround) {
      _snapToNearbyPlatform(maxDistance: 96.0);
      _velocityY = 0;
      velocity.y = 0;
    }
  }

  void _snapToNearbyPlatform({required double maxDistance}) {
    final targetTop = position.y - Enemy3Config.feetVisualOffsetY;
    Rect? best;
    var bestDistance = maxDistance;

    for (final platform in platforms) {
      final rect = platform.toRect();
      if (!_isSolidGroundPlatform(rect)) continue;
      if (position.x < rect.left || position.x > rect.right) continue;

      final distance = (rect.top - targetTop).abs();
      if (distance <= bestDistance) {
        best = rect;
        bestDistance = distance;
      }
    }

    if (best == null) {
      return;
    }

    _lastPlatformTopY = best.top;
    position.y = best.top + Enemy3Config.feetVisualOffsetY;
    _isOnGround = true;
  }

  Rect get worldHitboxRect {
    final p = absolutePosition;
    return Rect.fromLTWH(
      p.x - Enemy3Config.hitboxWidth / 2 + Enemy3Config.hitboxOffsetX,
      p.y - Enemy3Config.hitboxHeight + Enemy3Config.hitboxOffsetY,
      Enemy3Config.hitboxWidth,
      Enemy3Config.hitboxHeight,
    );
  }

  Rect get _hitboxLocalRect => Rect.fromLTWH(
    size.x / 2 - Enemy3Config.hitboxWidth / 2 + Enemy3Config.hitboxOffsetX,
    size.y - Enemy3Config.hitboxHeight + Enemy3Config.hitboxOffsetY,
    Enemy3Config.hitboxWidth,
    Enemy3Config.hitboxHeight,
  );

  @override
  Rect get healthBarBoundsLocal {
    final renderer = _renderer;
    if (renderer == null) {
      return Rect.fromLTWH(0, 0, size.x, size.y);
    }

    final dest = renderer.currentDestRect ?? renderer.lastDestRect;
    if (dest == null) {
      return Rect.fromLTWH(0, 0, size.x, size.y);
    }

    final topLeft =
        renderer.position -
        Vector2(
          renderer.anchor.x * renderer.size.x,
          renderer.anchor.y * renderer.size.y,
        );
    return dest.shift(Offset(topLeft.x, topLeft.y));
  }

  void _syncRootSizeWithVisual() {
    final visual = _renderer?.size;
    if (visual == null || visual.x <= 0 || visual.y <= 0) {
      size = Vector2(Enemy3Config.visualWidth, Enemy3Config.visualHeight);
      return;
    }
    size = visual.clone();
  }

  void _applySpawnBaselineAfterInit() {
    final top = spawnPlatformTopY;
    if (top == null) {
      _isOnGround = false;
      return;
    }

    position.y = top + Enemy3Config.feetVisualOffsetY;
    _velocityY = 0;
    _isOnGround = true;
    _lastPlatformTopY = top;
  }

  bool _hasHorizontalOverlap(Rect platformRect) {
    final enemyLeft = position.x - Enemy3Config.hitboxWidth / 2;
    final enemyRight = position.x + Enemy3Config.hitboxWidth / 2;
    return enemyRight > platformRect.left && enemyLeft < platformRect.right;
  }

  bool _hasPlatformUnderFeet({bool logIfMissing = false}) {
    final feetY = position.y;
    final enemyLeft = position.x - Enemy3Config.hitboxWidth / 2;
    final enemyRight = position.x + Enemy3Config.hitboxWidth / 2;

    Rect? nearestPlatform;
    var nearestDist = double.infinity;

    for (final platform in platforms) {
      final rect = platform.toRect();
      if (!_isSolidGroundPlatform(rect)) continue;

      final baselineY = rect.top + Enemy3Config.feetVisualOffsetY;
      final overlapsX = enemyRight > rect.left && enemyLeft < rect.right;
      final sameY =
          (feetY - baselineY).abs() <= Enemy3Config.groundSnapTolerance;

      final dist = (feetY - baselineY).abs();
      if (dist < nearestDist) {
        nearestDist = dist;
        nearestPlatform = rect;
      }

      if (overlapsX && sameY) {
        return true;
      }
    }

    if (logIfMissing && Enemy3Config.debugLogs) {
      final platformLeft = nearestPlatform?.left;
      final platformRight = nearestPlatform?.right;
      enemy3Log(
        'left platform edge: '
        'enemyLeft=$enemyLeft '
        'enemyRight=$enemyRight '
        'platformLeft=$platformLeft '
        'platformRight=$platformRight',
      );
    }

    return false;
  }

  bool _isSolidGroundPlatform(Rect rect) {
    final isHorizontal = rect.width > rect.height;
    if (!isHorizontal) return false;

    // Ignore hidden ceiling boundary collision strips for Enemy3 grounding.
    final isVeryWide = rect.width >= GameConfig.defaultWorldWidth * 0.6;
    final isCeilingBoundary = isVeryWide && rect.top <= 4.0;
    return !isCeilingBoundary;
  }

  bool _isSupportedOnPlatformTop() {
    return _hasPlatformUnderFeet();
  }

  Rect? _findPlatformNearFeet({required double x, required double feetY}) {
    Rect? nearest;
    var nearestDistance = double.infinity;

    for (final platform in platforms) {
      final rect = platform.toRect();
      if (!_isSolidGroundPlatform(rect)) {
        continue;
      }

      if (x < rect.left || x > rect.right) {
        continue;
      }

      final baselineY = rect.top + Enemy3Config.feetVisualOffsetY;
      final distance = (feetY - baselineY).abs();
      if (distance <= Enemy3Config.groundSnapTolerance * 4 &&
          distance < nearestDistance) {
        nearest = rect;
        nearestDistance = distance;
      }
    }

    return nearest;
  }

  bool _needsLevelAlignment(PlayerComponent playerRef) {
    final enemyPlatform = _findPlatformNearFeet(
      x: position.x,
      feetY: position.y,
    );
    final playerFeetY = playerRef.worldHitboxRect.bottom;
    final playerPlatform = _findPlatformNearFeet(
      x: playerRef.position.x,
      feetY: playerFeetY,
    );
    if (enemyPlatform == null || playerPlatform == null) {
      return false;
    }

    return (enemyPlatform.top - playerPlatform.top).abs() >
        Enemy3Config.groundSnapTolerance;
  }

  bool _isEnemyAbovePlayer(PlayerComponent playerRef) {
    final enemyFeetY = position.y;
    final playerFeetY = playerRef.worldHitboxRect.bottom;
    return enemyFeetY <
        playerFeetY - (Enemy3Config.shootVerticalTolerance * 0.5);
  }

  double _computeLevelAlignDirection(PlayerComponent playerRef) {
    final currentPlatform = _findPlatformNearFeet(
      x: position.x,
      feetY: position.y,
    );
    if (currentPlatform == null) {
      return playerRef.position.x >= position.x ? 1.0 : -1.0;
    }

    final playerX = playerRef.position.x;
    if (playerX <= currentPlatform.left) {
      return -1.0;
    }
    if (playerX >= currentPlatform.right) {
      return 1.0;
    }

    final leftDistance = (position.x - currentPlatform.left).abs();
    final rightDistance = (currentPlatform.right - position.x).abs();
    if ((leftDistance - rightDistance).abs() <=
        Enemy3Config.facingDirectionThreshold) {
      return _facingRight ? 1.0 : -1.0;
    }
    return leftDistance <= rightDistance ? -1.0 : 1.0;
  }

  void _applyVerticalPhysics(double dt) {
    final previousY = position.y;

    if (_isOnGround && !_isSupportedOnPlatformTop()) {
      _isOnGround = false;
      if (!_didLogFalling && Enemy3Config.debugLogs) {
        enemy3Log('falling');
        _didLogFalling = true;
      }
    }

    if (!_isOnGround) {
      _velocityY += Enemy3Config.gravity * dt;
      if (_velocityY > Enemy3Config.maxFallSpeed) {
        _velocityY = Enemy3Config.maxFallSpeed;
      }
    }

    position.y += _velocityY * dt;

    if (_velocityY < 0) {
      return;
    }

    double? landingTop;
    for (final platform in platforms) {
      final rect = platform.toRect();
      if (!_isSolidGroundPlatform(rect)) continue;
      final overlapsX = _hasHorizontalOverlap(rect);
      if (_isDebugTarget &&
          Enemy3Config.debugLogs &&
          Enemy3Config.debugContours) {
        final isBelow = rect.top >= previousY;
        enemy3Log(
          'platform candidate topY=${rect.top} '
          'left=${rect.left} right=${rect.right} '
          'overlapsX=$overlapsX isBelow=$isBelow',
        );
      }
      if (!overlapsX) continue;

      final platformTopY = rect.top;
      final previousFeetY = previousY;
      final currentFeetY = position.y;
      final crossedTop =
          previousFeetY <= platformTopY && currentFeetY >= platformTopY;
      if (!crossedTop) continue;

      if (landingTop == null || platformTopY < landingTop) {
        landingTop = platformTopY;
      }
    }

    if (landingTop == null) {
      return;
    }

    _lastPlatformTopY = landingTop;
    position.y = landingTop + Enemy3Config.feetVisualOffsetY;
    _velocityY = 0;
    _isOnGround = true;
    _didLogFalling = false;
    if (Enemy3Config.debugLogs) {
      final destRect = _renderer?.currentDestRect ?? _renderer?.lastDestRect;
      enemy3Log(
        'landed platformTopY=$landingTop '
        'enemyX=${position.x} '
        'previousY=$previousY '
        'newY=${position.y} '
        'baselineOffset=${Enemy3Config.feetVisualOffsetY} '
        'position=$position '
        'size=$size '
        'anchor=$anchor '
        'localBottomY=${size.y} '
        'hitboxRect=$_hitboxLocalRect '
        'destRect=$destRect',
      );
      final enemyFeetY = position.y;
      final platformY = _lastPlatformTopY;
      final gap = platformY == null ? null : platformY - enemyFeetY;
      enemy3Log(
        'Y CHECK enemyFeetY=$enemyFeetY '
        'platformTopY=$platformY '
        'gap=$gap '
        'size=$size '
        'anchor=$anchor '
        'feetOffset=${Enemy3Config.feetVisualOffsetY}',
      );
    }
  }

  @override
  Future<void> onLoad() async {
    useDefaultMovement = false;
    await super.onLoad();

    anchor = Anchor.bottomCenter;
    size = Vector2(Enemy3Config.visualWidth, Enemy3Config.visualHeight);
    maxHealth = Enemy3Config.maxHp;
    health = maxHealth;
    _fireCooldown = 0;
    _isOnGround = false;
    _velocityY = 0;
    angle = 0;

    _instances.add(this);
    debugTarget ??= this;
    if (_isDebugTarget) {
      enemy3Log('debug target selected pos=$position');
    }

    await _initVisual();
    _syncRootSizeWithVisual();
    _applySpawnBaselineAfterInit();

    if (Enemy3Config.debugLogs) {
      enemy3Log(
        'spawn platformTopY=${spawnPlatformTopY ?? 'unknown'} '
        'enemyY=${position.y} '
        'anchor=$anchor '
        'size=$size',
      );
    }
  }

  @override
  void onRemove() {
    _instances.remove(this);
    if (_isDebugTarget) {
      debugTarget = _instances.isEmpty ? null : _instances.first;
      final next = debugTarget;
      if (next != null) {
        enemy3Log('debug target selected pos=${next.position}');
      }
    }
    super.onRemove();
  }

  @override
  Rect toRect() {
    return worldHitboxRect;
  }

  @override
  void render(Canvas canvas) {
    if (Enemy3Config.debugRenderBounds && PlayerComponent.debugDrawCollision) {
      final hitboxPaint = Paint()
        ..color = const Color(0x663399FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawRect(_hitboxLocalRect, hitboxPaint);
    }

    if (Enemy3Config.debugHitbox &&
        DebugCollisionConfig.showCollisionBoxes &&
        DebugCollisionConfig.showEnemy3Hitbox) {
      // Hitbox bounds (blue)
      canvas.drawRect(
        _hitboxLocalRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFF0000FF),
      );
    }
  }

  @override
  void update(double dt) {
    final game = findGame();
    if (game is VoidRelayGame && game.isGameplayInputBlocked) {
      return;
    }
    if (!isAlive) {
      return;
    }

    angle = 0;

    _fireCooldown -= dt;

    final playerRef = player;
    if (playerRef == null) {
      return;
    }

    _handleDebugAnimationHotkeys();
    if (Enemy3Config.limitFramesForDebug) {
      velocity.x = 0;
      _facingRight = true;
      angle = 0;
      _syncVisualFacing();

      // In frame-limit debug mode frame index changes only via F4/F5.
      _renderer?.setPaused(true);

      super.update(0);
      return;
    }

    if (Enemy3Config.debugManualAnimationMode && _isDebugTarget) {
      // Manual mode isolates animation debugging from AI movement/shooting.
      velocity.x = 0;
      angle = 0;
      _syncVisualFacing();
      if (!_debugAnimationPaused) {
        _renderer?.update(dt);
      }
      super.update(0);
      return;
    }

    if (!_isOnGround) {
      _applyVerticalPhysics(dt);
      if (!_isOnGround) {
        _aiState = Enemy3AiState.fallingToPlayerLevel;
        velocity.x = 0;
        _setState(EnemyState.idle);
        _syncVisualFacing();

        // Keep animation ticking while airborne, but disable horizontal AI.
        _renderer?.update(dt);
        angle = 0;
        super.update(0);
        angle = 0;
        return;
      }
    }

    final toPlayer = playerRef.position - position;
    final dx = playerRef.position.x - position.x;
    final dist = toPlayer.length;
    final horizontalDistance = dx.abs();
    final previousFacingDirection = _facingRight ? 1.0 : -1.0;
    final facingDirection = dx.abs() <= Enemy3Config.facingDirectionThreshold
        ? previousFacingDirection
        : (dx > 0 ? 1.0 : -1.0);
    _facingRight = facingDirection > 0;
    angle = 0;

    final isInRange = dist <= Enemy3Config.detectionRange;
    final wasShootStraightState = _aiState == Enemy3AiState.shootStraight;
    final isPlayerInFront = _facingRight ? dx > 0 : dx < 0;
    final shotOriginY = position.y + Enemy3Config.bulletSpawnOffsetY;
    final playerTargetY = playerRef.position.y + Enemy3Config.targetOffsetY;
    final dy = playerTargetY - shotOriginY;
    final isSameHeight = dy.abs() <= Enemy3Config.shootVerticalTolerance;
    final canShootStraight = isInRange && isPlayerInFront && isSameHeight;
    final isWithinShootDistance =
        horizontalDistance <= Enemy3Config.shootDistance;
    final needsLevelAlignment = _needsLevelAlignment(playerRef);
    final shouldDescendToPlayer =
        isInRange && _isEnemyAbovePlayer(playerRef) && !isSameHeight;

    if (!isInRange) {
      _aiState = Enemy3AiState.idle;
      velocity.x = 0;
      _setState(EnemyState.idle);
    } else if (!canShootStraight || !isWithinShootDistance) {
      final shouldMoveToDropEdge = shouldDescendToPlayer || needsLevelAlignment;
      _aiState = shouldMoveToDropEdge
          ? Enemy3AiState.moveToDropEdge
          : Enemy3AiState.chase;
      final moveDirection = shouldMoveToDropEdge
          ? _computeLevelAlignDirection(playerRef)
          : facingDirection;
      velocity.x =
          moveDirection * Enemy3Config.moveSpeed * difficultySpeedMultiplier;
      if (_isOnGround) {
        _setState(EnemyState.run);
      }

      if (_isDebugTarget && Enemy3Config.debugLogs) {
        final dir = moveDirection > 0 ? 1 : -1;
        if (dir != _lastLoggedMoveDirection) {
          _lastLoggedMoveDirection = dir;
          enemy3Log(
            'movement direction=$dir positionX=${position.x.toStringAsFixed(1)}',
          );
        }
      }
    } else {
      _aiState = Enemy3AiState.shootStraight;
      velocity.x = 0;
      _lastLoggedMoveDirection = 0;
      if (_isOnGround) {
        _setState(EnemyState.idle);
      }
      final isStopped = velocity.x.abs() < 0.1;
      final canFireNow = wasShootStraightState && isStopped;
      if (canFireNow) {
        _tryShoot(facingDirection);
      }
    }

    position.x += velocity.x * dt;

    if (_isOnGround && !_hasPlatformUnderFeet(logIfMissing: true)) {
      _isOnGround = false;
      _lastPlatformTopY = null;
      _velocityY = 0;
      if (Enemy3Config.debugLogs) {
        enemy3Log('falling from edge y=${position.y}');
      }
      _setState(EnemyState.idle);
    }

    _applyVerticalPhysics(dt);
    _syncVisualFacing();

    // BaseEnemy uses super.update(0) here to avoid double movement integration,
    // so we manually advance visual frames with real dt.
    _renderer?.update(dt);
    angle = 0;

    super.update(0);
    angle = 0;
  }

  @override
  void takeDamage(double damage) {
    if (Enemy3Config.limitFramesForDebug) {
      return;
    }
    super.takeDamage(damage);
    if (Enemy3Config.debugLogs) {
      enemy3Log('player bullet hit Enemy3 damage=$damage hp=$health');
      enemy3Log('Enemy3 hitbox=$worldHitboxRect');
    }

    if (isDead && Enemy3Config.debugLogs) {
      enemy3Log('Enemy3 died');
    }
  }

  void _tryShoot(double facingDirection) {
    if (_fireCooldown > 0) {
      return;
    }

    final manager = parent;
    if (manager is! EnemyManager) {
      return;
    }

    final spawn = Vector2(
      position.x + Enemy3Config.bulletSpawnOffsetX * facingDirection,
      position.y + Enemy3Config.bulletSpawnOffsetY,
    );
    final shotDirection = Vector2(facingDirection, 0);
    if (Enemy3Config.debugLogs) {
      enemy3Log(
        'enemy shoot spawn=$spawn '
        'direction=$shotDirection '
        'spawnOffsetY=${Enemy3Config.bulletSpawnOffsetY} '
        'targetOffsetY=${Enemy3Config.targetOffsetY}',
      );
    }

    final bullet = EnemyProjectileComponent()
      ..position = spawn
      ..velocity =
          shotDirection *
          (Enemy3Config.bulletSpeed * difficultyProjectileSpeedMultiplier)
      ..damage = Enemy3Config.bulletDamage * difficultyDamageMultiplier
      ..maxRange = Enemy3Config.bulletRange
      ..angleOffset = Enemy3Config.bulletAngleOffset
      ..spritePath = Enemy3Config.bulletPath;

    manager.addProjectile(bullet);
    final game = findGame();
    if (game is VoidRelayGame) {
      if (kDebugMode) {
        debugPrint(
          '[ENEMY_SHOT] type=enemy3 projectile spawned at ${bullet.position}',
        );
      }
      unawaited(game.playEnemyBlasterShotSound());
      if (kDebugMode) {
        debugPrint('[AUDIO] blaster_enemy played for enemy3');
      }
    }
    _fireCooldown = Enemy3Config.fireCooldown;
  }

  Future<void> _initVisual() async {
    final idle = await _loadAtlasBundle(
      label: 'idle',
      imageCandidates: Enemy3Config.idlePathCandidates,
      atlasCandidates: Enemy3Config.idleAtlasPathCandidates,
    );
    final run = await _loadAtlasBundle(
      label: 'run',
      imageCandidates: Enemy3Config.runPathCandidates,
      atlasCandidates: Enemy3Config.runAtlasPathCandidates,
    );

    if (idle == null || run == null) {
      return;
    }

    if (Enemy3Config.debugLogs) {
      enemy3Log('idle frames count=${idle.frames.length}');
      enemy3Log('run frames count=${run.frames.length}');
      if (run.frames.isNotEmpty) {
        enemy3Log('run first frame sourceRect=${run.frames.first.src}');
      }
    }

    _renderer =
        _EnemyAnimationRenderer(
            bundles: {EnemyState.idle: idle, EnemyState.run: run},
            stepTimes: {
              EnemyState.idle: Enemy3Config.idleStepTime,
              EnemyState.run: Enemy3Config.runStepTime,
            },
            desiredVisualHeight: Enemy3Config.visualHeight,
            initialState: _state,
          )
          ..anchor = Anchor.bottomCenter
          ..position = Vector2.zero();
    add(_renderer!);

    if (Enemy3Config.limitFramesForDebug) {
      _debugState = EnemyState.idle;
      _debugFrameIndex = 0;
      _applyDebugFrameSelection();
    }

    if (Enemy3Config.limitFramesForDebug) {
      _debugAnimationPaused = true;
      _renderer?.setPaused(true);
    }

    if (Enemy3Config.debugManualAnimationMode) {
      _logDebugFrame('idle atlas loaded');
      _setState(EnemyState.run);
      _logDebugFrame('run atlas loaded');
      _setState(EnemyState.idle);
    }
  }

  void _setState(EnemyState nextState) {
    if (Enemy3Config.limitFramesForDebug) {
      _debugState = nextState;
      _debugFrameIndex = 0;
      _applyDebugFrameSelection();
      _state = nextState;
      return;
    }

    if (_state == nextState) {
      return;
    }
    _state = nextState;
    _renderer?.setState(nextState);
    if (_isDebugTarget && Enemy3Config.debugLogs) {
      enemy3Log('state changed=${nextState.name}');
    }
  }

  void _applyDebugFrameSelection() {
    final renderer = _renderer;
    if (renderer == null) {
      return;
    }

    renderer.setState(_debugState);
    final frameCount = renderer.frameCountForState(_debugState);
    if (frameCount <= 0) {
      _debugFrameIndex = 0;
      renderer.setFrameIndex(0);
      return;
    }

    _debugFrameIndex = _debugFrameIndex.clamp(0, frameCount - 1);
    renderer.setFrameIndex(_debugFrameIndex);
  }

  void _syncVisualFacing() {
    _renderer?.setFacingRight(_facingRight);
  }

  void _handleDebugAnimationHotkeys() {
    if (!Enemy3Config.debugManualAnimationMode) {
      return;
    }
    if (!_isDebugTarget) {
      return;
    }

    final pressed = HardwareKeyboard.instance.logicalKeysPressed
        .map((k) => k.keyId)
        .toSet();

    bool justPressed(LogicalKeyboardKey key) =>
        pressed.contains(key.keyId) && !_prevDebugKeyIds.contains(key.keyId);

    if (justPressed(LogicalKeyboardKey.f6)) {
      _selectNextDebugTarget();
      _prevDebugKeyIds
        ..clear()
        ..addAll(pressed);
      return;
    }

    if (justPressed(LogicalKeyboardKey.f1) ||
        justPressed(LogicalKeyboardKey.digit1)) {
      if (Enemy3Config.limitFramesForDebug) {
        _debugState = EnemyState.idle;
        _debugFrameIndex = 0;
        _applyDebugFrameSelection();
      } else {
        _setState(EnemyState.idle);
      }
      _logDebugFrame('debug animation switched to idle');
    }

    if (justPressed(LogicalKeyboardKey.f2) ||
        justPressed(LogicalKeyboardKey.digit2)) {
      if (Enemy3Config.limitFramesForDebug) {
        _debugState = EnemyState.run;
        _debugFrameIndex = 0;
        _applyDebugFrameSelection();
      } else {
        _setState(EnemyState.run);
      }
      _logDebugFrame('debug animation switched to run');
    }

    if (justPressed(LogicalKeyboardKey.f3) ||
        justPressed(LogicalKeyboardKey.digit3)) {
      _debugAnimationPaused = !_debugAnimationPaused;
      _renderer?.setPaused(
        Enemy3Config.limitFramesForDebug ? true : _debugAnimationPaused,
      );
      _logDebugFrame('debug pause=${_debugAnimationPaused ? 'on' : 'off'}');
    }

    if (justPressed(LogicalKeyboardKey.f4) ||
        justPressed(LogicalKeyboardKey.digit4)) {
      _debugAnimationPaused = true;
      _renderer?.setPaused(true);
      if (Enemy3Config.limitFramesForDebug) {
        final renderer = _renderer;
        if (renderer != null) {
          final frameCount = renderer.frameCountForState(_debugState);
          if (frameCount > 0) {
            _debugFrameIndex = (_debugFrameIndex + 1) % frameCount;
            _applyDebugFrameSelection();
          }
        }
      } else {
        _renderer?.nextFrame();
      }
      _logDebugFrame('debug next frame');
    }

    if (justPressed(LogicalKeyboardKey.f5) ||
        justPressed(LogicalKeyboardKey.digit5)) {
      _debugAnimationPaused = true;
      _renderer?.setPaused(true);
      if (Enemy3Config.limitFramesForDebug) {
        final renderer = _renderer;
        if (renderer != null) {
          final frameCount = renderer.frameCountForState(_debugState);
          if (frameCount > 0) {
            _debugFrameIndex = (_debugFrameIndex - 1) % frameCount;
            if (_debugFrameIndex < 0) {
              _debugFrameIndex += frameCount;
            }
            _applyDebugFrameSelection();
          }
        }
      } else {
        _renderer?.previousFrame();
      }
      _logDebugFrame('debug previous frame');
    }

    _prevDebugKeyIds
      ..clear()
      ..addAll(pressed);
  }

  void _selectNextDebugTarget() {
    if (_instances.isEmpty) return;

    final current = debugTarget;
    final currentIndex = current == null ? -1 : _instances.indexOf(current);
    if (currentIndex < 0) {
      debugTarget = _instances.first;
    } else {
      final nextIndex = (currentIndex + 1) % _instances.length;
      debugTarget = _instances[nextIndex];
    }

    final next = debugTarget;
    if (next == null) return;
    next._debugAnimationPaused = Enemy3Config.limitFramesForDebug
        ? true
        : false;
    next._renderer?.setPaused(Enemy3Config.limitFramesForDebug ? true : false);
    if (Enemy3Config.limitFramesForDebug) {
      next._applyDebugFrameSelection();
    }
    enemy3Log('debug target selected pos=${next.position}');
    next._logDebugFrame('debug target active');
  }

  void _logDebugFrame(String reason) {
    if (!Enemy3Config.debugManualAnimationMode) {
      return;
    }
    if (!_isDebugTarget) {
      return;
    }
    final renderer = _renderer;
    if (renderer == null) {
      enemy3Log('$reason renderer=missing');
      return;
    }
    if (!renderer.isInitialized) {
      enemy3Log('$reason debug frame skipped: renderer not initialized yet');
      return;
    }

    final sourceRect = renderer.currentFrameRect;
    final canonicalFrameSize = renderer.currentCanonicalFrameSize;
    final scale = renderer.currentScale ?? renderer.lastScale;
    final destRect = renderer.currentDestRect ?? renderer.lastDestRect;

    enemy3Log(
      '$reason '
      'target=true '
      'state=${renderer.currentState.name} '
      'frameIndex=${renderer.currentFrameIndex} '
      'sourceRect=$sourceRect '
      'canonicalFrameSize=$canonicalFrameSize '
      'scale=$scale '
      'componentSize=${renderer.size} '
      'destRect=$destRect '
      'position=$position '
      'angle=$angle',
    );
  }

  Future<_EnemyAtlasBundle?> _loadAtlasBundle({
    required String label,
    required List<String> imageCandidates,
    required List<String> atlasCandidates,
  }) async {
    final imageAsset = await _loadAnimationAsset(imageCandidates);
    if (imageAsset == null) {
      return null;
    }

    for (final atlasPath in atlasCandidates) {
      final cacheKey = '${imageAsset.$1}|$atlasPath';
      if (_bundleCache.containsKey(cacheKey)) {
        return _bundleCache[cacheKey];
      }

      final bundle = await _tryParseAtlasBundle(
        label: label,
        imagePath: imageAsset.$1,
        atlasPath: atlasPath,
        image: imageAsset.$2,
      );
      _bundleCache[cacheKey] = bundle;
      if (bundle != null) {
        return bundle;
      }
    }
    return null;
  }

  Future<_EnemyAtlasBundle?> _tryParseAtlasBundle({
    required String label,
    required String imagePath,
    required String atlasPath,
    required Image image,
  }) async {
    try {
      final atlasRaw = await rootBundle.loadString(atlasPath);
      final decoded = jsonDecode(atlasRaw);
      if (decoded is! List) {
        return null;
      }

      final atlasFrames =
          decoded
              .whereType<Map>()
              .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
              .where((frame) {
                final idx = frame['frameIndex'];
                final x = frame['x'];
                final y = frame['y'];
                final w = frame['width'];
                final h = frame['height'];
                return idx is num &&
                    x is num &&
                    y is num &&
                    w is num &&
                    h is num;
              })
              .toList(growable: false)
            ..sort(
              (a, b) =>
                  (a['frameIndex'] as num).compareTo((b['frameIndex'] as num)),
            );

      final frameDefs =
          atlasFrames
              .map((frame) {
                final idx = (frame['frameIndex'] as num).toInt();
                final row = (frame['row'] as num?)?.toInt() ?? 0;
                final col = (frame['col'] as num?)?.toInt() ?? 0;
                final x = (frame['x'] as num).toDouble();
                final y = (frame['y'] as num).toDouble();
                final w = (frame['width'] as num).toDouble();
                final h = (frame['height'] as num).toDouble();
                final originalX =
                    (frame['originalX'] as num?)?.toDouble() ?? 0.0;
                final originalY =
                    (frame['originalY'] as num?)?.toDouble() ?? 0.0;

                final sourceX = Enemy3Config.atlasUsesGridCellOffsets
                    ? col * Enemy3Config.sheetFrameWidth + originalX
                    : x;
                final sourceY = Enemy3Config.atlasUsesGridCellOffsets
                    ? row * Enemy3Config.sheetFrameHeight + originalY
                    : y;

                final sourceRect = Rect.fromLTWH(sourceX, sourceY, w, h);

                // Keep parser logs minimal; runtime debug logs cover selected frames.

                final right = sourceRect.right;
                final bottom = sourceRect.bottom;
                final inBounds =
                    sourceRect.left >= 0 &&
                    sourceRect.top >= 0 &&
                    right <= image.width &&
                    bottom <= image.height;
                if (!inBounds) {
                  return null;
                }

                return _EnemyAtlasFrame(
                  frameIndex: idx,
                  row: row,
                  col: col,
                  rawX: x,
                  rawY: y,
                  originalX: originalX,
                  originalY: originalY,
                  src: sourceRect,
                );
              })
              .whereType<_EnemyAtlasFrame>()
              .toList(growable: false)
            ..sort((a, b) => a.frameIndex.compareTo(b.frameIndex));

      if (frameDefs.isEmpty) {
        return null;
      }

      final limitedFrameDefs = _applyDebugFrameLimit(frameDefs);
      if (Enemy3Config.limitFramesForDebug) {
        enemy3Log(
          '$label frames limited for debug: ${limitedFrameDefs.length}',
        );
      }
      if (limitedFrameDefs.isEmpty) {
        return null;
      }

      return _EnemyAtlasBundle(
        imagePath: imagePath,
        atlasPath: atlasPath,
        image: image,
        frames: limitedFrameDefs,
      );
    } catch (e) {
      return null;
    }
  }

  Future<(String, Image)?> _loadAnimationAsset(List<String> candidates) async {
    for (final path in candidates) {
      final image = await loadUiImageSafe(path);
      if (image != null) {
        return (path, image);
      }
    }
    return null;
  }

  List<_EnemyAtlasFrame> _applyDebugFrameLimit(List<_EnemyAtlasFrame> frames) {
    if (!Enemy3Config.limitFramesForDebug) {
      return frames;
    }

    final limit = Enemy3Config.debugFrameLimit;
    if (limit <= 0) {
      return frames;
    }

    return frames.take(limit).toList(growable: false);
  }
}

// Backward-compatible alias for current spawn wiring.
class BasicEnemyComponent extends Enemy3Component {}
