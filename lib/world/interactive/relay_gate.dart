import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

import '../../core/utils/safe_asset_loader.dart';
import '../../flame_game.dart';
import '../../player/player_component.dart';

enum DoorState { closed, opening, open, closing }

class _DoorAtlasFrame {
  const _DoorAtlasFrame({required this.frameIndex, required this.srcRect});

  final int frameIndex;
  final Rect srcRect;
}

class RelayGate extends PositionComponent {
  static const String _doorImagePath = 'assets/sprites/world/door.png';
  // Source frame size in atlas pixels (do not use as world size).
  static const double _sheetFrameW = 768.0;
  static const double _sheetFrameH = 448.0;
  static const int _sheetColumns = 4;
  static const int _sheetRows = 6;
  static const double _sourceAspectRatio = _sheetFrameW / _sheetFrameH;
  static const double _doorBaseWorldH = 72.0;
  static const double _doorScale = 1.3;
  static const double _doorWorldH = _doorBaseWorldH * _doorScale;
  static const double _doorWorldW = _doorWorldH * _sourceAspectRatio;
  static const double _doorYOffset = 15.0;
  // World-space size used for rendering and interactions.
  static const double _width = _doorWorldW;
  static const double _height = _doorWorldH;
  static const double _animationStepTime = 0.1;
  static const double _passThroughProgressThreshold = 0.85;
  static const int _totalDoorFrameCount = 21;

  static Future<void>? _sharedDoorLoadFuture;
  static Image? _sharedDoorImage;
  static List<_DoorAtlasFrame> _sharedDoorFrames = const [];

  final PlayerComponent player;
  final void Function()? onReached;
  final String saveId;

  bool _triggered = false;
  DoorState _state = DoorState.closed;
  double _progress = 0.0;
  bool _wasCloseEventActive = false;
  int _lastBlockedNoticeMs = 0;
  bool _isExitUnlocked;

  Image? _doorImage;
  List<_DoorAtlasFrame> _frames = const [];
  late final Rect _fixedVisualRect;

  RelayGate({
    required Vector2 position,
    required this.player,
    required this.saveId,
    this.onReached,
    bool isExitUnlocked = false,
  }) : _isExitUnlocked = isExitUnlocked,
       super(
         position: position,
         size: Vector2(_width, _height),
         anchor: Anchor.bottomCenter,
       );

  DoorState get currentDoorState => _state;

  double get doorProgress => _progress;

  bool get isTriggered => _triggered;

  bool get wasCloseEventActive => _wasCloseEventActive;

  void restoreState({
    required DoorState state,
    required double progress,
    required bool triggered,
    required bool closeEventActive,
  }) {
    _state = state;
    _progress = progress.clamp(0.0, 1.0);
    _triggered = triggered;
    _wasCloseEventActive = closeEventActive;
    _isExitUnlocked = state == DoorState.open || state == DoorState.opening;
  }

  void unlockDoor() {
    if (_isExitUnlocked) return;
    _isExitUnlocked = true;
    if (_state == DoorState.closed || _state == DoorState.closing) {
      _setState(DoorState.opening);
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    assert(_sheetFrameW > 0 && _sheetFrameH > 0);
    // Shift the whole component so visual and collision stay aligned.
    position.y += _doorYOffset;
    final visualX = (size.x - _doorWorldW) / 2;
    final visualY = size.y - _doorWorldH;
    _fixedVisualRect = Rect.fromLTWH(
      visualX,
      visualY,
      _doorWorldW,
      _doorWorldH,
    );
    await _tryInitDoorAnimation();
  }

  @override
  void renderDebugMode(Canvas canvas) {
    // Suppress component debug outline for gameplay visuals.
  }

  @override
  void update(double dt) {
    super.update(dt);
    final game = findGame();
    final isDoorFailureActive =
        game is VoidRelayGame && game.isDoorFailureActive;

    _syncDoorState(
      dt: dt,
      closeEventActive: isDoorFailureActive,
      game: game is VoidRelayGame ? game : null,
    );

    if (_triggered) return;
    if (isDoorFailureActive) return;

    final isOverlapping = toRect().overlaps(player.worldHitboxRect);
    if (!isOverlapping) return;

    if (game is VoidRelayGame) {
      final world = game.gameWorld;
      if (world != null && !world.canUseLevelExit()) {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        if (nowMs - _lastBlockedNoticeMs > 600) {
          _lastBlockedNoticeMs = nowMs;
          game.notifyLevelExitBlocked(enemiesAlive: world.aliveHostilesCount);
        }
        return;
      }
    }

    if (!_canPlayerPassThroughGate) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (nowMs - _lastBlockedNoticeMs > 600) {
        _lastBlockedNoticeMs = nowMs;
        final world = game is VoidRelayGame ? game.gameWorld : null;
        final alive = world?.aliveHostilesCount ?? 0;
        if (alive > 0) {
          debugPrint('[LEVEL_EXIT] blocked: enemiesAlive=$alive');
        } else {
          debugPrint('[LEVEL_EXIT] blocked: door not open');
        }
      }
      return;
    }

    if (game is VoidRelayGame && kDebugMode) {
      debugPrint(
        '[LEVEL_EXIT] player entered opened door: showing sector reward',
      );
    }
    _triggered = true;
    onReached?.call();
  }

