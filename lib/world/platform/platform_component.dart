import 'dart:ui';

import 'package:flame/components.dart';

import '../../config/game_config.dart';
import '../../core/debug/render_trace.dart';
import '../../core/utils/safe_asset_loader.dart';
import '../../player/player_component.dart';

class PlatformVisualConfig {
  static const String underPlatformAssetPath =
      'assets/sprites/world/under_platform.png';
  static const String underPlatformFallbackAssetPath =
      'assets/sprites/world/under_platform.png';
  static const String flyPlatformAssetPath =
      'assets/sprites/world/fly_platform.png';
  static const String defaultPlatformAssetPath =
      'assets/sprites/world/platform.png';

  static const double underPlatformHeight = 110.0;
  static const double flyPlatformHeight = 35.0;

  static const double underPlatformYOffset = 0.0;
  static const double flyPlatformYOffset = 0.0;

  static const bool tileUnderPlatformX = true;
  static const bool tileFlyPlatformX = false;
  static const bool stretchUnderPlatformX = false;
  static const bool stretchFlyPlatformX = true;

  static const bool renderCeilingVisual = false;
  static const double ceilingTopThreshold = 4.0;

  static const int platformVisualPriority = -100;

  static const double topOffsetY = 0.0;
  static const bool hideCollisionRects = true;

  // Crop area (normalized). Defaults to full image for reliable visibility.
  static const double cropLeftN = 0.0;
  static const double cropTopN = 0.0;
  static const double cropWidthN = 1.0;
  static const double cropHeightN = 1.0;
}

enum _PlatformKind { under, fly }

class _LoadedPlatformAsset {
  const _LoadedPlatformAsset({required this.path, required this.image});

  final String path;
  final Image image;
}

class PlatformComponent extends PositionComponent {
  static final Map<String, Image?> _imageCache = {};
  static final Set<String> _missingAssetLogs = {};

  _PlatformKind _platformKind = _PlatformKind.fly;
  bool _isVisualHidden = false;
  String _selectedAssetPath = '';
  Image? _tileImage;
  Rect? _sourceRect;
  bool _didLogInstanceInfo = false;
  Rect? _previousWorldRect;

  PlatformComponent({required Vector2 position, required Vector2 size}) {
    this.position = position;
    this.size = size;
    anchor = Anchor.center;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _previousWorldRect = toRect();

    _isVisualHidden = _shouldHideVisual();
    if (_isVisualHidden) {
      _selectedAssetPath = 'none';
      return;
    }

    _platformKind = _resolvePlatformKind();
    final loaded = await _resolveVisualAsset(_platformKind);
    if (loaded == null) {
      if (_missingAssetLogs.add('platform_visual_all_missing')) {
        if (false)
          print(
            '[PlatformVisual] no platform asset available, rendering skipped',
          );
      }
      return;
    }

    _selectedAssetPath = loaded.path;
    _tileImage = loaded.image;
    _sourceRect = _buildSourceRect(loaded.image);
    _logPlatformLoadInfo();
  }

  @override
  void update(double dt) {
    // Keep previous frame rect for swept collision against moving platforms.
    _previousWorldRect = toRect();
    super.update(dt);
  }

  Rect get previousWorldRect => _previousWorldRect ?? toRect();

  Future<_LoadedPlatformAsset?> _resolveVisualAsset(_PlatformKind kind) async {
    final candidates = kind == _PlatformKind.under
        ? <String>[
            PlatformVisualConfig.underPlatformAssetPath,
            PlatformVisualConfig.underPlatformFallbackAssetPath,
            PlatformVisualConfig.defaultPlatformAssetPath,
          ]
        : <String>[
            PlatformVisualConfig.flyPlatformAssetPath,
            PlatformVisualConfig.defaultPlatformAssetPath,
          ];

    for (final path in candidates) {
      final image = await _loadCachedImage(path);
      if (image != null) {
        return _LoadedPlatformAsset(path: path, image: image);
      }
    }

    return null;
  }

  Future<Image?> _loadCachedImage(String path) async {
    if (_imageCache.containsKey(path)) {
      return _imageCache[path];
    }

    final image = await loadUiImageSafe(path);
    _imageCache[path] = image;

    if (image == null && _missingAssetLogs.add(path)) {
      if (false) print('[PlatformVisual] missing asset=$path');
    }

    return image;
  }

