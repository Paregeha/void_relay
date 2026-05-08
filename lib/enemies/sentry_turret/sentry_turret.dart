import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../config/game_config.dart';
import '../../core/utils/safe_asset_loader.dart';
import '../../flame_game.dart';
import '../../player/player_component.dart';
import '../base_enemy.dart';
import '../enemy_projectile_component.dart';
import 'turret_ai.dart';

class _TurretAtlasFrame {
  const _TurretAtlasFrame({required this.frameIndex, required this.srcRect});

  final int frameIndex;
  final Rect srcRect;
}

class _TurretAtlasLoadResult {
  const _TurretAtlasLoadResult({required this.frames});

  final List<_TurretAtlasFrame> frames;
}

class SentryTurret extends BaseEnemy {
  static const String _turretImagePath = 'assets/sprites/enemies/turrel.png';
  static const String _turretAtlasPath =
      'assets/sprites/enemies/turrel_atlas.json';
  static const int _expectedFrameCount = 29;
  static const int _atlasColumns = 4;
  static const int _atlasRows = 8;
  static const double _shootAnimStepTime = 0.04;
  // 14th visual frame (1-based) => index 13 (0-based).
  static const int _shootSpawnFrameIndex = 13;
  static const double _logicalWidth = 96.0;
  static const double _logicalHeight = 64.0;
  static const double _hitboxScale = 1.0;

  PlayerComponent? player;
  late TurretAI ai;

  double _fireCooldown = 0.0;
  Image? _turretImage;
  List<_TurretAtlasFrame> _shootFrames = const [];
  int _shootFrameCursor = 0;
  double _shootFrameTimer = 0.0;
  bool _shootAnimationActive = false;
  bool _didSpawnProjectileInCurrentShoot = false;
  EnemyProjectileComponent? _pendingProjectile;

  @override
  bool get saveFacingRight => false;

  @override
  String get saveState => _shootAnimationActive ? 'shoot' : 'idle';

  double get _hitboxWidth => size.x * _hitboxScale;
  double get _hitboxHeight => size.y * _hitboxScale;
  double get _hitboxOffsetX => (size.x - _hitboxWidth) / 2;
  double get _hitboxOffsetY => (size.y - _hitboxHeight) / 2;

  Rect get localHitboxRect => Rect.fromLTWH(
    _hitboxOffsetX,
    _hitboxOffsetY,
    _hitboxWidth,
    _hitboxHeight,
  );

  Rect get worldHitboxRect {
    final local = localHitboxRect;
    final absolute = absolutePosition;

    if (anchor == Anchor.bottomCenter) {
      return Rect.fromLTWH(
        absolute.x - size.x / 2 + local.left,
        absolute.y - size.y + local.top,
        local.width,
        local.height,
      );
    }

    return Rect.fromLTWH(
      absolute.x - anchor.x * size.x + local.left,
      absolute.y - anchor.y * size.y + local.top,
      local.width,
      local.height,
    );
  }

  @override
  Future<void> onLoad() async {
    useDefaultMovement = false;
    await super.onLoad();
    size = Vector2(_logicalWidth, _logicalHeight);
    maxHealth = GameConfig.sentryTurretMaxHealth;
    health = maxHealth;
    velocity.setZero();
    ai = TurretAI();
    _fireCooldown = GameConfig.sentryTurretFireInterval;
    await _tryInitAtlasAnimation();
  }

  @override
  void update(double dt) {
    if (!isAlive || health <= 0) {
      velocity.setZero();
      return;
    }
    _fireCooldown = (_fireCooldown - dt).clamp(0, double.infinity);
    _updateShootAnimation(dt);
    _tryShootAtPlayer();
    // Movement is unified in BaseEnemy.update().
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final image = _turretImage;
    final frame = _currentFrame;
    if (image == null || frame == null) return;
    _renderAtlasFrame(canvas, image, frame);
  }

  _TurretAtlasFrame? get _currentFrame {
    if (_shootFrames.isEmpty) return null;
    final frameIndex = _shootAnimationActive ? _shootFrameCursor : 0;
    final clamped = frameIndex.clamp(0, _shootFrames.length - 1);
    return _shootFrames[clamped];
  }

  void _updateShootAnimation(double dt) {
    if (!_shootAnimationActive || _shootFrames.isEmpty) {
      _shootFrameCursor = 0;
      _shootFrameTimer = 0;
      return;
    }

    _shootFrameTimer += dt;
    while (_shootFrameTimer >= _shootAnimStepTime) {
      _shootFrameTimer -= _shootAnimStepTime;
      _shootFrameCursor += 1;
      _trySpawnPendingProjectile();
      if (_shootFrameCursor >= _shootFrames.length) {
        _trySpawnPendingProjectile(force: true);
        _shootAnimationActive = false;
        _shootFrameCursor = 0;
        _didSpawnProjectileInCurrentShoot = false;
        break;
      }
    }
  }

  Future<void> _tryInitAtlasAnimation() async {
    final image = await loadUiImageSafe(_turretImagePath);
    if (image == null) {
      print('[TURREL_ERROR] image load failed path=$_turretImagePath');
      _turretImage = null;
      _shootFrames = const [];
      return;
    }

    final atlas = await _loadAtlasFrames(_turretAtlasPath, image);
    if (atlas.frames.isEmpty) {
      print('[TURREL_ERROR] atlas frames empty');
      _turretImage = null;
      _shootFrames = const [];
      return;
    }

    if (atlas.frames.length != _expectedFrameCount) {
      print('[TURREL_ERROR] expected 29 frames, got ${atlas.frames.length}');
      _turretImage = null;
      _shootFrames = const [];
      return;
    }

    _turretImage = image;
    _shootFrames = atlas.frames;
    _shootFrameCursor = 0;
    _shootFrameTimer = 0;
    _shootAnimationActive = false;
    _didSpawnProjectileInCurrentShoot = false;
    _pendingProjectile = null;
  }