  @override
  void render(Canvas canvas) {
    final image = _doorImage;
    if (image == null || _frames.isEmpty) return;

    final frameIndex = (_progress * (_frames.length - 1)).round().clamp(
      0,
      _frames.length - 1,
    );
    final frame = _frames[frameIndex];
    final paint = Paint()
      ..isAntiAlias = false
      ..filterQuality = FilterQuality.none;
    canvas.drawImageRect(image, frame.srcRect, _fixedVisualRect, paint);
  }

  bool get _canPlayerPassThroughGate {
    if (_state == DoorState.open) return true;
    return _state == DoorState.opening &&
        _progress >= _passThroughProgressThreshold;
  }


  bool _isVisibleToPlayer(VoidRelayGame? game) {
    if (game == null) return true;
    return game.camera.visibleWorldRect.overlaps(toRect());
  }

  void _syncDoorState({
    required double dt,
    required bool closeEventActive,
    required VoidRelayGame? game,
  }) {
    if (closeEventActive && !_wasCloseEventActive) {
      final visible = _isVisibleToPlayer(game);
      if (visible) {
        if (_state == DoorState.open || _state == DoorState.opening) {
          _setState(DoorState.closing);
        }
      } else {
        _progress = 0;
        _setState(DoorState.closed);
      }
    }

    if (closeEventActive) {
      if (_state == DoorState.open || _state == DoorState.opening) {
        final visible = _isVisibleToPlayer(game);
        if (visible) {
          _setState(DoorState.closing);
        } else {
          _progress = 0;
          _setState(DoorState.closed);
        }
      }
    } else if (_isExitUnlocked &&
        (_state == DoorState.closed || _state == DoorState.closing)) {
      _setState(DoorState.opening);
    } else if (!_isExitUnlocked &&
        (_state == DoorState.open || _state == DoorState.opening)) {
      _setState(DoorState.closing);
    }

    _advanceAnimation(dt);
    _wasCloseEventActive = closeEventActive;
  }

  void _advanceAnimation(double dt) {
    final totalFrameSteps = (_frames.length - 1).clamp(1, 9999).toDouble();
    final duration = totalFrameSteps * _animationStepTime;
    if (duration <= 0) {
      return;
    }

    switch (_state) {
      case DoorState.closed:
        _progress = 0;
        break;
      case DoorState.open:
        _progress = 1;
        break;
      case DoorState.opening:
        _progress = (_progress + dt / duration).clamp(0.0, 1.0);
        if (_progress >= 1) {
          _progress = 1;
          _setState(DoorState.open);
          if (kDebugMode) {
            debugPrint('[LEVEL_EXIT] door opened');
          }
        }
        break;
      case DoorState.closing:
        _progress = (_progress - dt / duration).clamp(0.0, 1.0);
        if (_progress <= 0) {
          _progress = 0;
          _setState(DoorState.closed);
        }
        break;
    }
  }

  void _setState(DoorState next) {
    if (_state == next) return;
    final previous = _state;
    _state = next;

    final startedOpening =
        previous == DoorState.closed && next == DoorState.opening;
    final startedClosing =
        (previous == DoorState.open || previous == DoorState.opening) &&
        next == DoorState.closing;
    if (startedOpening || startedClosing) {
      final game = findGame();
      if (game is VoidRelayGame) {
        unawaited(game.playDoorSound());
      }
    }
  }

  Future<void> _tryInitDoorAnimation() async {
    await _ensureSharedDoorLoaded();
    final image = _sharedDoorImage;
    final frames = _sharedDoorFrames;
    if (image == null || frames.isEmpty) {
      _doorImage = null;
      _frames = const [];
      return;
    }

    _doorImage = image;
    _frames = frames;
    _progress = 0;
    _setState(DoorState.closed);
  }

  Future<void> _ensureSharedDoorLoaded() async {
    final inFlight = _sharedDoorLoadFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final loadFuture = _loadSharedDoorAnimation();
    _sharedDoorLoadFuture = loadFuture;
    await loadFuture;
  }

  Future<void> _loadSharedDoorAnimation() async {
    final image = await loadUiImageSafe(_doorImagePath);
    if (image == null) {
      _sharedDoorImage = null;
      _sharedDoorFrames = const [];
      return;
    }

    final frames = _buildGridFrames(image);
    if (frames.isEmpty) {
      _sharedDoorImage = null;
      _sharedDoorFrames = const [];
      return;
    }

    _sharedDoorImage = image;
    _sharedDoorFrames = frames;
  }

  List<_DoorAtlasFrame> _buildGridFrames(Image image) {
    final parsed = <_DoorAtlasFrame>[];
    for (var frameIndex = 0; frameIndex < _totalDoorFrameCount; frameIndex++) {
      final col = frameIndex % _sheetColumns;
      final row = frameIndex ~/ _sheetColumns;
      final srcX = col * _sheetFrameW;
      final srcY = row * _sheetFrameH;
      final srcRect = Rect.fromLTWH(srcX, srcY, _sheetFrameW, _sheetFrameH);

      if (row >= _sheetRows ||
          srcRect.right > image.width ||
          srcRect.bottom > image.height) {
        continue;
      }

      parsed.add(_DoorAtlasFrame(frameIndex: frameIndex, srcRect: srcRect));
    }

    if (parsed.length != _totalDoorFrameCount) {
      return const [];
    }
    return parsed;
  }
}