  @override
  void render(Canvas canvas) {
    if (PlayerComponent.debugTraceRenderSequence) {
      if (false)
        RenderTrace.log(
          'Platform.render priority=$priority pos=$position size=$size',
        );
    }
    if (PlayerComponent.debugHideLevelGeometry) {
      return;
    }

    if (!_isVisualHidden) {
      _renderVisualTiles(canvas);
    }

    if (PlayerComponent.debugDrawCollision ||
        !PlatformVisualConfig.hideCollisionRects) {
      final platformRectPaint = Paint()
        ..color = const Color(0x663399FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final platformTopPaint = Paint()
        ..color = const Color(0xFF00FF00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final rect = Rect.fromLTWH(0, 0, size.x, size.y);
      canvas.drawRect(rect, platformRectPaint);
      canvas.drawLine(Offset(0, 0), Offset(size.x, 0), platformTopPaint);
    }
  }

  void _renderVisualTiles(Canvas canvas) {
    final image = _tileImage;
    final sourceRect = _sourceRect;
    if (image == null || sourceRect == null) {
      return;
    }

    final visualHeight = _platformKind == _PlatformKind.under
        ? PlatformVisualConfig.underPlatformHeight
        : PlatformVisualConfig.flyPlatformHeight;
    final yOffset = _platformKind == _PlatformKind.under
        ? PlatformVisualConfig.underPlatformYOffset
        : PlatformVisualConfig.flyPlatformYOffset;
    final tileX = _platformKind == _PlatformKind.under
        ? PlatformVisualConfig.tileUnderPlatformX
        : PlatformVisualConfig.tileFlyPlatformX;
    final stretchX = _platformKind == _PlatformKind.under
        ? PlatformVisualConfig.stretchUnderPlatformX
        : PlatformVisualConfig.stretchFlyPlatformX;
    final useTileMode = tileX && !stretchX;
    final tileWidth = sourceRect.width * (visualHeight / sourceRect.height);
    if (tileWidth <= 0) return;

    if (!_didLogInstanceInfo) {
      _didLogInstanceInfo = true;
      final topY = position.y - size.y / 2;
      final tileCount = (size.x / tileWidth).ceil();
      final firstTileWorldX = position.x - size.x / 2;
      final firstTileWorldY = topY + yOffset + PlatformVisualConfig.topOffsetY;
      final mode = useTileMode ? 'tile' : 'stretch';
      if (false)
        print(
          '[PlatformVisual] type=${_platformKind.name} render=true '
          'asset=$_selectedAssetPath mode=$mode priority=$priority '
          'rect=(${(position.x - size.x / 2).toStringAsFixed(1)},${topY.toStringAsFixed(1)},${size.x.toStringAsFixed(1)}x${size.y.toStringAsFixed(1)}) '
          'visual=(${firstTileWorldX.toStringAsFixed(1)},${firstTileWorldY.toStringAsFixed(1)},${size.x.toStringAsFixed(1)}x${visualHeight.toStringAsFixed(1)}) '
          'tileCount=$tileCount',
        );
    }

    final top = yOffset + PlatformVisualConfig.topOffsetY;
    if (!useTileMode) {
      final dst = Rect.fromLTWH(0, top, size.x, visualHeight);
      canvas.drawImageRect(image, sourceRect, dst, Paint());
      return;
    }

    var x = 0.0;
    final paint = Paint();
    while (x < size.x) {
      final remaining = size.x - x;
      final drawWidth = remaining < tileWidth ? remaining : tileWidth;
      final widthRatio = drawWidth / tileWidth;
      final srcWidth = sourceRect.width * widthRatio;

      final src = Rect.fromLTWH(
        sourceRect.left,
        sourceRect.top,
        srcWidth,
        sourceRect.height,
      );
      final dst = Rect.fromLTWH(x, top, drawWidth, visualHeight);
      canvas.drawImageRect(image, src, dst, paint);
      x += tileWidth;
    }
  }

  bool _shouldHideVisual() {
    final topY = position.y - size.y / 2;
    final isHorizontal = size.x > size.y;
    final isVeryWide = size.x >= GameConfig.defaultWorldWidth * 0.6;
    final isCeiling =
        isHorizontal &&
        isVeryWide &&
        topY <= PlatformVisualConfig.ceilingTopThreshold;

    final isWallLike = !isHorizontal;
    final hide =
        (PlatformVisualConfig.renderCeilingVisual == false && isCeiling) ||
        isWallLike;

    if (hide && !_didLogInstanceInfo) {
      _didLogInstanceInfo = true;
      final reason = isWallLike ? 'wall_boundary' : 'ceiling_boundary';
      if (false)
        print(
          '[PlatformVisual] type=ceiling render=false asset=none '
          'rect=(${(position.x - size.x / 2).toStringAsFixed(1)},${topY.toStringAsFixed(1)},${size.x.toStringAsFixed(1)}x${size.y.toStringAsFixed(1)}) '
          'reason=$reason',
        );
    }

    return hide;
  }

  _PlatformKind _resolvePlatformKind() {
    final topY = position.y - size.y / 2;
    final isHorizontal = size.x > size.y;
    final isNearBottom = topY >= GameConfig.defaultWorldHeight * 0.55;
    final isVeryWide = size.x >= GameConfig.defaultWorldWidth * 0.6;
    final isGroundLikeThickness = size.y >= 60.0;

    if (isHorizontal && isNearBottom && (isVeryWide || isGroundLikeThickness)) {
      return _PlatformKind.under;
    }
    return _PlatformKind.fly;
  }

  Rect _buildSourceRect(Image image) {
    final left = image.width * PlatformVisualConfig.cropLeftN;
    final top = image.height * PlatformVisualConfig.cropTopN;
    final width = image.width * PlatformVisualConfig.cropWidthN;
    final height = image.height * PlatformVisualConfig.cropHeightN;

    final correctedWidth = (left + width > image.width)
        ? (image.width - left).toDouble()
        : width;
    final correctedHeight = (top + height > image.height)
        ? (image.height - top).toDouble()
        : height;

    return Rect.fromLTWH(left, top, correctedWidth, correctedHeight);
  }

  void _logPlatformLoadInfo() {
    final image = _tileImage;
    final sourceRect = _sourceRect;
    if (image == null || sourceRect == null) return;
    if (false)
      print(
        '[PlatformVisual] loadSuccess kind=${_platformKind.name} '
        'asset=$_selectedAssetPath image=${image.width}x${image.height} '
        'crop=(${sourceRect.left.toStringAsFixed(1)},${sourceRect.top.toStringAsFixed(1)},${sourceRect.width.toStringAsFixed(1)}x${sourceRect.height.toStringAsFixed(1)})',
      );
  }
}
