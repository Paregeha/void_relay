import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../config/game_config.dart';
import '../../core/debug/render_trace.dart';
import '../../core/utils/safe_asset_loader.dart';
import '../../player/player_component.dart';

class WorldVisualConfig {
  // Assets
  static const String backAssetPath = 'assets/sprites/world/back.png';
  static const String platformAssetPath = 'assets/sprites/world/platform.png';
  static const String perileAssetPath = 'assets/sprites/world/perile.png';

  // World-space layout in design coordinates (base height = 540)
  static const double groundBaselineY = 440.0;
  static const double platformVisualHeight = 44.0;
  static const double platformYOffset = 0.0;

  static const double perileY = 402.0;
  static const double perileVisualHeight = 24.0;

  static const double perileVisualOffsetY = 0.0;

  static const double platformTileGap = 0.0;
  static const double perileTileGap = 0.0;

  // Cropping in normalized image coordinates to avoid drawing empty canvas area.
  static const double platformCropLeftN = 0.0;
  static const double platformCropTopN = 0.78;
  static const double platformCropWidthN = 1.0;
  static const double platformCropHeightN = 0.22;

  static const double perileCropLeftN = 0.0;
  static const double perileCropTopN = 0.72;
  static const double perileCropWidthN = 1.0;
  static const double perileCropHeightN = 0.28;

  // Background movement
  static const double backgroundParallaxSpeed = 0.2;

  static const int backgroundPriority = -1000;
  static const int perilePriority = -200;
  static const int platformPriority = -100;

  static double scaleYForRoom(Vector2 roomSize) =>
      roomSize.y / GameConfig.defaultWorldHeight;
}

enum WorldVisualLayerType { back, platform, perile }

class BackgroundComponent extends PositionComponent {
  final Vector2 roomSize;
  final WorldVisualLayerType layerType;
  final double parallaxSpeed;

  double _cameraX = 0.0;
  Image? _image;
  Rect? _sourceRect;
  int _tileCount = 0;
  bool _didLogBackCover = false;
  static final Paint _pixelPaint = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none;

  BackgroundComponent({
    required this.roomSize,
    required this.layerType,
    this.parallaxSpeed = 0.0,
  });

  @override
  Future<void> onLoad() async {
    size = roomSize;
    position = Vector2.zero();
    anchor = Anchor.topLeft;

    final assetPath = _assetPathForLayer(layerType);
    _image = await loadUiImageSafe(assetPath);
    if (_image == null) {
      if (false)
        print('[WorldVisual] missing asset=$assetPath layer=${layerType.name}');
      return;
    }

    _sourceRect = _resolveSourceRect(_image!);

    _tileCount = _estimateTileCount();
    _logLayerLoad();
  }

  @override
  void update(double dt) {
    super.update(dt);
    final game = findGame();
    if (game == null) return;
    _cameraX = game.camera.viewfinder.position.x;
  }

  @override
  void render(Canvas canvas) {
    if (PlayerComponent.debugTraceRenderSequence) {
      if (false) RenderTrace.log('Background.render priority=$priority');
    }

    final image = _image;
    final sourceRect = _sourceRect;
    if (image == null || sourceRect == null) {
      return;
    }

    switch (layerType) {
      case WorldVisualLayerType.back:
        _renderBackLayer(canvas, image);
      case WorldVisualLayerType.platform:
        _renderTiledLayer(
          canvas,
          image: image,
          sourceRect: sourceRect,
          topY: _scaledPlatformTopY(),
          visualHeight:
              WorldVisualConfig.platformVisualHeight *
              WorldVisualConfig.scaleYForRoom(roomSize),
          tileGap: WorldVisualConfig.platformTileGap,
        );
      case WorldVisualLayerType.perile:
        _renderTiledLayer(
          canvas,
          image: image,
          sourceRect: sourceRect,
          topY: _scaledPerileTopY(),
          visualHeight:
              WorldVisualConfig.perileVisualHeight *
              WorldVisualConfig.scaleYForRoom(roomSize),
          tileGap: WorldVisualConfig.perileTileGap,
        );
    }
  }

