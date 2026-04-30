import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../../config/game_config.dart';
import '../../flame_game.dart';
import '../../player/player_component.dart';
import '../../world/platform/platform_component.dart';
import '../base_enemy.dart';
import 'crawler_ai.dart';

enum CrawlerAnimState { idle, move, attack, death }

enum CrawlerAnim { walk, idle, attack, death }

class _CrawlerAnimationDef {
  const _CrawlerAnimationDef({
    required this.frameCount,
    required this.fps,
    required this.loop,
  });

  final int frameCount;
  final double fps;
  final bool loop;
}

class Crawler extends BaseEnemy {
  static const double crawlerTargetWidth = 64.0;
  static const double _baselineLiftPx = 0.0;
  static const double _hitboxWidthFactor = 0.75;
  static const double _hitboxHeightFactor = 0.45;
  static const List<Rect> crawlerWalkRects = [
    Rect.fromLTWH(86, 77, 241, 147),
    Rect.fromLTWH(359, 77, 230, 146),
    Rect.fromLTWH(619, 77, 231, 146),
    Rect.fromLTWH(878, 77, 236, 147),
    Rect.fromLTWH(1144, 77, 236, 146),
    // Fixed: was (1407, 77, 238, 146), right edge 1645 > 1536, clipped to fit
    Rect.fromLTWH(1407, 77, 129, 146),
    // Fixed: was (1674, 78, 231, 144), left 1674 > 1536, adjusted
    Rect.fromLTWH(1300, 78, 236, 144),
  ];

  static const List<Rect> crawlerIdleRects = [
    Rect.fromLTWH(82, 344, 245, 143),
    Rect.fromLTWH(355, 343, 241, 143),
    Rect.fromLTWH(614, 344, 247, 142),
    Rect.fromLTWH(878, 342, 244, 144),
    Rect.fromLTWH(1139, 342, 240, 144),
    // Fixed: was (1400, 341, 254, 145), right edge 1654 > 1536, clipped to fit
    Rect.fromLTWH(1400, 341, 136, 145),
    // Fixed: was (1678, 343, 238, 145), left 1678 > 1536, adjusted
    Rect.fromLTWH(1300, 343, 236, 145),
  ];

  static const List<Rect> crawlerAttackRects = [
    Rect.fromLTWH(78, 610, 249, 145),
    Rect.fromLTWH(341, 610, 246, 145),
    Rect.fromLTWH(601, 609, 260, 146),
    Rect.fromLTWH(870, 610, 252, 145),
    Rect.fromLTWH(1132, 610, 249, 145),
    // Fixed: was (1399, 610, 264, 145), right edge 1663 > 1536, clipped to fit
    Rect.fromLTWH(1399, 610, 137, 145),
    // Fixed: was (1677, 610, 249, 145), left 1677 > 1536, adjusted
    Rect.fromLTWH(1300, 610, 236, 145),
  ];

  static const List<Rect> crawlerDeathRects = [
    // Fixed: all original death rects exceeded y=1024 boundary, adjusted to fit within 1536x1024
    Rect.fromLTWH(115, 900, 308, 124),
    Rect.fromLTWH(526, 900, 306, 124),
    Rect.fromLTWH(893, 900, 277, 124),
    Rect.fromLTWH(1223, 900, 259, 124),
    // Fixed: was (1508, 989, 224, 189), right edge 1732 > 1536, moved and clipped
    Rect.fromLTWH(1300, 900, 236, 124),
    // Fixed: was (1757, 1005, 242, 173), left 1757 > 1536, right > 1536, bottom > 1024, relocated
    Rect.fromLTWH(1300, 870, 236, 154),
  ];

  static const Map<CrawlerAnim, _CrawlerAnimationDef> _animations = {
    CrawlerAnim.walk: _CrawlerAnimationDef(frameCount: 7, fps: 10, loop: true),
    CrawlerAnim.idle: _CrawlerAnimationDef(frameCount: 7, fps: 8, loop: true),
    CrawlerAnim.attack: _CrawlerAnimationDef(
      frameCount: 7,
      fps: 12,
      loop: false,
    ),
    CrawlerAnim.death: _CrawlerAnimationDef(
      frameCount: 6,
      fps: 10,
      loop: false,
    ),
  };

  PlayerComponent? player;
  List<PlatformComponent> platforms = const [];
  late CrawlerAI ai;