  Future<_TurretAtlasLoadResult> _loadAtlasFrames(
    String atlasPath,
    Image image,
  ) async {
    try {
      final rawJson = await rootBundle.loadString(atlasPath);
      final decoded = jsonDecode(rawJson);
      if (decoded is! List) {
        return const _TurretAtlasLoadResult(frames: []);
      }

      final parsed = <_TurretAtlasFrame>[];
      final cellWidth = image.width / _atlasColumns;
      final cellHeight = image.height / _atlasRows;
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final frameIndex = (item['frameIndex'] as num?)?.toInt();
        final width = (item['width'] as num?)?.toDouble();
        final height = (item['height'] as num?)?.toDouble();
        if (frameIndex == null) {
          continue;
        }
        if (width == null || height == null || width <= 0 || height <= 0) {
          continue;
        }

        final col = (item['col'] as num?)?.toDouble();
        final row = (item['row'] as num?)?.toDouble();
        final originalX = (item['originalX'] as num?)?.toDouble();
        final originalY = (item['originalY'] as num?)?.toDouble();

        if (col == null ||
            row == null ||
            originalX == null ||
            originalY == null) {
          continue;
        }

        final srcX = col * cellWidth + originalX;
        final srcY = row * cellHeight + originalY;

        if (srcX < 0 || srcY < 0) {
          continue;
        }
        if (srcX + width > image.width || srcY + height > image.height) {
          print(
            '[TURREL_ERROR] frame $frameIndex src out of bounds: '
            '${Rect.fromLTWH(srcX, srcY, width, height)} '
            'image=${image.width}x${image.height}',
          );
          continue;
        }
        parsed.add(
          _TurretAtlasFrame(
            frameIndex: frameIndex,
            srcRect: Rect.fromLTWH(srcX, srcY, width, height),
          ),
        );
      }
      parsed.sort((a, b) => a.frameIndex.compareTo(b.frameIndex));
      return _TurretAtlasLoadResult(frames: parsed);
    } catch (_) {
      return const _TurretAtlasLoadResult(frames: []);
    }
  }

  void _renderAtlasFrame(Canvas canvas, Image image, _TurretAtlasFrame frame) {
    final dst = Rect.fromLTWH(0, 0, size.x, size.y);
    final paint = Paint()
      ..isAntiAlias = false
      ..filterQuality = FilterQuality.none;

    if (GameConfig.sentryTurretSpriteFacesRight) {
      canvas.save();
      canvas.translate(dst.center.dx, dst.center.dy);
      canvas.scale(-1, 1);
      canvas.translate(-dst.center.dx, -dst.center.dy);
      canvas.drawImageRect(image, frame.srcRect, dst, paint);
      canvas.restore();
      return;
    }
    canvas.drawImageRect(image, frame.srcRect, dst, paint);
  }

  void _tryShootAtPlayer() {
    if (!isAlive || health <= 0) return;
    final playerRef = player;
    if (playerRef == null) return;
    if (_fireCooldown > 0) return;

    if (!ai.canShootStraight(
      position,
      playerRef.position,
      facingRight: false,
    )) {
      return;
    }

    final manager = parent;
    if (manager == null) return;

    final muzzleOffsetX = -size.x * 0.58;
    final muzzleOffsetY = GameConfig.sentryTurretMuzzleOffsetY;
    final projectile = EnemyProjectileComponent()
      ..position = Vector2(
        position.x + muzzleOffsetX,
        position.y + muzzleOffsetY,
      )
      ..velocity = Vector2(
        -GameConfig.sentryTurretProjectileSpeed *
            difficultyProjectileSpeedMultiplier,
        0,
      )
      ..damage =
          GameConfig.sentryTurretProjectileDamage * difficultyDamageMultiplier
      ..lifetime = GameConfig.sentryTurretProjectileLifetime;

    _pendingProjectile = projectile;
    _didSpawnProjectileInCurrentShoot = false;
    _shootAnimationActive = true;
    _shootFrameCursor = 0;
    _shootFrameTimer = 0;

    // Fallback when animation frames are unavailable.
    if (_shootFrames.isEmpty) {
      _trySpawnPendingProjectile(force: true);
      _shootAnimationActive = false;
    }

    _fireCooldown = GameConfig.sentryTurretFireInterval;
  }

  void _trySpawnPendingProjectile({bool force = false}) {
    if (_didSpawnProjectileInCurrentShoot) return;
    final projectile = _pendingProjectile;
    if (projectile == null) return;
    if (!force && _shootFrameCursor < _shootSpawnFrameIndex) return;

    final manager = parent;
    if (manager == null) return;

    try {
      final dynamic projectileHost = manager;
      projectileHost.addProjectile(projectile);
    } catch (_) {
      return;
    }

    _didSpawnProjectileInCurrentShoot = true;
    _pendingProjectile = null;

    final game = findGame();
    if (game is! VoidRelayGame) return;

    if (kDebugMode) {
      debugPrint(
        '[ENEMY_SHOT] type=turret projectile spawned at ${projectile.position}',
      );
    }
    unawaited(game.playEnemyBlasterShotSound());
    if (kDebugMode) {
      debugPrint('[AUDIO] blaster_enemy played for turret');
    }
  }

  @override
  void die() {
    if (!isAlive) return;
    _shootAnimationActive = false;
    _didSpawnProjectileInCurrentShoot = false;
    _pendingProjectile = null;
    _fireCooldown = double.infinity;
    velocity.setZero();
    super.die();
  }
}