  void _renderBackLayer(Canvas canvas, Image image) {
    final game = findGame();
    final visible =
        game?.camera.visibleWorldRect ??
        Rect.fromLTWH(0, 0, roomSize.x, roomSize.y);
    final sourceRect =
        _sourceRect ??
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());

    // Cover scaling: fill viewport with no black bars.
    final coverScale = math.max(
      visible.width / image.width,
      visible.height / image.height,
    );
    final drawWidth = (image.width * coverScale).roundToDouble();
    final drawHeight = (image.height * coverScale).roundToDouble();

    final centerX = (visible.center.dx - _cameraX * parallaxSpeed)
        .roundToDouble();
    final centerY = visible.center.dy.roundToDouble();
    final baseRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: drawWidth,
      height: drawHeight,
    );

    // Draw center and side copies with 1px overlap to avoid seams.
    canvas.drawImageRect(image, sourceRect, baseRect, _pixelPaint);
    canvas.drawImageRect(
      image,
      sourceRect,
      baseRect.translate(-(drawWidth - 1.0), 0),
      _pixelPaint,
    );
    canvas.drawImageRect(
      image,
      sourceRect,
      baseRect.translate(drawWidth - 1.0, 0),
      _pixelPaint,
    );

    if (!_didLogBackCover) {
      _didLogBackCover = true;
      if (false)
        print(
          '[WorldVisual] viewport=${visible.width.toStringAsFixed(1)}x${visible.height.toStringAsFixed(1)} '
          'backImage=${image.width}x${image.height} '
          'backgroundScale=${coverScale.toStringAsFixed(3)}',
        );
    }
  }

  void _renderTiledLayer(
    Canvas canvas, {
    required Image image,
    required Rect sourceRect,
    required double topY,
    required double visualHeight,
    required double tileGap,
  }) {
    final tileWidth = sourceRect.width * (visualHeight / sourceRect.height);
    if (tileWidth <= 0) return;

    final tileWidthPx = tileWidth.roundToDouble();
    final visualHeightPx = visualHeight.roundToDouble();
    final topYPx = topY.roundToDouble();
    final shiftPx = (-_cameraX * parallaxSpeed).roundToDouble();
    final step = tileWidthPx + tileGap - 1.0;
    if (step <= 0) return;

    for (double x = 0; x <= roomSize.x + step; x += step) {
      final destRect = Rect.fromLTWH(
        shiftPx + x,
        topYPx,
        tileWidthPx,
        visualHeightPx,
      );
      canvas.drawImageRect(image, sourceRect, destRect, _pixelPaint);
    }
  }

  String _assetPathForLayer(WorldVisualLayerType type) {
    switch (type) {
      case WorldVisualLayerType.back:
        return WorldVisualConfig.backAssetPath;
      case WorldVisualLayerType.platform:
        return WorldVisualConfig.platformAssetPath;
      case WorldVisualLayerType.perile:
        return WorldVisualConfig.perileAssetPath;
    }
  }

  int _estimateTileCount() {
    final image = _image;
    final sourceRect = _sourceRect;
    if (image == null || sourceRect == null) return 0;
    if (layerType == WorldVisualLayerType.back) return 1;

    final visualHeight = layerType == WorldVisualLayerType.platform
        ? WorldVisualConfig.platformVisualHeight *
              WorldVisualConfig.scaleYForRoom(roomSize)
        : WorldVisualConfig.perileVisualHeight *
              WorldVisualConfig.scaleYForRoom(roomSize);
    final tileWidth = sourceRect.width * (visualHeight / sourceRect.height);
    if (tileWidth <= 0) return 0;
    final gap = layerType == WorldVisualLayerType.platform
        ? WorldVisualConfig.platformTileGap
        : WorldVisualConfig.perileTileGap;
    final step = tileWidth + gap;
    if (step <= 0) return 0;
    return ((roomSize.x + step) / step).ceil();
  }

  double _scaledPlatformTopY() {
    final scaleY = WorldVisualConfig.scaleYForRoom(roomSize);
    final baselineY =
        roomSize.y *
        (WorldVisualConfig.groundBaselineY / GameConfig.defaultWorldHeight);
    final platformHeight = WorldVisualConfig.platformVisualHeight * scaleY;
    return baselineY -
        platformHeight +
        WorldVisualConfig.platformYOffset * scaleY;
  }

  double _scaledPerileTopY() {
    final ratio = WorldVisualConfig.perileY / GameConfig.defaultWorldHeight;
    return roomSize.y * ratio +
        WorldVisualConfig.perileVisualOffsetY *
            WorldVisualConfig.scaleYForRoom(roomSize);
  }

  Rect _resolveSourceRect(Image image) {
    switch (layerType) {
      case WorldVisualLayerType.back:
        return Rect.fromLTWH(
          0,
          0,
          image.width.toDouble(),
          image.height.toDouble(),
        );
      case WorldVisualLayerType.platform:
        return _cropFromNormalized(
          image,
          leftN: WorldVisualConfig.platformCropLeftN,
          topN: WorldVisualConfig.platformCropTopN,
          widthN: WorldVisualConfig.platformCropWidthN,
          heightN: WorldVisualConfig.platformCropHeightN,
        );
      case WorldVisualLayerType.perile:
        return _cropFromNormalized(
          image,
          leftN: WorldVisualConfig.perileCropLeftN,
          topN: WorldVisualConfig.perileCropTopN,
          widthN: WorldVisualConfig.perileCropWidthN,
          heightN: WorldVisualConfig.perileCropHeightN,
        );
    }
  }

  Rect _cropFromNormalized(
    Image image, {
    required double leftN,
    required double topN,
    required double widthN,
    required double heightN,
  }) {
    final left = (image.width * leftN).clamp(0.0, image.width.toDouble());
    final top = (image.height * topN).clamp(0.0, image.height.toDouble());
    final width = (image.width * widthN).clamp(1.0, image.width.toDouble());
    final height = (image.height * heightN).clamp(1.0, image.height.toDouble());

    final correctedWidth = (left + width > image.width)
        ? (image.width - left).toDouble()
        : width;
    final correctedHeight = (top + height > image.height)
        ? (image.height - top).toDouble()
        : height;

    return Rect.fromLTWH(left, top, correctedWidth, correctedHeight);
  }

  void _logLayerLoad() {
    final image = _image;
    final sourceRect = _sourceRect;
    if (image == null || sourceRect == null) return;

    if (layerType == WorldVisualLayerType.platform) {
      final tileHeight =
          WorldVisualConfig.platformVisualHeight *
          WorldVisualConfig.scaleYForRoom(roomSize);
      final tileWidth = sourceRect.width * (tileHeight / sourceRect.height);
      if (false)
        print(
          '[WorldVisual] platform fullImage=${image.width}x${image.height} '
          'crop=(${sourceRect.left.toStringAsFixed(1)},${sourceRect.top.toStringAsFixed(1)},'
          '${sourceRect.width.toStringAsFixed(1)}x${sourceRect.height.toStringAsFixed(1)}) '
          'tileSize=${tileWidth.toStringAsFixed(1)}x${tileHeight.toStringAsFixed(1)} '
          'platformY=${_scaledPlatformTopY().toStringAsFixed(1)} tileCount=$_tileCount',
        );
      return;
    }

    if (layerType == WorldVisualLayerType.perile) {
      final tileHeight =
          WorldVisualConfig.perileVisualHeight *
          WorldVisualConfig.scaleYForRoom(roomSize);
      final tileWidth = sourceRect.width * (tileHeight / sourceRect.height);
      if (false)
        print(
          '[WorldVisual] perile fullImage=${image.width}x${image.height} '
          'crop=(${sourceRect.left.toStringAsFixed(1)},${sourceRect.top.toStringAsFixed(1)},'
          '${sourceRect.width.toStringAsFixed(1)}x${sourceRect.height.toStringAsFixed(1)}) '
          'tileSize=${tileWidth.toStringAsFixed(1)}x${tileHeight.toStringAsFixed(1)} '
          'perileY=${_scaledPerileTopY().toStringAsFixed(1)} tileCount=$_tileCount',
        );
      return;
    }

    if (false)
      print(
        '[WorldVisual] back fullImage=${image.width}x${image.height} '
        'tileCount=$_tileCount levelWidth=${roomSize.x.toStringAsFixed(1)}',
      );
  }
}