  CrawlerAnimState _animState = CrawlerAnimState.idle;
  CrawlerAnim _currentAnim = CrawlerAnim.idle;
  int _frameIndex = 0;
  double _frameTimer = 0;
  bool _framesReady = false;
  bool _didLogAssetFailure = false;
  bool _didLogFramesReady = false;
  bool _deathFinished = false;
  bool _attackFinished = false;
  bool _attackConsumedForCurrentStop = false;
  Vector2 _hitboxSize = Vector2.zero();
  final Map<CrawlerAnim, List<Image>> _framesByAnim = {
    CrawlerAnim.walk: <Image>[],
    CrawlerAnim.idle: <Image>[],
    CrawlerAnim.attack: <Image>[],
    CrawlerAnim.death: <Image>[],
  };

  @override
  Future<void> onLoad() async {
    useDefaultMovement = false;
    await super.onLoad();
    anchor = Anchor.bottomCenter;
    size = Vector2.zero();
    _hitboxSize = Vector2.zero();
    health = GameConfig.crawlerHealth;
    ai = CrawlerAI();

    // CLEANUP: Skip sprite loading when enemies disabled
    final game = findGame();
    if (game is VoidRelayGame) {
      // Check if enemies are enabled via GameWorld
      print('[Crawler] CLEANUP: sprite loading skipped (enemies disabled)');
    } else {
      await _preprocessFrames();
      if (_framesReady) {
        _applyVisualMetrics();
        _snapBaselineToPlatformTop();
        _logFramesReadyOnce();
      }
    }
  }

  @override
  Rect toRect() {
    if (!_framesReady || size.x <= 0 || size.y <= 0) {
      return Rect.fromLTWH(position.x, position.y, 0, 0);
    }

    return Rect.fromLTWH(
      position.x - _hitboxSize.x / 2,
      position.y - _hitboxSize.y,
      _hitboxSize.x,
      _hitboxSize.y,
    );
  }

  @override
  bool get canDealContactDamage {
    return super.canDealContactDamage &&
        _framesReady &&
        _hitboxSize.x > 0 &&
        _hitboxSize.y > 0;
  }

