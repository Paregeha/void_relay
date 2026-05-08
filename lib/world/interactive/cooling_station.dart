import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

import '../../config/game_config.dart';
import '../../core/utils/safe_asset_loader.dart';
import '../../flame_game.dart';
import '../../player/player_component.dart';

class _CoolingAtlasFrame {
  const _CoolingAtlasFrame({
    required this.frameIndex,
    required this.srcRect,
    required this.sourceX,
    required this.sourceY,
    required this.sourceW,
    required this.sourceH,
  });

  final int frameIndex;
  final Rect srcRect;
  final int sourceX;
  final int sourceY;
  final int sourceW;
  final int sourceH;
}

class CoolingStation extends PositionComponent {
  static const String _coldImagePath = 'assets/sprites/world/cold.png';
  static const double _width = 40.0;
  static const double _height = 56.0;
  static const double _visualScale = 1.5;
  static const double _visualYOffset = 27.0;
  static const double _animationStepTime = 0.1;
  static const double _sheetFrameWidth = 768.0;
  static const double _sheetFrameHeight = 448.0;
  static const double _sheetAspectRatio = _sheetFrameWidth / _sheetFrameHeight;
  static const int _sheetColumns = 4;
  static const int _totalColdFrameCount = 21;
  static Future<void>? _sharedAnimationLoadFuture;
  static Image? _sharedColdImage;
  static List<_CoolingAtlasFrame> _sharedFrames = const [];

  final PlayerComponent player;
  final String saveId;
  final void Function(String id)? onCollected;
  bool isCollected = false;
  Image? _coldImage;
  List<_CoolingAtlasFrame> _frames = const [];
  int _frameCursor = 0;
  double _frameTimer = 0.0;
  late final Rect _fixedVisualRect;

  CoolingStation({
    required Vector2 position,
    required this.player,
    required this.saveId,
    this.onCollected,
  }) : super(
         position: position,
         size: Vector2(_width, _height),
         anchor: Anchor.bottomCenter,
       );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Keep stable render bounds with source aspect ratio; do not affect collision size.
    final visualHeight = size.y * _visualScale;
    final visualWidth = visualHeight * _sheetAspectRatio;
    final visualX = (size.x - visualWidth) / 2;
    final visualY = size.y - visualHeight + _visualYOffset;
    _fixedVisualRect = Rect.fromLTWH(
      visualX,
      visualY,
      visualWidth,
      visualHeight,
    );
    await _tryInitAnimation();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isCollected) return;

    if (_frames.isNotEmpty) {
      _frameTimer += dt;
      while (_frameTimer >= _animationStepTime) {
        _frameTimer -= _animationStepTime;
        _frameCursor = (_frameCursor + 1) % _frames.length;
      }
    }

    if (toRect().overlaps(player.worldHitboxRect)) {
      collect();
    }
  }

  @override
  void render(Canvas canvas) {
    if (isCollected) return;
    final image = _coldImage;
    if (image == null || _frames.isEmpty) return;

    final frame = _frames[_frameCursor.clamp(0, _frames.length - 1)];
    final paint = Paint()
      ..isAntiAlias = false
      ..filterQuality = FilterQuality.none;
    canvas.drawImageRect(image, frame.srcRect, _fixedVisualRect, paint);
  }

  void collect() {
    if (isCollected) return;
    isCollected = true;
    onCollected?.call(saveId);

    final game = findGame();
    if (game is VoidRelayGame) {
      if (kDebugMode) {
        debugPrint('[PICKUP] cooling collected');
      }
      game.heatSystem?.coolHeat(GameConfig.coolingStationHeatReduce);
      unawaited(game.playCoolingPickupSound());
    }

    removeFromParent();
  }

  Future<void> _tryInitAnimation() async {
    await _ensureSharedAnimationLoaded();
    final image = _sharedColdImage;
    final frames = _sharedFrames;
    if (image == null || frames.isEmpty) {
      _coldImage = null;
      _frames = const [];
      return;
    }

    _coldImage = image;
    _frames = frames;
    _frameCursor = 0;
    _frameTimer = 0.0;
  }

  Future<void> _ensureSharedAnimationLoaded() async {
    final inFlight = _sharedAnimationLoadFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final loadFuture = _loadSharedAnimation();
    _sharedAnimationLoadFuture = loadFuture;
    await loadFuture;
  }

  Future<void> _loadSharedAnimation() async {
    final image = await loadUiImageSafe(_coldImagePath);
    if (image == null) {
      _sharedColdImage = null;
      _sharedFrames = const [];
      return;
    }

    final frames = _buildGridFrames(image);
    if (frames.isEmpty) {
      _sharedColdImage = null;
      _sharedFrames = const [];
      return;
    }

    _sharedColdImage = image;
    _sharedFrames = frames;
  }

  List<_CoolingAtlasFrame> _buildGridFrames(Image image) {
    final parsed = <_CoolingAtlasFrame>[];
    for (var frameIndex = 0; frameIndex < _totalColdFrameCount; frameIndex++) {
      final col = frameIndex % _sheetColumns;
      final row = frameIndex ~/ _sheetColumns;
      final sourceX = (col * _sheetFrameWidth).round();
      final sourceY = (row * _sheetFrameHeight).round();
      final sourceW = _sheetFrameWidth.round();
      final sourceH = _sheetFrameHeight.round();

      if (sourceX < 0 ||
          sourceY < 0 ||
          sourceX + sourceW > image.width ||
          sourceY + sourceH > image.height) {
        continue;
      }

      parsed.add(
        _CoolingAtlasFrame(
          frameIndex: frameIndex,
          srcRect: Rect.fromLTWH(
            sourceX.toDouble(),
            sourceY.toDouble(),
            sourceW.toDouble(),
            sourceH.toDouble(),
          ),
          sourceX: sourceX,
          sourceY: sourceY,
          sourceW: sourceW,
          sourceH: sourceH,
        ),
      );
    }
    assert(parsed.length == _totalColdFrameCount);
    return parsed;
  }
}