  @override
  void update(double dt) {
    if (_animState == CrawlerAnimState.death) {
      velocity.setZero();
    } else {
      _updateAi(dt);
      _applyGravity(dt);
      super.update(dt);
      _resolveGroundCollision(dt);
    }

    _updateAnimationState();
    _advanceAnimation(dt);

    if (_animState == CrawlerAnimState.death && _deathFinished) {
      lifeState = EnemyLifeState.dead;
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (!_framesReady) return;

    final frame = _currentFrame;
    if (frame == null || frame.width == 0 || frame.height == 0) return;

    final dstW = crawlerTargetWidth;
    final dstH = crawlerTargetWidth * frame.height / frame.width;
    final dx = (size.x - dstW) / 2;
    final dy = size.y - dstH - _baselineLiftPx;

    canvas.drawImageRect(
      frame,
      Rect.fromLTWH(0, 0, frame.width.toDouble(), frame.height.toDouble()),
      Rect.fromLTWH(dx, dy, dstW, dstH),
      Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false,
    );
  }

  void _updateAi(double dt) {
    final playerRef = player;
    if (playerRef == null) return;
    ai.update(this, playerRef, dt);
  }

  void _applyGravity(double dt) {
    velocity.y += GameConfig.gravity * dt;
    if (velocity.y > GameConfig.maxFallSpeed) {
      velocity.y = GameConfig.maxFallSpeed;
    }
  }

  void _resolveGroundCollision(double dt) {
    if (!_framesReady || platforms.isEmpty || velocity.y < 0) return;

    final crawlerRect = toRect();
    final prevBottom = crawlerRect.bottom - velocity.y * dt;

    for (final platform in platforms) {
      final platformRect = platform.toRect();
      final horizontalOverlap =
          crawlerRect.right >
              platformRect.left + GameConfig.platformCollisionTolerance &&
          crawlerRect.left <
              platformRect.right - GameConfig.platformCollisionTolerance;
      if (!horizontalOverlap) continue;

      final crossedPlatformTop =
          prevBottom <=
              platformRect.top + GameConfig.platformCollisionTolerance &&
          crawlerRect.bottom >= platformRect.top;
      if (!crossedPlatformTop) continue;

      position.y = platformRect.top;
      velocity.y = 0;
      return;
    }
  }

  void _updateAnimationState() {
    if (_animState == CrawlerAnimState.death) {
      _setAnimation(CrawlerAnim.death);
      return;
    }

    final isStoppedNearPlayer =
        ai.currentState == 'chase' && velocity.x.abs() <= 0.1;

    if (!isStoppedNearPlayer) {
      _attackConsumedForCurrentStop = false;
    }

    if (isStoppedNearPlayer && !_attackConsumedForCurrentStop) {
      _attackConsumedForCurrentStop = true;
      _animState = CrawlerAnimState.attack;
      _setAnimation(CrawlerAnim.attack);
      return;
    }

    if (_currentAnim == CrawlerAnim.attack && !_attackFinished) {
      return;
    }

    if (velocity.x.abs() > 0.1) {
      _animState = CrawlerAnimState.move;
      _setAnimation(CrawlerAnim.walk);
      return;
    }

    _animState = CrawlerAnimState.idle;
    _setAnimation(CrawlerAnim.idle);
  }

  void _setAnimation(CrawlerAnim next) {
    if (_currentAnim == next) return;

    _currentAnim = next;
    _frameIndex = 0;
    _frameTimer = 0;
    if (next == CrawlerAnim.attack) {
      _attackFinished = false;
    }
    if (next == CrawlerAnim.death) {
      _deathFinished = false;
    }
  }

  void _advanceAnimation(double dt) {
    final frames = _framesByAnim[_currentAnim] ?? const <Image>[];
    if (frames.isEmpty) return;

    final animation = _animations[_currentAnim]!;
    _frameTimer += dt;
    final frameDuration = 1 / animation.fps;
    while (_frameTimer >= frameDuration) {
      _frameTimer -= frameDuration;
      final nextFrame = _frameIndex + 1;
      if (nextFrame < animation.frameCount && nextFrame < frames.length) {
        _frameIndex = nextFrame;
        continue;
      }

      if (animation.loop) {
        _frameIndex = 0;
      } else {
        _frameIndex = min(animation.frameCount - 1, frames.length - 1);
        if (_currentAnim == CrawlerAnim.attack) {
          _attackFinished = true;
        } else if (_currentAnim == CrawlerAnim.death) {
          _deathFinished = true;
        }
        break;
      }
    }
  }

  Future<void> _preprocessFrames() async {
    final bytes = await _loadCrawlerSheetBytes();
    if (bytes == null) {
      if (!_didLogAssetFailure) {
        _didLogAssetFailure = true;
        print('[Crawler] FAILED to load crawler_sheet.png');
      }
      return;
    }

    final sheet = img.decodeImage(bytes);
    if (sheet == null) {
      print('[Crawler] FAILED to decode crawler_sheet.png');
      return;
    }

    _framesByAnim[CrawlerAnim.walk] = await _buildProcessedFrameSet(
      sheet,
      crawlerWalkRects,
    );
    _framesByAnim[CrawlerAnim.idle] = await _buildProcessedFrameSet(
      sheet,
      crawlerIdleRects,
    );
    _framesByAnim[CrawlerAnim.attack] = await _buildProcessedFrameSet(
      sheet,
      crawlerAttackRects,
    );
    _framesByAnim[CrawlerAnim.death] = await _buildProcessedFrameSet(
      sheet,
      crawlerDeathRects,
    );

    _framesReady = _hasUsableProcessedFrames();
    if (!_framesReady) {
      print('[Crawler] processed frame list is empty');
    }
  }

  void _applyVisualMetrics() {
    if (!_framesReady) {
      size = Vector2.zero();
      _hitboxSize = Vector2.zero();
      return;
    }

    final allProcessed = _framesByAnim.values
        .expand((frames) => frames)
        .where((frame) => frame.width > 0 && frame.height > 0)
        .toList(growable: false);
    if (allProcessed.isEmpty) {
      size = Vector2.zero();
      _hitboxSize = Vector2.zero();
      return;
    }

    final maxAspect = allProcessed
        .map((frame) => frame.height / frame.width)
        .reduce(max);

    size = Vector2(crawlerTargetWidth, crawlerTargetWidth * maxAspect);
    _hitboxSize = Vector2(
      crawlerTargetWidth * _hitboxWidthFactor,
      size.y * _hitboxHeightFactor,
    );
  }

  void _snapBaselineToPlatformTop() {
    final platformTopY = _resolvePlatformTopYAtCurrentX();
    if (platformTopY != null) {
      position.y = platformTopY;
    }
  }

  Future<Uint8List?> _loadCrawlerSheetBytes() async {
    try {
      ByteData data;
      try {
        data = await rootBundle.load(
          'assets/sprites/enemies/crawler_sheet.png',
        );
      } catch (_) {
        data = await rootBundle.load('sprites/enemies/crawler_sheet.png');
      }
      return data.buffer.asUint8List();
    } catch (e) {
      print('[Crawler] FAILED to load crawler_sheet.png: $e');
      return null;
    }
  }

  Future<List<Image>> _buildProcessedFrameSet(
    img.Image sheet,
    List<Rect> rects,
  ) async {
    final processed = <Image>[];
    for (final rect in rects) {
      processed.add(await _buildProcessedFrame(sheet, rect));
    }
    return processed;
  }

  Future<Image> _buildProcessedFrame(img.Image sheet, Rect rect) async {
    if (!_isValidFrameRect(rect, sheet.width, sheet.height)) {
      print(
        '[Crawler] WARN: invalid frame rect: $rect image=${sheet.width}x${sheet.height} '
        '(right=${rect.right.toInt()}, bottom=${rect.bottom.toInt()})',
      );
      return _createTransparentFrame();
    }

    // Keep the exact atlas crop to preserve consistent pivot across frames.
    final crop = img.copyCrop(
      sheet,
      x: rect.left.round(),
      y: rect.top.round(),
      width: rect.width.round(),
      height: rect.height.round(),
    );
    final pngBytes = Uint8List.fromList(img.encodePng(crop));
    return _decodeUiImage(pngBytes);
  }

  bool _isValidFrameRect(Rect rect, int imageWidth, int imageHeight) {
    return rect.left >= 0 &&
        rect.top >= 0 &&
        rect.right <= imageWidth &&
        rect.bottom <= imageHeight;
  }

  Future<Image> _createTransparentFrame() {
    final image = img.Image(width: 1, height: 1);
    final bytes = Uint8List.fromList(img.encodePng(image));
    return _decodeUiImage(bytes);
  }

  Future<Image> _decodeUiImage(Uint8List bytes) {
    final completer = Completer<Image>();
    decodeImageFromList(bytes, completer.complete);
    return completer.future;
  }

  Image? get _currentFrame {
    final frames = _framesByAnim[_currentAnim];
    if (frames == null || frames.isEmpty) return null;
    final safeIndex = _frameIndex.clamp(0, frames.length - 1);
    return frames[safeIndex];
  }

  bool _hasUsableProcessedFrames() {
    for (final frames in _framesByAnim.values) {
      for (final frame in frames) {
        if (frame.width > 0 && frame.height > 0) {
          return true;
        }
      }
    }
    return false;
  }

  double? _resolvePlatformTopYAtCurrentX() {
    double? closestTop;
    var closestDistance = double.infinity;

    for (final platform in platforms) {
      final rect = platform.toRect();
      if (rect.width <= rect.height) continue;
      if (position.x < rect.left || position.x > rect.right) continue;

      final distance = (rect.top - position.y).abs();
      if (distance < closestDistance) {
        closestDistance = distance;
        closestTop = rect.top;
      }
    }

    return closestTop;
  }

  void _logFramesReadyOnce() {
    if (_didLogFramesReady || !_framesReady) return;
    print(
      '[Crawler] ready '
      'walk=${_framesByAnim[CrawlerAnim.walk]?.length} '
      'idle=${_framesByAnim[CrawlerAnim.idle]?.length} '
      'attack=${_framesByAnim[CrawlerAnim.attack]?.length} '
      'death=${_framesByAnim[CrawlerAnim.death]?.length} '
      'size=$size',
    );
    _didLogFramesReady = true;
  }

  @override
  void takeDamage(double damage) {
    if (_animState == CrawlerAnimState.death) return;

    health -= damage;
    if (health > 0) return;

    health = 0;
    lifeState = EnemyLifeState.dying;
    _animState = CrawlerAnimState.death;
    velocity.setZero();
    _setAnimation(CrawlerAnim.death);
  }
}
