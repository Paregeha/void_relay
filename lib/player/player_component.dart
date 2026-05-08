import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:void_relay/player/player_controller.dart';

import '../config/game_config.dart';
import '../core/debug/debug_collision_config.dart';
import '../core/debug/render_trace.dart';
import '../core/utils/safe_asset_loader.dart';
import '../flame_game.dart';
import '../sound_assets.dart';
import '../weapons/beam_cutter.dart';
import '../weapons/pulse_blaster.dart';
import '../weapons/weapon_manager.dart';

enum PlayerAnimState { idle, run, jump, dash, gun, death }

enum WeaponType { autoGun, sniperGun }

enum PlayerLifeState { alive, dying, dead }

class _AtlasFrameDef {
  const _AtlasFrameDef({
    required this.frameIndex,
    required this.row,
    required this.col,
    required this.src,
    required this.originalX,
    required this.originalY,
  });

  final int frameIndex;
  final int row;
  final int col;
  final Rect src; // x, y, width, height in PNG sheet
  final double originalX; // placement within logical 768x448 frame
  final double originalY; // placement within logical 768x448 frame
}

class _AtlasAnimationBundle {
  const _AtlasAnimationBundle({
    required this.imagePath,
    required this.atlasPath,
    required this.image,
    required this.frames,
  });

  static const double logicalFrameWidth = 768.0;
  static const double logicalFrameHeight = 448.0;

  final String imagePath;
  final String atlasPath;
  final Image image;
  final List<_AtlasFrameDef> frames;

  double get maxWidth =>
      frames.isEmpty ? 0 : frames.map((f) => f.src.width).reduce(max);
  double get maxHeight =>
      frames.isEmpty ? 0 : frames.map((f) => f.src.height).reduce(max);
}

class _DebugAnimMeta {
  const _DebugAnimMeta({
    required this.label,
    required this.frameCount,
    required this.stepTime,
    required this.loop,
    required this.bundle,
  });

  final String label;
  final int frameCount;
  final double stepTime;
  final bool loop;
  final _AtlasAnimationBundle? bundle;
}

class _PlayerVisualData {
  const _PlayerVisualData({
    required this.bundles,
    required this.debugMeta,
    required this.scaleMultipliers,
    required this.renderOffsetsLogical,
  });

  final Map<PlayerAnimState, _AtlasAnimationBundle> bundles;
  final Map<PlayerAnimState, _DebugAnimMeta> debugMeta;
  final Map<PlayerAnimState, double> scaleMultipliers;
  final Map<PlayerAnimState, Offset> renderOffsetsLogical;
}

class _WeaponAssetPaths {
  const _WeaponAssetPaths({
    required this.imagePath,
    required this.atlasPath,
    required this.label,
  });

  final String imagePath;
  final String atlasPath;
  final String label;
}

class _PlayerAnimationRenderer extends PositionComponent {
  final Map<PlayerAnimState, _AtlasAnimationBundle> bundles;
  final Map<PlayerAnimState, _DebugAnimMeta> debugMeta;
  final Map<PlayerAnimState, double> scaleMultipliers;
  final Map<PlayerAnimState, Offset> renderOffsetsLogical;
  final double desiredVisualHeight;
  final Vector2 parentGameplaySize;

  PlayerAnimState currentState = PlayerAnimState.idle;

  /// Index into the sorted [frames] list. Advances strictly +1 per stepTime.
  /// Never computed via row/col/originalX/originalY — only list position.
  int currentFrameIndex = 0;

  /// Accumulates time between frame advances. Resets on each advance.
  double _frameTimer = 0.0;

  // Legacy fields kept so existing callers still compile
  double animTimer = 0.0;
  int lastLoggedFrame = -1;
  double lastLogTime = 0.0;

  int flipScaleX = 1; // 1 or -1 for facing direction

  /// Tracks the last list-index that was actually drawn, for RENDER logging.
  int _lastRenderedListIndex = -1;

  /// DEBUG: counts how many frame advances happened in this update.
  /// Used to detect if while-loop caused multi-advance and created visual jitter.
  int _advancesThisUpdate = 0;

  /// DEBUG: for timing analysis (can be modified by +/- keys in debug mode)
  double _debugTimingMultiplier = 1.0;

  /// DEBUG: show crop info overlay (F1-F4 keys)
  /// 0 = off, 1 = frame info (src/dst rects), 2 = bounds check, 3 = full atlas
  int _debugOverlayMode = 0;

  _PlayerAnimationRenderer({
    required this.bundles,
    required this.debugMeta,
    required this.scaleMultipliers,
    required this.renderOffsetsLogical,
    required this.desiredVisualHeight,
    required this.parentGameplaySize,
  });

  late double _atlasScale;
  late Vector2 visualSize;
  final Map<PlayerAnimState, double> _bundleBaselines = {};
  bool _isPaused = false;
  int _playerRenderCallsThisFrame = 0;
  int _lastRenderFrameMarker = -1;
  bool _canvasSaveCalled = false;
  bool _canvasRestoreCalled = false;
  bool _facingRight = true;
  Rect? _lastVisualDestRect;
  double? _lastVisibleFeetBottomOnScreen;
  bool _didLogDeathHoldLast = false;

  Rect? get lastVisualDestRect => _lastVisualDestRect;
  double? get lastVisibleFeetBottomOnScreen => _lastVisibleFeetBottomOnScreen;

  void _recomputeBundleBaselines() {
    _bundleBaselines.clear();
    for (final entry in bundles.entries) {
      final frames = entry.value.frames;
      if (frames.isEmpty) continue;
      final maxBottom = frames
          .map((f) => f.originalY + f.src.height)
          .reduce(max);
      _bundleBaselines[entry.key] = maxBottom;
    }
  }

  void replaceVisualData({
    required Map<PlayerAnimState, _AtlasAnimationBundle> nextBundles,
    required Map<PlayerAnimState, _DebugAnimMeta> nextDebugMeta,
    required Map<PlayerAnimState, double> nextScaleMultipliers,
    required Map<PlayerAnimState, Offset> nextRenderOffsetsLogical,
    required PlayerAnimState preferredState,
  }) {
    final previousState = currentState;
    final previousBundle = bundles[previousState];
    final previousLen = previousBundle?.frames.length ?? 0;
    final progressRatio = previousLen > 1
        ? currentFrameIndex / (previousLen - 1)
        : 0.0;

    bundles
      ..clear()
      ..addAll(nextBundles);
    debugMeta
      ..clear()
      ..addAll(nextDebugMeta);
    scaleMultipliers
      ..clear()
      ..addAll(nextScaleMultipliers);
    renderOffsetsLogical
      ..clear()
      ..addAll(nextRenderOffsetsLogical);
    _recomputeBundleBaselines();

    final targetState = bundles.containsKey(previousState)
        ? previousState
        : preferredState;
    currentState = targetState;

    final newLen = bundles[targetState]?.frames.length ?? 0;
    if (newLen <= 1) {
      currentFrameIndex = 0;
    } else {
      currentFrameIndex = (progressRatio * (newLen - 1)).round().clamp(
        0,
        newLen - 1,
      );
    }

    _frameTimer = 0.0;
    animTimer = 0.0;
    lastLoggedFrame = -1;
    lastLogTime = 0.0;
    _lastRenderedListIndex = -1;
    _advancesThisUpdate = 0;
    _didLogDeathHoldLast = false;
  }

  Rect buildFullGridSourceRect(_AtlasFrameDef frame) {
    return Rect.fromLTWH(
      frame.col * _AtlasAnimationBundle.logicalFrameWidth,
      frame.row * _AtlasAnimationBundle.logicalFrameHeight,
      _AtlasAnimationBundle.logicalFrameWidth,
      _AtlasAnimationBundle.logicalFrameHeight,
    );
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _atlasScale =
        desiredVisualHeight / _AtlasAnimationBundle.logicalFrameHeight;
    visualSize = Vector2(
      _AtlasAnimationBundle.logicalFrameWidth * _atlasScale,
      _AtlasAnimationBundle.logicalFrameHeight * _atlasScale,
    );
    size = visualSize;
    anchor = Anchor.bottomCenter;
    position = Vector2(parentGameplaySize.x / 2, parentGameplaySize.y);

    if (PlayerComponent.debugAnimationLogs) {
      if (false)
        print(
          '[PlayerBaseline] renderer position=['
          '${position.x.toInt()},${position.y.toInt()}] '
          'anchor=bottomCenter '
          'size=[${size.x.toInt()},${size.y.toInt()}]',
        );
      if (false)
        print(
          '[PlayerVisual] rendererSize=[${size.x.toInt()},${size.y.toInt()}]',
        );
      if (false)
        print(
          '[PlayerVisual] rendererPos=[${position.x.toInt()},${position.y.toInt()}]',
        );
      if (false) print('[PlayerVisual] anchor=bottomCenter');
      if (false)
        print(
          '[PlayerVisual] playerHitbox=[${parentGameplaySize.x.toInt()},${parentGameplaySize.y.toInt()}]',
        );
    }

    // Compute max bottom-Y per animation bundle (for baseline correction)
    _recomputeBundleBaselines();
    for (final entry in _bundleBaselines.entries) {
      final corrY =
          (_AtlasAnimationBundle.logicalFrameHeight - entry.value) *
          _atlasScale;
      if (PlayerComponent._debugRunAtlas &&
          !PlayerComponent.debugIdleTwoFramesOnly) {
        if (false)
          print(
            '[PlayerAtlas] baseline ${entry.key.name}: '
            'animationBaselineY=${entry.value.toInt()} '
            'baselineCorrectionY=${corrY.toStringAsFixed(1)}',
          );
      }
    }

    if (PlayerComponent._debugRunAtlas &&
        !PlayerComponent.debugIdleTwoFramesOnly) {
      if (false)
        print(
          '[PlayerAtlas] visual component: '
          'size=$size position=$position anchor=$anchor '
          'parentGameplaySize=32x64',
        );
    }

    if (PlayerComponent._debugRunAtlas &&
        !PlayerComponent.debugIdleTwoFramesOnly) {
      // ── STARTUP: Show all animation stepTimes ──────────────────────────────
      if (false) print('[PlayerAtlas] TIMING_CONFIG: All animation stepTimes:');
      for (final entry in debugMeta.entries) {
        final state = entry.key;
        final meta = entry.value;
        if (false)
          print(
            '[PlayerAtlas]   ${state.name.padRight(8)} stepTime=${meta.stepTime.toStringAsFixed(4)} '
            'loop=${meta.loop} frames=${meta.bundle?.frames.length ?? 0}',
          );
      }
      if (false)
        print(
          '[PlayerAtlas] TIMING_CONFIG: Use - (minus) to slow down, + (plus) to speed up, Home to reset',
        );
    }

    // ── ATLAS FORMAT: Verify compressed bbox vs full grid ────────────────────
    if (!PlayerComponent._debugRunAtlas ||
        PlayerComponent.debugIdleTwoFramesOnly) {
      return;
    }
    if (false) print('[PlayerAtlas] ATLAS_FORMAT_CHECK:');
    for (final entry in bundles.entries) {
      final state = entry.key;
      final bundle = entry.value;
      if (bundle.frames.isEmpty) continue;

      // Determine atlas type by checking ALL frames, not just first
      bool isCompressed = false;
      for (int i = 0; i < bundle.frames.length; i++) {
        final f = bundle.frames[i];
        const logicalFrameWidth = 768.0;
        const logicalFrameHeight = 448.0;
        final expectedGridX = (f.col * logicalFrameWidth + f.originalX).toInt();
        final expectedGridY = (f.row * logicalFrameHeight + f.originalY)
            .toInt();
        final actualX = f.src.left.toInt();
        final actualY = f.src.top.toInt();

        if (actualX != expectedGridX || actualY != expectedGridY) {
          isCompressed = true;
          break;
        }
      }

      final f = bundle.frames.first;
      const logicalFrameWidth = 768.0;
      const logicalFrameHeight = 448.0;
      final expectedGridX = (f.col * logicalFrameWidth + f.originalX).toInt();
      final expectedGridY = (f.row * logicalFrameHeight + f.originalY).toInt();
      final actualX = f.src.left.toInt();
      final actualY = f.src.top.toInt();

      if (false)
        print(
          '[PlayerAtlas]   ${state.name}: ${isCompressed ? "COMPRESSED_BBOX" : "FULL_GRID_ATLAS"} (checked all frames)\n'
          '    frameIndex=${f.frameIndex} row=${f.row} col=${f.col}\n'
          '    expectedGrid=(${expectedGridX},${expectedGridY})\n'
          '    actualPacked=(${actualX},${actualY})\n'
          '    tight_bbox=(${f.src.width.toInt()}x${f.src.height.toInt()})\n'
          '    logicalOffset=(${f.originalX.toInt()},${f.originalY.toInt()})',
        );
    }

    // ── STARTUP FRAME DUMP: verify atlas src-coords for every bundle ──────
    // Lets us confirm that src rects are row-major and non-overlapping.
    for (final entry in bundles.entries) {
      final state = entry.key;
      final b = entry.value;
      if (b.frames.isEmpty) continue;
      final imageName = b.imagePath.split('/').last;
      if (false)
        print(
          '[PlayerAtlas] FRAME_DUMP state=${state.name} '
          'image=$imageName frames=${b.frames.length}',
        );
      for (final f in b.frames) {
        if (false)
          print(
            '[PlayerAtlas]   listIdx=${b.frames.indexOf(f)} '
            'frameIndex=${f.frameIndex} row=${f.row} col=${f.col} '
            'src=(${f.src.left.toInt()},${f.src.top.toInt()},'
            '${f.src.width.toInt()}x${f.src.height.toInt()}) '
            'orig=(${f.originalX.toInt()},${f.originalY.toInt()})',
          );
      }
    }
  }

  void setPaused(bool val) {
    _isPaused = val;
  }

  void previousFrame() {
    _isPaused = true;
    final bundle = bundles[currentState];
    if (bundle == null || bundle.frames.isEmpty) return;
    currentFrameIndex = (currentFrameIndex - 1).clamp(
      0,
      bundle.frames.length - 1,
    );
    _logFrameDebug();
  }

  void nextFrame() {
    _isPaused = true;
    final bundle = bundles[currentState];
    if (bundle == null || bundle.frames.isEmpty) return;
    currentFrameIndex = (currentFrameIndex + 1) % bundle.frames.length;
    _logFrameDebug();
  }

  void jumpToFrameIndexValue(int frameIndexValue) {
    final bundle = bundles[currentState];
    if (bundle == null || bundle.frames.isEmpty) return;
    final targetListIndex = bundle.frames.indexWhere(
      (f) => f.frameIndex == frameIndexValue,
    );
    if (targetListIndex == -1) return;
    _isPaused = true;
    currentFrameIndex = targetListIndex;
    _logFrameDebug();
  }

  void setAnimationState(PlayerAnimState state) {
    if (currentState == state) return;
    currentState = state;
    // ── FRAME ORDER FIX: reset sequential counter on every state switch ──
    currentFrameIndex = 0; // list index into sorted frames array
    _frameTimer = 0.0; // time accumulator between frame steps
    animTimer = 0.0; // legacy field kept for API compat
    lastLoggedFrame = -1;
    lastLogTime = 0.0;
    _lastRenderedListIndex = -1; // force RENDER log on next draw
    _advancesThisUpdate = 0; // reset counter
    _didLogDeathHoldLast = false;

    final meta = debugMeta[state];
    final effectiveStepTime = meta?.stepTime ?? 0.0;
    if (!PlayerComponent.debugIdleTwoFramesOnly &&
        PlayerComponent.debugAnimationLogs) {
      if (false)
        print(
          '[PlayerAtlas] STATE_SWITCH → ${state.name} '
          'stepTime=${effectiveStepTime.toStringAsFixed(4)} '
          'frames=${bundles[state]?.frames.length ?? 0}',
        );
      if (state == PlayerAnimState.death) {
        if (false) print('[PlayerAnim] DEATH_START frameIndex=0');
      }
    }
  }

  void setFacingDirection(int direction) {
    flipScaleX = (direction < 0 ? -1 : 1);
    _facingRight = direction >= 0;
  }

  void setFacingRight(bool facingRight) {
    _facingRight = facingRight;
    flipScaleX = facingRight ? 1 : -1;
  }

  @override
  void update(double dt) {
    if (_isPaused) return;

    final bundle = bundles[currentState];
    if (bundle == null || bundle.frames.isEmpty) return;

    final meta = debugMeta[currentState];
    if (meta == null || meta.stepTime <= 0) return;

    // Apply debug timing multiplier (from +/- keys in force mode)
    final effectiveStepTime = meta.stepTime / _debugTimingMultiplier;

    // ── FRAME ORDER FIX ─────────────────────────────────────────────────────
    // Frame cursor advances strictly by +1 per stepTime.
    // No division by timer, no row/col math, no originalX/Y math.
    // frames list is pre-sorted by frameIndex ascending (see _loadAtlasBundle).
    // For run/idle: frames contains frameIndex 0–12 only (see _tryInitSpriteVisual).
    //
    // Sequence: listIndex 0 → 1 → 2 → ... → (N-1) → 0  [loop]
    //           listIndex 0 → 1 → 2 → ... → (N-1)       [no loop, hold last]
    // ────────────────────────────────────────────────────────────────────────
    _frameTimer += dt;
    _advancesThisUpdate = 0;

    // Advance frame cursor by exactly +1 for each elapsed stepTime.
    // Using a while-loop handles cases where dt > stepTime (lag spikes).
    while (_frameTimer >= effectiveStepTime) {
      _frameTimer -= effectiveStepTime;

      final prevIndex = currentFrameIndex;
      final frameCount = bundle.frames.length; // use actual list length

      if (meta.loop) {
        // +1 mod frameCount: 0→1→2→...→12→0
        currentFrameIndex = (currentFrameIndex + 1) % frameCount;
      } else {
        // Clamp at last frame (hold final frame, no loop)
        if (currentFrameIndex < frameCount - 1) {
          currentFrameIndex++;
        } else if (currentState == PlayerAnimState.death &&
            !_didLogDeathHoldLast) {
          _didLogDeathHoldLast = true;
          final holdFrame = bundle.frames[currentFrameIndex].frameIndex;
          if (false)
            print('[PlayerAnim] DEATH_HOLD_LAST frameIndex=$holdFrame');
        }
      }

      _advancesThisUpdate++;

      // Log EVERY frame advance — one line per step, validates row-major order.
      // Expected for run/idle:
      //   listIndex=0 frameIndex=0 row=0 col=0
      //   listIndex=1 frameIndex=1 row=0 col=1
      //   listIndex=2 frameIndex=2 row=0 col=2
      //   listIndex=3 frameIndex=3 row=0 col=3
      //   listIndex=4 frameIndex=4 row=1 col=0
      //   ...
      //   listIndex=12 frameIndex=12 row=3 col=0
      //   listIndex=0  frameIndex=0  row=0 col=0  ← loop restart
      if (!PlayerComponent.debugIdleTwoFramesOnly &&
          PlayerComponent.debugAnimationLogs &&
          currentFrameIndex != prevIndex) {
        final frameDef = bundle.frames[currentFrameIndex];
        if (false)
          print(
            '[PlayerAtlas] FRAME_ADVANCE anim=${currentState.name} '
            'listIndex=$currentFrameIndex '
            'frameIndex=${frameDef.frameIndex} '
            'row=${frameDef.row} col=${frameDef.col}',
          );
        if (currentState == PlayerAnimState.death) {
          if (false)
            print(
              '[PlayerDeath] DEATH_FRAME frameIndex=${frameDef.frameIndex}',
            );
        }
      }
    }

    // ── TIMING log: shows dt, frameTimer accumulation, stepTime, how many advances ──
    // Useful for detecting if while-loop caused multi-frame skips.
    // If advancesThisUpdate > 1, this frame may appear jerky.
    if (!PlayerComponent.debugIdleTwoFramesOnly &&
        PlayerComponent.debugAnimationLogs &&
        _advancesThisUpdate > 0) {
      if (false)
        print(
          '[PlayerAtlas] TIMING anim=${currentState.name} '
          'dt=${dt.toStringAsFixed(4)} frameTimer=${_frameTimer.toStringAsFixed(4)} '
          'stepTime=${effectiveStepTime.toStringAsFixed(4)} '
          'advancesThisUpdate=$_advancesThisUpdate '
          '(multiplier=${_debugTimingMultiplier.toStringAsFixed(2)})',
        );
    }

    // Periodic status log every 2 s (snapshot, does not affect playback)
    lastLogTime += dt;
    if (!PlayerComponent.debugIdleTwoFramesOnly &&
        PlayerComponent.debugAnimationLogs &&
        lastLogTime > 2.0) {
      lastLogTime = 0.0;
      _logFrameDebug();
    }
  }

  @override
  void render(Canvas canvas) {
    final bundle = bundles[currentState];
    if (bundle == null || bundle.frames.isEmpty) return;

    final shouldLog =
        !PlayerComponent.debugIdleTwoFramesOnly &&
        PlayerComponent.debugPlayerRenderLogs;

    if (PlayerComponent.debugTraceRenderSequence && shouldLog) {
      if (false)
        RenderTrace.log(
          '_PlayerAnimationRenderer.render START priority=$priority',
        );
    }

    final parentPlayer = parent is PlayerComponent
        ? parent as PlayerComponent
        : null;
    final frameMarker = parentPlayer?.debugRenderFrameMarker ?? -1;
    if (_lastRenderFrameMarker != frameMarker) {
      _lastRenderFrameMarker = frameMarker;
      _playerRenderCallsThisFrame = 0;
    }
    _playerRenderCallsThisFrame++;
    if (shouldLog) {
      if (false)
        print(
          '[RenderTrace] _PlayerAnimationRenderer render call count this frame = '
          '$_playerRenderCallsThisFrame',
        );
    }

    // ── Single source of truth: currentFrameIndex is the list index ──────
    // Never use frameDef.frameIndex as an array index.
    // frameDef.frameIndex / row / col are used ONLY for debug output.
    final listIndex = currentFrameIndex.clamp(0, bundle.frames.length - 1);
    final frameDef = bundle.frames[listIndex]; // ← list index, not frameIndex

    final useFullGridCell =
        PlayerComponent.debugRenderFullGridCell &&
        (currentState == PlayerAnimState.idle ||
            currentState == PlayerAnimState.run ||
            currentState == PlayerAnimState.jump ||
            currentState == PlayerAnimState.death);

    // Full-cell debug mode: use row/col logical cell directly.
    final sourceRect = useFullGridCell
        ? buildFullGridSourceRect(frameDef)
        : Rect.fromLTWH(
            frameDef.src.left,
            frameDef.src.top,
            frameDef.src.width,
            frameDef.src.height,
          );

    final animBaseline =
        _bundleBaselines[currentState] ??
        _AtlasAnimationBundle.logicalFrameHeight;
    final baselineCorrY =
        (_AtlasAnimationBundle.logicalFrameHeight - animBaseline) * _atlasScale;

    final animScaleMultiplier = useFullGridCell
        ? (scaleMultipliers[currentState] ?? 1.0)
        : 1.0;
    final renderWidth = size.x * animScaleMultiplier;
    final renderHeight = size.y * animScaleMultiplier;
    final centeredX = (size.x - renderWidth) / 2;
    const logicalFrameHeight = _AtlasAnimationBundle.logicalFrameHeight;
    final frameVisibleBottomY = frameDef.originalY + frameDef.src.height;
    final frameScale = renderHeight / logicalFrameHeight;
    final visibleBottomCorrectionY =
        (logicalFrameHeight - frameVisibleBottomY) * frameScale;
    final logicalRenderOffset =
        renderOffsetsLogical[currentState] ?? Offset.zero;
    final normalizedOffsetX = logicalRenderOffset.dx * frameScale;
    final normalizedOffsetY = logicalRenderOffset.dy * frameScale;
    final groundOffset = currentState == PlayerAnimState.death
        ? PlayerComponent.deathVisualGroundOffsetY
        : PlayerComponent.visualGroundOffsetY;
    final bottomAlignedY =
        size.y - renderHeight + visibleBottomCorrectionY + groundOffset;

    final destRect = useFullGridCell
        ? Rect.fromLTWH(
            centeredX + normalizedOffsetX,
            bottomAlignedY + normalizedOffsetY,
            renderWidth,
            renderHeight,
          )
        : Rect.fromLTWH(
            frameDef.originalX * _atlasScale + normalizedOffsetX,
            frameDef.originalY * _atlasScale +
                baselineCorrY +
                normalizedOffsetY,
            frameDef.src.width * _atlasScale,
            frameDef.src.height * _atlasScale,
          );
    final visibleFeetBottomOnScreen =
        destRect.top + frameVisibleBottomY * frameScale;
    _lastVisualDestRect = destRect;
    _lastVisibleFeetBottomOnScreen = visibleFeetBottomOnScreen;

    final destX = destRect.left;
    final destY = destRect.top;
    final destW = destRect.width;
    final destH = destRect.height;

    _canvasSaveCalled = false;
    _canvasRestoreCalled = false;
    final isFlipped = !_facingRight && !PlayerComponent.debugForceFacingRight;
    final centerX = size.x / 2.0;
    final centerY = size.y / 2.0;
    if (shouldLog) {
      if (false)
        print(
          '[PlayerFacing] render facingRight=$_facingRight '
          'isFlipped=$isFlipped center=(${centerX.toInt()},${centerY.toInt()})',
        );
    }

    if (shouldLog) {
      final renderWeapon = bundle.imagePath.contains('_sniper_gun')
          ? 'sniperGun'
          : 'autoGun';
      if (false) print('[RenderTrace] PlayerRenderer START');
      if (false)
        print(
          '[PlayerRenderNormalize] weapon=$renderWeapon anim=${currentState.name} '
          'sourceFrame=${frameDef.src.width.toInt()}x${frameDef.src.height.toInt()} '
          'visualSize=${renderWidth.toStringAsFixed(2)}x${renderHeight.toStringAsFixed(2)} '
          'offset=(${normalizedOffsetX.toStringAsFixed(2)},${normalizedOffsetY.toStringAsFixed(2)}) '
          'destRect=$destRect',
        );
      if (false)
        print('[RenderTrace] parentPos=${parentPlayer?.position ?? "unknown"}');
      if (false) print('[RenderTrace] rendererPos=$position');
      if (false) print('[RenderTrace] rendererSize=$size');
      if (false) print('[RenderTrace] anchor=$anchor');
      if (false) print('[RenderTrace] priority=$priority');
      if (false) print('[RenderTrace] anim=${currentState.name}');
      if (false) print('[RenderTrace] listIndex=$listIndex');
      if (false) print('[RenderTrace] frameIndex=${frameDef.frameIndex}');
      if (false) print('[RenderTrace] sourceRect=$sourceRect');
      if (false) print('[RenderTrace] destRect=$destRect');
      if (false)
        print(
          '[RenderTrace] baselineCorrectionY=${baselineCorrY.toStringAsFixed(3)}',
        );
      if (false) print('[RenderTrace] isFlipped=$isFlipped');
    }

    if (listIndex != _lastRenderedListIndex) {
      _lastRenderedListIndex = listIndex;

      if (useFullGridCell && PlayerComponent.debugAnimationLogs) {
        if (currentState == PlayerAnimState.death) {
          if (false)
            print(
              '[PlayerDeath] frameIndex=${frameDef.frameIndex} row=${frameDef.row} col=${frameDef.col} '
              'sourceRect=(${sourceRect.left.toInt()},${sourceRect.top.toInt()},${sourceRect.width.toInt()}x${sourceRect.height.toInt()})',
            );
          if (false)
            print(
              '[PlayerDeath] frameIndex=${frameDef.frameIndex} '
              'visibleBottomY=${frameVisibleBottomY.toStringAsFixed(0)} '
              'correctionY=${visibleBottomCorrectionY.toStringAsFixed(2)} '
              'deathOffsetY=${PlayerComponent.deathVisualGroundOffsetY.toStringAsFixed(2)} '
              'destRect=(${destRect.left.toStringAsFixed(2)},${destRect.top.toStringAsFixed(2)},${destRect.width.toStringAsFixed(2)}x${destRect.height.toStringAsFixed(2)}) '
              'visibleFeetBottomOnScreen=${visibleFeetBottomOnScreen.toStringAsFixed(2)}',
            );
        }
        if (false)
          print(
            '[PlayerFullGrid] anim=${currentState.name} frameIndex=${frameDef.frameIndex} '
            'row=${frameDef.row} col=${frameDef.col} '
            'sourceRect=(${sourceRect.left.toInt()},${sourceRect.top.toInt()},${sourceRect.width.toInt()}x${sourceRect.height.toInt()}) '
            'destRect=(${destRect.left.toInt()},${destRect.top.toInt()},${destRect.width.toInt()}x${destRect.height.toInt()})',
          );
        if (false)
          print(
            '[PlayerAnim] STATE ${currentState.name} frameIndex=${frameDef.frameIndex} '
            'row=${frameDef.row} col=${frameDef.col} '
            'sourceRect=(${sourceRect.left.toInt()},${sourceRect.top.toInt()},${sourceRect.width.toInt()}x${sourceRect.height.toInt()})',
          );
        if (false)
          print(
            '[PlayerScaleNormalize] anim=${currentState.name} '
            'frameIndex=${frameDef.frameIndex} '
            'multiplier=${animScaleMultiplier.toStringAsFixed(2)} '
            'destRect=(${destRect.left.toInt()},${destRect.top.toInt()},${destRect.width.toInt()}x${destRect.height.toInt()})',
          );
        if (false)
          print(
            '[PlayerFeetLock] anim=${currentState.name} frameIndex=${frameDef.frameIndex} '
            'originalY=${frameDef.originalY.toStringAsFixed(0)} '
            'height=${frameDef.src.height.toStringAsFixed(0)} '
            'visibleBottomY=${frameVisibleBottomY.toStringAsFixed(0)} '
            'correctionY=${visibleBottomCorrectionY.toStringAsFixed(2)}',
          );
        if (false)
          print(
            '[PlayerFeetLock] destRect.top=${destRect.top.toStringAsFixed(2)} '
            'destRect.bottom=${destRect.bottom.toStringAsFixed(2)}',
          );
        if (false)
          print(
            '[PlayerFeetLock] expectedFeetBottom=${(size.y + PlayerComponent.visualGroundOffsetY).toStringAsFixed(2)}',
          );
        if (false)
          print(
            '[PlayerFeetLock] visibleFeetBottomOnScreen=${visibleFeetBottomOnScreen.toStringAsFixed(2)}',
          );
        if (false)
          print(
            '[PlayerBaseline] anim=${currentState.name} '
            'multiplier=${animScaleMultiplier.toStringAsFixed(2)} '
            'destRect=(${destRect.left.toStringAsFixed(2)},${destRect.top.toStringAsFixed(2)},${destRect.width.toStringAsFixed(2)}x${destRect.height.toStringAsFixed(2)}) '
            'bottom=${destRect.bottom.toStringAsFixed(2)}',
          );
      }

      // ── RENDER log: fires on every frame change (not every render call) ──
      // Compare with FRAME_ADVANCE logs: listIndex and frameIndex must match.
      if (!shouldLog) {
        // FullCellDebug logs above remain active even when general traces are muted.
      } else {
        final imageName = bundle.imagePath.split('/').last;

        if (false)
          print(
            '[PlayerAtlas] RENDER anim=${currentState.name} image=$imageName '
            'listIndex=$listIndex frameIndex=${frameDef.frameIndex} '
            'row=${frameDef.row} col=${frameDef.col}',
          );

        // ── COMPRESSED BBOX ATLAS ANALYSIS ────────────────────────────────────
        // Determines if atlas uses compressed tight bboxes or full grid layout.
        // For compressed: frame.x ≠ expectedGridX (this is OK!)
        // For full grid: frame.x = expectedGridX
        const logicalFrameWidth = 768.0;
        const logicalFrameHeight = 448.0;
        final expectedGridX =
            (frameDef.col * logicalFrameWidth + frameDef.originalX).toInt();
        final expectedGridY =
            (frameDef.row * logicalFrameHeight + frameDef.originalY).toInt();
        final actualX = frameDef.src.left.toInt();
        final actualY = frameDef.src.top.toInt();

        final isCompressedAtlas =
            actualX != expectedGridX || actualY != expectedGridY;

        if (false)
          print(
            '[PlayerAtlas] ATLAS_ANALYSIS: ${isCompressedAtlas ? "COMPRESSED_BBOX" : "FULL_GRID"}\n'
            '  packedSrc=(${actualX},${actualY},${frameDef.src.width.toInt()}x${frameDef.src.height.toInt()})\n'
            '  logicalOffset=(${frameDef.originalX.toInt()},${frameDef.originalY.toInt()})\n'
            '  gridWouldBe=(${expectedGridX},${expectedGridY})',
          );

        if (false)
          print(
            '[PlayerAtlas] COORDINATES '
            'src=(${frameDef.src.left.toInt()},${frameDef.src.top.toInt()},'
            '${frameDef.src.width.toInt()}x${frameDef.src.height.toInt()}) '
            'dst=(${destX.toInt()},${destY.toInt()},${destW.toInt()}x${destH.toInt()})',
          );

        // ── DEBUG CROP INFO ─────────────────────────────────────────────────────
        // Detailed frame analysis for diagnosing crop/render issues.
        if (_debugOverlayMode > 0) {
          final srcLeftTop = Offset(frameDef.src.left, frameDef.src.top);
          final srcRightBottom = Offset(
            frameDef.src.right,
            frameDef.src.bottom,
          );
          final logicalRightBottom = Offset(
            frameDef.originalX + frameDef.src.width,
            frameDef.originalY + frameDef.src.height,
          );
          final runtimeRightBottom = Offset(destX + destW, destY + destH);

          final sourceOK =
              frameDef.src.left >= 0 &&
              frameDef.src.top >= 0 &&
              frameDef.src.right <= bundle.image.width &&
              frameDef.src.bottom <= bundle.image.height;
          final logicalOK =
              frameDef.originalX >= 0 &&
              frameDef.originalY >= 0 &&
              logicalRightBottom.dx <= 768 &&
              logicalRightBottom.dy <= 448;

          if (false)
            print(
              '[PlayerAtlasCropDebug] DETAILED listIndex=$listIndex frameIndex=${frameDef.frameIndex}\n'
              '  src: LTWH=(${frameDef.src.left.toInt()},${frameDef.src.top.toInt()},${frameDef.src.width.toInt()}x${frameDef.src.height.toInt()}) '
              'LTRB=(${srcLeftTop.dx.toInt()},${srcLeftTop.dy.toInt()},${srcRightBottom.dx.toInt()},${srcRightBottom.dy.toInt()})\n'
              '  logical: orig=(${frameDef.originalX.toInt()},${frameDef.originalY.toInt()}) '
              'LTRB=(${frameDef.originalX.toInt()},${frameDef.originalY.toInt()},${logicalRightBottom.dx.toInt()},${logicalRightBottom.dy.toInt()})\n'
              '  runtime: dst=(${destX.toInt()},${destY.toInt()},${destW.toInt()}x${destH.toInt()}) '
              'LTRB=(${destX.toInt()},${destY.toInt()},${runtimeRightBottom.dx.toInt()},${runtimeRightBottom.dy.toInt()})\n'
              '  baseline: value=${_bundleBaselines[currentState]?.toStringAsFixed(1) ?? "?"} corrY=${(_bundleBaselines[currentState] != null ? ((_AtlasAnimationBundle.logicalFrameHeight - _bundleBaselines[currentState]!) * _atlasScale).toStringAsFixed(2) : "?")}\n'
              '  sourceOK=$sourceOK logicalOK=$logicalOK scale=${_atlasScale.toStringAsFixed(2)}',
            );
        }
      }
    }

    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..isAntiAlias = false;

    if (flipScaleX < 0 && !PlayerComponent.debugForceFacingRight) {
      // ── Facing left: flip horizontally around the component center ────────
      // Use defensive try-finally to ensure canvas.restore() is always called
      if (shouldLog) {
        if (false) print('[RenderTrace] before canvas.save()');
        if (false)
          RenderTrace.logCanvas(
            file: 'lib/player/player_component.dart',
            method: '_PlayerAnimationRenderer.render',
            operation: 'save',
          );
      }
      _canvasSaveCalled = true;
      canvas.save();
      try {
        if (shouldLog) {
          if (false)
            print('[RenderTrace] before canvas.translate(centerX, centerY)');
          if (false)
            RenderTrace.logCanvas(
              file: 'lib/player/player_component.dart',
              method: '_PlayerAnimationRenderer.render',
              operation: 'translate',
            );
        }
        canvas.translate(centerX, centerY);

        if (shouldLog) {
          if (false) print('[RenderTrace] before canvas.scale(-1.0, 1.0)');
          if (false)
            RenderTrace.logCanvas(
              file: 'lib/player/player_component.dart',
              method: '_PlayerAnimationRenderer.render',
              operation: 'scale',
            );
        }
        canvas.scale(-1.0, 1.0);

        if (shouldLog) {
          if (false)
            print('[RenderTrace] before canvas.translate(-centerX, -centerY)');
          if (false)
            RenderTrace.logCanvas(
              file: 'lib/player/player_component.dart',
              method: '_PlayerAnimationRenderer.render',
              operation: 'translate',
            );
        }
        canvas.translate(-centerX, -centerY);

        if (shouldLog) {
          final imageName = bundle.imagePath.split('/').last;
          if (false)
            print(
              '[RenderTrace] drawImageRect BEFORE image=$imageName '
              'sourceLTRB=${sourceRect.left.toStringAsFixed(1)},${sourceRect.top.toStringAsFixed(1)},${sourceRect.right.toStringAsFixed(1)},${sourceRect.bottom.toStringAsFixed(1)} '
              'destLTRB=${destRect.left.toStringAsFixed(1)},${destRect.top.toStringAsFixed(1)},${destRect.right.toStringAsFixed(1)},${destRect.bottom.toStringAsFixed(1)} '
              'sourceWH=${sourceRect.width.toStringAsFixed(1)}x${sourceRect.height.toStringAsFixed(1)} '
              'destWH=${destRect.width.toStringAsFixed(1)}x${destRect.height.toStringAsFixed(1)}',
            );
          if (false)
            print('[RenderTrace] before drawImageRect (flipped branch)');
        }
        canvas.drawImageRect(bundle.image, sourceRect, destRect, paint);
        if (shouldLog)
          if (false)
            print('[RenderTrace] after drawImageRect (flipped branch)');
      } finally {
        if (shouldLog) {
          if (false) print('[RenderTrace] before canvas.restore()');
          if (false)
            RenderTrace.logCanvas(
              file: 'lib/player/player_component.dart',
              method: '_PlayerAnimationRenderer.render',
              operation: 'restore',
            );
        }
        _canvasRestoreCalled = true;
        canvas.restore();
        if (shouldLog) if (false) print('[RenderTrace] after canvas.restore()');
      }
    } else {
      // ── Facing right: draw directly, no transform needed ─────────────────
      if (shouldLog) {
        final imageName = bundle.imagePath.split('/').last;
        if (false)
          print(
            '[RenderTrace] drawImageRect BEFORE image=$imageName '
            'sourceLTRB=${sourceRect.left.toStringAsFixed(1)},${sourceRect.top.toStringAsFixed(1)},${sourceRect.right.toStringAsFixed(1)},${sourceRect.bottom.toStringAsFixed(1)} '
            'destLTRB=${destRect.left.toStringAsFixed(1)},${destRect.top.toStringAsFixed(1)},${destRect.right.toStringAsFixed(1)},${destRect.bottom.toStringAsFixed(1)} '
            'sourceWH=${sourceRect.width.toStringAsFixed(1)}x${sourceRect.height.toStringAsFixed(1)} '
            'destWH=${destRect.width.toStringAsFixed(1)}x${destRect.height.toStringAsFixed(1)}',
          );
        if (false) print('[RenderTrace] before drawImageRect (normal branch)');
      }
      canvas.drawImageRect(bundle.image, sourceRect, destRect, paint);
      if (shouldLog)
        if (false) print('[RenderTrace] after drawImageRect (normal branch)');
    }

    if (shouldLog) {
      if (false) print('[RenderTrace] canvasSaveCalled=$_canvasSaveCalled');
      if (false)
        print('[RenderTrace] canvasRestoreCalled=$_canvasRestoreCalled');
    }

    if (PlayerComponent.debugDrawPlayerRenderBounds) {
      _drawPlayerRenderBounds(canvas, destRect, baselineCorrY);
    }

    // ── DEBUG OVERLAY: show crop bounds/info on screen ─────────────────────
    _renderDebugOverlay(
      canvas,
      bundle,
      frameDef,
      sourceRect,
      destRect,
      listIndex,
    );

    if (PlayerComponent.debugTraceRenderSequence && shouldLog) {
      if (false) RenderTrace.log('_PlayerAnimationRenderer.render END');
    }
  }

  void _drawPlayerRenderBounds(
    Canvas canvas,
    Rect destRect,
    double baselineCorrY,
  ) {
    final containerPaint = Paint()
      ..color = const Color(0xFFFFFF00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final destPaint = Paint()
      ..color = const Color(0xFF00FF00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final hitboxPaint = Paint()
      ..color = const Color(0xFFFF0000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final baselinePaint = Paint()
      ..color = const Color(0xFF0099FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final containerRect = Rect.fromLTWH(0, 0, visualSize.x, visualSize.y);
    final hitboxRect = Rect.fromCenter(
      center: Offset(visualSize.x / 2, visualSize.y - 32),
      width: 32,
      height: 64,
    );
    final baselineY = hitboxRect.bottom;

    canvas.drawRect(containerRect, containerPaint);
    canvas.drawRect(destRect, destPaint);
    canvas.drawRect(hitboxRect, hitboxPaint);
    canvas.drawLine(
      Offset(0, baselineY),
      Offset(visualSize.x, baselineY),
      baselinePaint,
    );

    if (!PlayerComponent.debugIdleTwoFramesOnly) {
      if (false)
        print(
          '[RenderTrace] debugBounds container=$containerRect destRect=$destRect '
          'hitbox=$hitboxRect baselineY=${baselineY.toStringAsFixed(2)} '
          'baselineCorrectionY=${baselineCorrY.toStringAsFixed(2)}',
        );
    }
  }

  void _renderDebugOverlay(
    Canvas canvas,
    _AtlasAnimationBundle bundle,
    _AtlasFrameDef frameDef,
    Rect sourceRect,
    Rect destRect,
    int listIndex,
  ) {
    if (_debugOverlayMode == 0) return; // debug off

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Helper function to check bounds
    bool checkSourceBounds() {
      return frameDef.src.left >= 0 &&
          frameDef.src.top >= 0 &&
          frameDef.src.right <= bundle.image.width &&
          frameDef.src.bottom <= bundle.image.height;
    }

    bool checkLogicalBounds() {
      return frameDef.originalX >= 0 &&
          frameDef.originalY >= 0 &&
          (frameDef.originalX + frameDef.src.width) <= 768 &&
          (frameDef.originalY + frameDef.src.height) <= 448;
    }

    switch (_debugOverlayMode) {
      case 1:
        // Show source rect outline (RED) and dest rect outline (GREEN)
        paint.color = const Color(0xFFFF0000);
        canvas.drawRect(sourceRect, paint);

        paint.color = const Color(0xFF00FF00);
        canvas.drawRect(destRect, paint);

        // Draw circle at dest origin (BLUE)
        paint.color = const Color(0xFF0000FF);
        canvas.drawCircle(
          Offset(destRect.left, destRect.top),
          4,
          paint..style = PaintingStyle.fill,
        );
        break;

      case 2:
        // Show bounds checks with color coding
        paint.style = PaintingStyle.stroke;
        paint.strokeWidth = 2.0;

        paint.color = checkSourceBounds()
            ? const Color(0xFF00AA00)
            : const Color(0xFFFF0000);
        canvas.drawRect(sourceRect, paint);

        paint.color = checkLogicalBounds()
            ? const Color(0xFF00AA00)
            : const Color(0xFFFF0000);
        canvas.drawRect(destRect, paint);
        break;

      case 3:
        // Full bounds outline (yellow)
        paint.color = const Color(0xFFFFFF00);
        paint.strokeWidth = 3.0;
        canvas.drawRect(destRect, paint);
        break;
    }
  }

  void _logFrameDebug() {
    final bundle = bundles[currentState];
    if (bundle == null || bundle.frames.isEmpty) return;

    // currentFrameIndex is a LIST INDEX into sorted frames array
    final listIndex = currentFrameIndex.clamp(0, bundle.frames.length - 1);
    final frameDef = bundle.frames[listIndex];

    if (false)
      print(
        '[PlayerAtlas] STATUS anim=${currentState.name} '
        'listIndex=$listIndex/${bundle.frames.length - 1} '
        'frameIndex=${frameDef.frameIndex} '
        'src=(${frameDef.src.left.toInt()},${frameDef.src.top.toInt()}, '
        '${frameDef.src.width.toInt()}x${frameDef.src.height.toInt()}) '
        'orig=(${frameDef.originalX.toInt()},${frameDef.originalY.toInt()}) '
        'row=${frameDef.row} col=${frameDef.col} '
        'scale=${_atlasScale.toStringAsFixed(2)} '
        'visualSize=${visualSize.x.toInt()}x${visualSize.y.toInt()}',
      );
  }
}

class PlayerComponent extends PositionComponent {
  // ── CLEANUP: ONLY Player animations loaded ──
  // Enemies rendering completely disabled (enableEnemies = false in GameWorld)

  static const String _playerAtlasAssetsRoot = 'assets/sprites/player';

  static const bool _debugRunAtlas = false;

  /// Temporary isolation mode: render only idle frames via manual controls.
  static const bool debugIdleTwoFramesOnly = false;

  /// Renders full 768x448 cell by row/col instead of bbox crop for debugging.
  static const bool debugRenderFullGridCell = true;

  /// Enables manual frame stepping keys (1..0,-,=,Backspace,[,],Space).
  static const bool debugManualFrameMode = false;
  static const bool debugManualRunAutoGunFrames = false;

  /// CLEANUP: Set false to hide weapon entirely during Player animation testing.
  static const bool enableWeaponSystem = true;

  /// Debug: force player to always face right (disable horizontal flip)
  static const bool debugForceFacingRight = false;

  static const double playerLogicalFrameWidth = 768.0;
  static const double playerLogicalFrameHeight = 448.0;
  static const double playerDesiredVisualHeight = 84.0;
  // Smaller stepTime => faster frame cycling for run animation.
  static const double runAnimationStepTime = 0.045;

  /// Extra offset for bottom-aligned drawing inside 168x98 visual container.
  static const double visualGroundOffsetY = 0.0;

  static const double idleVisualMultiplier = 1.0;
  static const double? runVisualMultiplierOverride = null;
  static const double? jumpVisualMultiplierOverride = 1.35;
  static const double deathVisualMultiplier = 1.65;
  static const double deathVisualGroundOffsetY = 0.0;

  // Sniper-only visual calibration (render only, no physics changes)
  static const double sniperRenderScale = 1.08;
  static const double sniperRunRenderScale = 0.95;
  static const double sniperRenderOffsetXLogical = -5.0;
  static const double sniperRenderOffsetYLogical = 0.0;

  /// Logs physical-vs-visual grounding diagnostics.
  static const bool debugGroundAlignmentLogs = false;

  ///Debug: hide all level geometry to test if it's occluding player
  static const bool debugHideLevelGeometry = false;

  /// Debug: render player above all other world elements for testing
  static const bool debugRenderPlayerOnTop = true;

  /// Debug: draw container/destRect/hitbox/baseline for visual render diagnostics.
  static const bool debugDrawPlayerRenderBounds = false;

  /// Debug: print runtime render sequence to identify overdraw order bugs.
  static const bool debugTraceRenderSequence = false;

  static const bool debugPlayerRenderLogs = false;
  static const bool debugAnimationLogs = false;
  static const bool debugRenderOrderLogs = false;
  static const bool debugWeaponSwitchLogs = true;

  static const Map<WeaponType, Offset> _manualWeaponRenderOffsetsLogical = {
    WeaponType.autoGun: Offset.zero,
    WeaponType.sniperGun: Offset(
      sniperRenderOffsetXLogical,
      sniperRenderOffsetYLogical,
    ),
  };

  /// Debug: visual overlay for collision debugging (hitbox + bottom line).
  static const bool debugDrawCollision =
      DebugCollisionConfig.showCollisionBoxes &&
      DebugCollisionConfig.showPlayerHitbox;

  /// Debug force-anim keys (no conflicts with PlayerController):
  ///   I = force idle   R = force run   J = force jump
  ///   K = force death  (D is NOT used — D moves player right in PlayerController)
  ///   P = pause/resume animation  (Space is NOT used — Space jumps)
  ///   [ / ] = prev / next frame   Esc / C = clear forced state
  static const bool enableForceAnimKeys = kDebugMode;
  static const bool enableDeathDebugHotkey = kDebugMode;
  static const bool enableWeaponDebugHotkeys = kDebugMode;

  // Hysteresis thresholds to prevent idle/run flicker.
  // velocity.x is set directly (no decay), so these just guard against
  // edge-case near-zero values.
  static const double _enterRunVelocityThreshold = 5.0;
  static const double _exitRunVelocityThreshold = 1.0;

  Vector2 velocity = Vector2.zero();
  double maxHealth = GameConfig.playerMaxHealth;
  double health = GameConfig.playerMaxHealth;
  double _invulnerabilityTimer = 0.0;
  bool isOnGround = false;
  bool canDash = true;
  bool _isSprintHeld = false;
  int facingDirection = 1;
  int _jumpsUsed = 0;
  PlayerAnimState _animState = PlayerAnimState.idle;
  double _dashAnimTimer = 0.0;
  double _dashTrailCooldown = 0.0;
  double _animTime = 0.0;
  PlayerLifeState _lifeState = PlayerLifeState.alive;

  /// True while moveLeft/moveRight is being called this frame (cleared by stopHorizontal).
  /// Used in run/idle hysteresis to avoid flickering when velocity is near zero.
  bool _isMovementInputActive = false;
  bool _facingRight = true;
  bool _deathDebugKeyPrev = false;
  WeaponType currentWeapon = WeaponType.autoGun;
  final Map<String, _AtlasAnimationBundle?> _animationBundleCache = {};
  final Set<int> _prevWeaponHotkeyIds = {};
  int _weaponSwitchVersion = 0;
  double? _referenceIdleMaxBboxHeight;
  double? _referenceBodyCenterX;
  Rect? _previousWorldRect;

  Rect get worldHitboxRect {
    final p = absolutePosition;
    final hitboxWidth = size.x;
    final hitboxHeight = size.y;
    final centerX = p.x + (0.5 - anchor.x) * size.x;
    final feetY = p.y + (1 - anchor.y) * size.y;
    return Rect.fromLTWH(
      centerX - hitboxWidth / 2,
      feetY - hitboxHeight,
      hitboxWidth,
      hitboxHeight,
    );
  }

  Rect get previousWorldRect => _previousWorldRect ?? toRect();

  Rect get _localHitboxRect {
    final hitboxWidth = size.x;
    final hitboxHeight = size.y;
    return Rect.fromLTWH(
      size.x / 2 - hitboxWidth / 2,
      size.y - hitboxHeight,
      hitboxWidth,
      hitboxHeight,
    );
  }

  _PlayerAnimationRenderer? _animationRenderer;
  PlayerAnimState? _forcedAnimState; // when set, overrides resolved anim state
  bool _animForcePaused = false;
  final Set<int> _prevPressedKeyIds = {}; // for edge detection on force keys
  late PlayerController _controller;
  late WeaponManager weaponManager;

  final Map<PlayerAnimState, _DebugAnimMeta> _debugAnimMeta = {};
  PlayerAnimState _debugCurrentVisualState = PlayerAnimState.idle;
  int _debugRenderFrameMarker = 0;
  // _debugAnimElapsed and _debugAnimLogCooldown removed - logging moved to renderer

  PlayerLifeState get lifeState => _lifeState;
  bool get isAlive => _lifeState == PlayerLifeState.alive;
  bool get isDying => _lifeState == PlayerLifeState.dying;
  bool get isDead => _lifeState == PlayerLifeState.dead;
  PlayerAnimState get currentAnimState => _animState;
  int get debugRenderFrameMarker => _debugRenderFrameMarker;

  @override
  Future<void> onLoad() async {
    size = Vector2(32, 64);
    anchor = Anchor.center;
    _controller = PlayerController(this);
    // Always init weaponManager so external references don't break,
    // but only add as child (and load loadout) when enableWeaponSystem=true.
    weaponManager = WeaponManager(this);
    if (enableWeaponSystem) {
      add(weaponManager);
      _initDefaultLoadout();
    }
    await _tryInitSpriteVisual();
  }

  void _initDefaultLoadout() {
    weaponManager.setLoadout([PulseBlaster(), BeamCutter()], initialIndex: 0);
  }

  @override
  void update(double dt) {
    // Keep last frame world rect for swept collision (important on lag spikes).
    _previousWorldRect = toRect();
    _debugRenderFrameMarker++;
    super.update(dt);
    _animTime += dt;
    if (_dashAnimTimer > 0) _dashAnimTimer -= dt;
    if (_dashTrailCooldown > 0) _dashTrailCooldown -= dt;
    if (_invulnerabilityTimer > 0) _invulnerabilityTimer -= dt;

    final game = findGame();
    final isGameplayBlocked =
        game is VoidRelayGame && game.isGameplayInputBlocked;

    if (!isAlive || isGameplayBlocked) {
      velocity.setZero();
    } else if (debugIdleTwoFramesOnly) {
      // Keep player pinned on ground for visual-frame isolation test.
      velocity.y = 0;
      isOnGround = true;
      position.x += velocity.x * dt;
    } else {
      velocity.y += GameConfig.gravity * dt;
      if (velocity.y > GameConfig.maxFallSpeed) {
        velocity.y = GameConfig.maxFallSpeed;
      }

      _controller.update(dt);
      position += velocity * dt;
    }

    // Keep last direction while idle; update only on meaningful horizontal movement.
    if (velocity.x > 1.0) {
      _setFacingRight(true);
    } else if (velocity.x < -1.0) {
      _setFacingRight(false);
    }

    _updateAnimationState();
    _syncSpriteVisual();
    _logGroundDebug();

    if (_dashAnimTimer > 0 && _dashTrailCooldown <= 0) {
      final game = findGame();
      if (game is VoidRelayGame) {
        game.spawnDashTrail(absolutePosition, direction: facingDirection);
      }
      _dashTrailCooldown = 0.03;
    }
  }

  void _checkDeathDebugHotkey() {
    if (!enableDeathDebugHotkey) return;
    final pressed = HardwareKeyboard.instance.isLogicalKeyPressed(
      LogicalKeyboardKey.keyK,
    );
    if (pressed && !_deathDebugKeyPrev) {
      _forcedAnimState = PlayerAnimState.death;
      _animForcePaused = false;
      _animationRenderer?.setPaused(false);
      _animationRenderer?.setAnimationState(PlayerAnimState.death);
      if (false) print('[PlayerDeath] STATE_SWITCH -> death (debug key K)');
    }
    _deathDebugKeyPrev = pressed;
  }

  void _checkWeaponHotkeys() {
    if (!enableWeaponDebugHotkeys || debugManualFrameMode) return;

    final pressed = HardwareKeyboard.instance.logicalKeysPressed
        .map((k) => k.keyId)
        .toSet();
    bool justPressed(LogicalKeyboardKey key) =>
        pressed.contains(key.keyId) &&
        !_prevWeaponHotkeyIds.contains(key.keyId);

    if (justPressed(LogicalKeyboardKey.digit1)) {
      setWeapon(WeaponType.autoGun);
    }
    if (justPressed(LogicalKeyboardKey.digit2)) {
      setWeapon(WeaponType.sniperGun);
    }

    _prevWeaponHotkeyIds
      ..clear()
      ..addAll(pressed);
  }

  void setWeapon(WeaponType weapon) {
    if (weapon == currentWeapon) {
      if (false) print('[PlayerWeapon] unchanged weapon=${weapon.name}');
      return;
    }

    final previous = currentWeapon;
    final visualState = _resolveVisualAnimState();
    currentWeapon = weapon;
    final version = ++_weaponSwitchVersion;

    if (false)
      print(
        '[PlayerWeapon] changed ${previous.name} -> ${weapon.name} '
        'state=${visualState.name}',
      );

    if (enableWeaponSystem) {
      final slot = weapon == WeaponType.autoGun ? 0 : 1;
      weaponManager.switchToWeaponSlot(slot);
    }

    // ignore: discarded_futures
    _refreshWeaponVisuals(version: version, visualState: visualState);
  }

  void switchToNextWeapon() {
    if (!enableWeaponSystem) return;
    final next = currentWeapon == WeaponType.autoGun
        ? WeaponType.sniperGun
        : WeaponType.autoGun;
    setWeapon(next);
  }

  void switchToPreviousWeapon() {
    if (!enableWeaponSystem) return;
    final previous = currentWeapon == WeaponType.autoGun
        ? WeaponType.sniperGun
        : WeaponType.autoGun;
    setWeapon(previous);
  }

  void switchToWeaponSlot(int slot) {
    if (!enableWeaponSystem) return;
    if (slot == 0) {
      setWeapon(WeaponType.autoGun);
      return;
    }
    if (slot == 1) {
      setWeapon(WeaponType.sniperGun);
      return;
    }
    weaponManager.switchToWeaponSlot(slot);
  }

  @override
  void render(Canvas canvas) {
    if (debugTraceRenderSequence) {
      if (false)
        RenderTrace.log(
          'PlayerComponent.render START priority=$priority '
          'rendererLoaded=${_animationRenderer != null} children=${children.length}',
        );
    }

    // NOTE: children are rendered by Flame's renderTree flow.
    // super.render(canvas) itself does not render children.
    super.render(canvas);

    // Only draw placeholder if atlas renderer failed to load
    if (_animationRenderer == null) {
      if (!debugIdleTwoFramesOnly && debugPlayerRenderLogs) {
        if (false)
          print(
            '[RenderTrace] PlayerComponent fallback placeholder render ACTIVE',
          );
      }
      final paint = Paint()..color = _resolvePlaceholderColor();
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
    } else {
      if (!debugIdleTwoFramesOnly && debugPlayerRenderLogs) {
        if (false)
          print(
            '[RenderTrace] PlayerComponent fallback placeholder render SKIPPED',
          );
      }
    }

    if (debugDrawCollision) {
      final hitboxPaint = Paint()
        ..color = const Color(0xFFFF0000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final bottomLinePaint = Paint()
        ..color = const Color(0xFFFFFF00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final hitboxRect = _localHitboxRect;
      final bottomY = hitboxRect.bottom;
      canvas.drawRect(hitboxRect, hitboxPaint);
      canvas.drawLine(
        Offset(hitboxRect.left, bottomY),
        Offset(hitboxRect.right, bottomY),
        bottomLinePaint,
      );
    }

    // Weapon temporarily disabled during Player animation testing
    // _renderWeapon(canvas);

    if (debugTraceRenderSequence) {
      if (false) RenderTrace.log('PlayerComponent.render END');
    }
  }

  // ── Movement ─────────────────────────────────────────────────────────────

  void moveLeft(double dt) {
    velocity.x = -_horizontalSpeed;
    facingDirection = -1;
    _setFacingRight(false);
    _isMovementInputActive = true;
  }

  void moveRight(double dt) {
    velocity.x = _horizontalSpeed;
    facingDirection = 1;
    _setFacingRight(true);
    _isMovementInputActive = true;
  }

  void _setFacingRight(bool value) {
    if (_facingRight == value) return;
    _facingRight = value;
    if (debugPlayerRenderLogs) {
      if (false)
        print(
          '[PlayerFacing] direction changed: ${_facingRight ? 'right' : 'left'}',
        );
    }
  }

  void restoreFacingDirection(int direction) {
    facingDirection = direction >= 0 ? 1 : -1;
    _setFacingRight(facingDirection > 0);
  }

  double get _horizontalSpeed =>
      GameConfig.playerSpeed *
      (_isSprintHeld ? GameConfig.playerSprintMultiplier : 1.0);

  void setSprintHeld(bool held) {
    _isSprintHeld = held;
  }

  void stopHorizontal() {
    velocity.x = 0;
    _isMovementInputActive = false;
  }

  void jump() {
    if (GameConfig.playerMaxJumps <= 0) return;

    // Jump #1 from ground + one extra jump in air for MVP mobility.
    if (isOnGround) {
      velocity.y = GameConfig.playerJumpForce;
      isOnGround = false;
      _jumpsUsed = 1;
      return;
    }

    if (!_canUseAirJump) return;

    velocity.y = GameConfig.playerJumpForce;
    _jumpsUsed += 1;
  }

  bool get _canUseAirJump => _jumpsUsed < GameConfig.playerMaxJumps;

  void dash() {
    if (canDash) {
      velocity.x += GameConfig.playerDashForce * (velocity.x >= 0 ? 1 : -1);
      canDash = false;
      _dashAnimTimer = 0.12;
      _setAnimationState(PlayerAnimState.dash);
    }
  }

  void land() {
    isOnGround = true;
    canDash = true;
    _jumpsUsed = 0;
  }

  // ── Health ────────────────────────────────────────────────────────────────

  bool get isInvulnerable => _invulnerabilityTimer > 0;

  double heal(double amount) {
    if (amount <= 0 || !isAlive) return 0;
    final previous = health;
    health = (health + amount).clamp(0.0, maxHealth).toDouble();
    return health - previous;
  }

  void takeDamage(double amount) {
    if (GameConfig.playerGodMode) return;
    if (!isAlive || isInvulnerable) return;
    health -= amount;
    if (health <= 0) {
      health = 0;
      beginDying();
      final game = findGame();
      if (game is VoidRelayGame) {
        game.beginPlayerDeathSequence();
      }
      return;
    }

    _invulnerabilityTimer = GameConfig.invulnerabilityDuration;

    final game = findGame();
    if (game is VoidRelayGame) {
      game.playSfx(SoundAssets.hit);
      game.spawnHitSpark(absolutePosition);
    }
  }

  // ── Animation ─────────────────────────────────────────────────────────────

  void _updateAnimationState() {
    if (debugIdleTwoFramesOnly) {
      _animState = PlayerAnimState.idle;
      return;
    }
    final previous = _animState;

    if (!isAlive) {
      _animState = PlayerAnimState.death;
    } else if (!isOnGround) {
      _animState = PlayerAnimState.jump;
    } else {
      final absVelX = velocity.x.abs();
      final currentlyRunning = _animState == PlayerAnimState.run;
      final isMovingHorizontally =
          _isMovementInputActive ||
          (currentlyRunning
              ? absVelX > _exitRunVelocityThreshold
              : absVelX > _enterRunVelocityThreshold);
      _animState = isMovingHorizontally
          ? PlayerAnimState.run
          : PlayerAnimState.idle;
    }

    if (_animState != previous && debugAnimationLogs) {
      if (false)
        print(
          '[PlayerAnim] STATE_SWITCH ${previous.name} -> ${_animState.name}',
        );
    }
  }

  /// Direct override used by dash/death — bypasses hysteresis.
  void _setAnimationState(PlayerAnimState state) {
    if (debugIdleTwoFramesOnly) {
      _animState = PlayerAnimState.idle;
      return;
    }
    _animState = state;
  }

  PlayerAnimState _resolveVisualAnimState() {
    if (debugIdleTwoFramesOnly) return PlayerAnimState.idle;
    if (_forcedAnimState == PlayerAnimState.death) return PlayerAnimState.death;
    if (debugManualFrameMode && _forcedAnimState != null) {
      return _forcedAnimState!;
    }
    if (_animState == PlayerAnimState.death) return PlayerAnimState.death;
    if (_animState == PlayerAnimState.jump) return PlayerAnimState.jump;
    if (_animState == PlayerAnimState.run) return PlayerAnimState.run;
    return PlayerAnimState.idle;
  }

  void _checkForceAnimKeys() {
    if (!enableForceAnimKeys || !debugManualFrameMode) return;
    final pressed = HardwareKeyboard.instance.logicalKeysPressed
        .map((k) => k.keyId)
        .toSet();

    bool justPressed(LogicalKeyboardKey key) =>
        pressed.contains(key.keyId) && !_prevPressedKeyIds.contains(key.keyId);

    bool handledFrameHotkey = false;
    void setFrameByKey(LogicalKeyboardKey key, int frameIndex, String label) {
      if (!justPressed(key)) return;
      handledFrameHotkey = true;
      _forcedAnimState = PlayerAnimState.idle;
      _animForcePaused = true;
      _animationRenderer?.setPaused(true);
      _animationRenderer?.setAnimationState(PlayerAnimState.idle);
      _animationRenderer?.jumpToFrameIndexValue(frameIndex);
      if (false) print('[IdleDebug] key=$label -> frameIndex=$frameIndex');
    }

    // Keep manual frame stepping available during full-grid validation.
    if (debugRenderFullGridCell) {
      setFrameByKey(LogicalKeyboardKey.digit1, 0, '1');
      setFrameByKey(LogicalKeyboardKey.digit2, 1, '2');
      setFrameByKey(LogicalKeyboardKey.digit3, 2, '3');
      setFrameByKey(LogicalKeyboardKey.digit4, 3, '4');
      setFrameByKey(LogicalKeyboardKey.digit5, 4, '5');
      setFrameByKey(LogicalKeyboardKey.digit6, 5, '6');
      setFrameByKey(LogicalKeyboardKey.digit7, 6, '7');
      setFrameByKey(LogicalKeyboardKey.digit8, 7, '8');
      setFrameByKey(LogicalKeyboardKey.digit9, 8, '9');
      setFrameByKey(LogicalKeyboardKey.digit0, 9, '0');
      setFrameByKey(LogicalKeyboardKey.minus, 10, '-');
      setFrameByKey(LogicalKeyboardKey.equal, 11, '=');
      setFrameByKey(LogicalKeyboardKey.backspace, 12, 'Backspace');

      if (justPressed(LogicalKeyboardKey.space)) {
        _animForcePaused = !_animForcePaused;
        _animationRenderer?.setPaused(_animForcePaused);
        if (false) print('[IdleDebug] key=Space -> paused=$_animForcePaused');
      }
      if (justPressed(LogicalKeyboardKey.bracketLeft)) {
        _animationRenderer?.previousFrame();
        if (false) print('[IdleDebug] key=[ -> prev frame');
      }
      if (justPressed(LogicalKeyboardKey.bracketRight)) {
        _animationRenderer?.nextFrame();
        if (false) print('[IdleDebug] key=] -> next frame');
      }
    }

    if (debugIdleTwoFramesOnly) {
      _forcedAnimState = PlayerAnimState.idle;

      _prevPressedKeyIds
        ..clear()
        ..addAll(pressed);
      return;
    }

    // ── Force animation state (visual only, physics unchanged) ───────────────
    // KEY MAPPING (no conflicts with PlayerController):
    //   I = idle      PlayerController does NOT use I
    //   R = run       PlayerController does NOT use R
    //   J = jump      PlayerController does NOT use J
    //   K = death     NOT D — D is moveRight in PlayerController!
    //   P = pause     NOT Space — Space is jump in PlayerController!
    //   [ / ] = prev / next frame
    //   Esc / C = clear forced state
    if (justPressed(LogicalKeyboardKey.keyI)) {
      _forcedAnimState = PlayerAnimState.idle;
      if (false) print('[PlayerAtlas] FORCE: idle (I)');
    }
    if (justPressed(LogicalKeyboardKey.keyR)) {
      _forcedAnimState = PlayerAnimState.run;
      if (false) print('[PlayerAtlas] FORCE: run (R)');
    }
    if (justPressed(LogicalKeyboardKey.keyJ)) {
      _forcedAnimState = PlayerAnimState.jump;
      if (false) print('[PlayerAtlas] FORCE: jump (J)');
    }
    // K = force death  (was D — D conflicts with moveRight!)
    if (justPressed(LogicalKeyboardKey.keyK)) {
      _forcedAnimState = PlayerAnimState.death;
      if (false)
        print(
          '[PlayerAtlas] FORCE: death (K) — note: D was remapped, D=moveRight',
        );
    }
    // Clear forced state
    if (justPressed(LogicalKeyboardKey.escape) ||
        justPressed(LogicalKeyboardKey.keyC)) {
      _forcedAnimState = null;
      if (false) print('[PlayerAtlas] FORCE: cleared → auto-state');
    }
    // P = pause/resume animation  (was Space — Space conflicts with jump!)
    if (justPressed(LogicalKeyboardKey.keyP)) {
      _animForcePaused = !_animForcePaused;
      _animationRenderer?.setPaused(_animForcePaused);
      if (false) print('[PlayerAtlas] FORCE: paused=$_animForcePaused (P)');
    }
    // Frame stepping: [ = previous, ] = next
    if (justPressed(LogicalKeyboardKey.bracketLeft)) {
      _animationRenderer?.previousFrame();
      if (false) print('[PlayerAtlas] FORCE: prevFrame ([)');
    }
    if (justPressed(LogicalKeyboardKey.bracketRight)) {
      _animationRenderer?.nextFrame();
      if (false) print('[PlayerAtlas] FORCE: nextFrame (])');
    }

    // ── DEBUG: Animation speed control ────────────────────────────────────
    // Minus (-) = slower (increase stepTime)
    // Plus (+) = faster (decrease stepTime)
    if (!handledFrameHotkey && justPressed(LogicalKeyboardKey.minus)) {
      _animationRenderer?._debugTimingMultiplier *= 0.8;
      final mult = _animationRenderer?._debugTimingMultiplier ?? 1.0;
      if (false)
        print(
          '[PlayerAtlas] TIMING: slower (multiplier=${mult.toStringAsFixed(2)})',
        );
    }
    if (!handledFrameHotkey && justPressed(LogicalKeyboardKey.equal)) {
      // "equal" key is "+/=" in US keyboard layout
      _animationRenderer?._debugTimingMultiplier *= 1.25;
      final mult = _animationRenderer?._debugTimingMultiplier ?? 1.0;
      if (false)
        print(
          '[PlayerAtlas] TIMING: faster (multiplier=${mult.toStringAsFixed(2)})',
        );
    }
    // Home = reset to 1.0x
    if (justPressed(LogicalKeyboardKey.home)) {
      _animationRenderer?._debugTimingMultiplier = 1.0;
      if (false) print('[PlayerAtlas] TIMING: reset to 1.0x');
    }

    // ── DEBUG: Crop/render overlay toggle (F1-F4) ────────────────────────────
    // F1 = off, F2 = frame info, F3 = bounds check, F4 = full atlas overlay
    if (justPressed(LogicalKeyboardKey.f1)) {
      _animationRenderer?._debugOverlayMode = 0;
      if (false) print('[PlayerAtlas] DEBUG: overlay off');
    }
    if (justPressed(LogicalKeyboardKey.f2)) {
      _animationRenderer?._debugOverlayMode = 1;
      if (false) print('[PlayerAtlas] DEBUG: showing frame info');
    }
    if (justPressed(LogicalKeyboardKey.f3)) {
      _animationRenderer?._debugOverlayMode = 2;
      if (false) print('[PlayerAtlas] DEBUG: showing bounds checks');
    }
    if (justPressed(LogicalKeyboardKey.f4)) {
      _animationRenderer?._debugOverlayMode = 3;
      if (false)
        print('[PlayerAtlas] DEBUG: showing full atlas with sourceRect');
    }

    _prevPressedKeyIds
      ..clear()
      ..addAll(pressed);
  }

  void _syncSpriteVisual() {
    final renderer = _animationRenderer;
    if (renderer == null) return;

    final resolved = _resolveVisualAnimState();
    if (_debugCurrentVisualState != resolved) {
      _debugCurrentVisualState = resolved;
    }

    // Tell renderer to switch to new animation state
    renderer.setAnimationState(resolved);

    // Apply facing direction to renderer
    renderer.setFacingRight(debugForceFacingRight ? true : _facingRight);

    _debugLogVisualPlayback();
  }

  void _debugLogVisualPlayback() {
    // Note: frame-level logging is now done in _PlayerAnimationRenderer.update()
    // via FRAME_ADVANCE logs. This method is kept for potential future use.
  }

  void _logGroundDebug() {
    if (!debugGroundAlignmentLogs) return;
    final game = findGame();
    if (game is! VoidRelayGame) return;
    final world = game.gameWorld;
    if (world == null) return;

    final playerBottom = position.y + size.y / 2;
    double? platformTop;
    var bestDistance = double.infinity;
    for (final platform in world.platforms) {
      final rect = platform.toRect();
      if (rect.width <= rect.height) continue;
      if (position.x < rect.left || position.x > rect.right) continue;
      final distance = (rect.top - playerBottom).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        platformTop = rect.top;
      }
    }

    final visualDest = _animationRenderer?.lastVisualDestRect;
    final visualFeetBottom = _animationRenderer?.lastVisibleFeetBottomOnScreen;
    final animName = _resolveVisualAnimState().name;
    if (false) print('[GroundDebug] playerPos=$position');
    if (false) print('[GroundDebug] playerSize=$size');
    if (false)
      print('[GroundDebug] playerBottom=${playerBottom.toStringAsFixed(2)}');
    if (false)
      print(
        '[GroundDebug] platformTop=${platformTop?.toStringAsFixed(2) ?? "n/a"}',
      );
    if (false)
      print('[GroundDebug] velocityY=${velocity.y.toStringAsFixed(2)}');
    if (false) print('[GroundDebug] grounded=$isOnGround');
    if (false) print('[GroundDebug] currentAnim=$animName');
    if (false) print('[GroundDebug] visualDestRect=${visualDest ?? "n/a"}');
    if (false)
      print(
        '[GroundDebug] visualFeetBottom=${visualFeetBottom?.toStringAsFixed(2) ?? "n/a"}',
      );
  }

  // ── Weapon render ─────────────────────────────────────────────────────────
  // TEMPORARILY DISABLED during Player animation testing
  // Re-enable by calling _renderWeapon(canvas) in render() when needed
  // ignore: unused_element
  void _renderWeapon(Canvas canvas) {
    if (!isAlive) return;
    const gunLength = 16.0;
    const gunHeight = 5.0;
    final dir = facingDirection.toDouble();
    final centerX = size.x / 2 + dir * (size.x / 2 - 4);
    final centerY = size.y / 2 - 8;

    final bodyPaint = Paint()..color = const Color(0xFF6A6A6A);
    final muzzlePaint = Paint()..color = const Color(0xFFB8E8FF);

    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: gunLength,
        height: gunHeight,
      ),
      bodyPaint,
    );
    canvas.drawCircle(
      Offset(centerX + dir * (gunLength / 2), centerY),
      1.8,
      muzzlePaint,
    );
  }

  // ── Sprite visual layer ───────────────────────────────────────────────────

  Future<void> _tryInitSpriteVisual() async {
    final visualData = await _buildVisualDataForWeapon(currentWeapon);
    if (visualData == null) {
      _animationRenderer = null;
      return;
    }
    await _applyVisualData(
      visualData,
      preferredState: _resolveVisualAnimState(),
      isInitialLoad: true,
    );
    _syncSpriteVisual();
  }

  Future<void> _refreshWeaponVisuals({
    required int version,
    required PlayerAnimState visualState,
  }) async {
    final requestedWeapon = currentWeapon;
    final visualData = await _buildVisualDataForWeapon(requestedWeapon);
    if (version != _weaponSwitchVersion) {
      if (debugWeaponSwitchLogs) {
        if (false)
          print('[PlayerWeapon] switch ignored (stale version=$version)');
      }
      return;
    }
    if (visualData == null) {
      if (debugWeaponSwitchLogs) {
        if (false)
          print(
            '[PlayerWeapon] switch failed weapon=${requestedWeapon.name} state=${visualState.name}',
          );
      }
      return;
    }

    await _applyVisualData(
      visualData,
      preferredState: visualState,
      isInitialLoad: _animationRenderer == null,
    );
    _syncSpriteVisual();

    if (debugWeaponSwitchLogs) {
      if (false)
        print(
          '[PlayerWeapon] switch applied weapon=${requestedWeapon.name} state=${visualState.name}',
        );
    }
  }

  Future<void> _applyVisualData(
    _PlayerVisualData visualData, {
    required PlayerAnimState preferredState,
    required bool isInitialLoad,
  }) async {
    if (_animationRenderer == null) {
      final baseScale = playerDesiredVisualHeight / playerLogicalFrameHeight;
      final visualContainerSize = Vector2(
        playerLogicalFrameWidth * baseScale,
        playerDesiredVisualHeight,
      );

      _animationRenderer =
          _PlayerAnimationRenderer(
              bundles: Map<PlayerAnimState, _AtlasAnimationBundle>.from(
                visualData.bundles,
              ),
              debugMeta: _debugAnimMeta,
              scaleMultipliers: Map<PlayerAnimState, double>.from(
                visualData.scaleMultipliers,
              ),
              renderOffsetsLogical: Map<PlayerAnimState, Offset>.from(
                visualData.renderOffsetsLogical,
              ),
              desiredVisualHeight: playerDesiredVisualHeight,
              parentGameplaySize: size.clone(),
            )
            ..size = visualContainerSize
            ..position = Vector2(size.x / 2, size.y)
            ..anchor = Anchor.bottomCenter
            ..priority = 0;

      await add(_animationRenderer!);
      if (debugRenderOrderLogs) {
        if (false)
          print(
            '[RenderOrder] component=_PlayerAnimationRenderer priority=${_animationRenderer!.priority}',
          );
      }
    } else {
      _animationRenderer!.replaceVisualData(
        nextBundles: visualData.bundles,
        nextDebugMeta: visualData.debugMeta,
        nextScaleMultipliers: visualData.scaleMultipliers,
        nextRenderOffsetsLogical: visualData.renderOffsetsLogical,
        preferredState: preferredState,
      );
    }

    _debugAnimMeta
      ..clear()
      ..addAll(visualData.debugMeta);

    if (isInitialLoad && debugIdleTwoFramesOnly) {
      _forcedAnimState = PlayerAnimState.idle;
      _animationRenderer?.setAnimationState(PlayerAnimState.idle);
      _animationRenderer?.setFacingDirection(1);
    }
  }

  Future<_PlayerVisualData?> _buildVisualDataForWeapon(
    WeaponType weapon,
  ) async {
    await _ensureRenderNormalizationReference();

    final idleBundle = await _resolveBundleWithFallback(
      PlayerAnimState.idle,
      weapon,
    );
    if (idleBundle == null) {
      if (debugWeaponSwitchLogs) {
        if (false)
          print('[PlayerWeapon] idle bundle missing for weapon=${weapon.name}');
      }
      return null;
    }

    final runBundle = debugIdleTwoFramesOnly
        ? null
        : await _resolveBundleWithFallback(PlayerAnimState.run, weapon);
    final jumpBundle = debugIdleTwoFramesOnly
        ? null
        : await _resolveBundleWithFallback(PlayerAnimState.jump, weapon);
    final deathBundle = debugIdleTwoFramesOnly
        ? null
        : await _resolveBundleWithFallback(PlayerAnimState.death, weapon);

    final idleDebugBundle = (debugIdleTwoFramesOnly)
        ? _AtlasAnimationBundle(
            imagePath: idleBundle.imagePath,
            atlasPath: idleBundle.atlasPath,
            image: idleBundle.image,
            frames:
                idleBundle.frames
                    .where((f) => f.frameIndex >= 0 && f.frameIndex <= 12)
                    .toList(growable: false)
                  ..sort((a, b) => a.frameIndex.compareTo(b.frameIndex)),
          )
        : null;

    final idleOnlyBundle = idleDebugBundle ?? idleBundle;
    if (debugIdleTwoFramesOnly && idleOnlyBundle.frames.isEmpty) {
      if (false)
        print('[IdleDebug] FAILED: idle frameIndex 0..12 not available');
      return null;
    }

    double resolveMaxBboxHeight(_AtlasAnimationBundle? bundle) {
      if (bundle == null || bundle.frames.isEmpty) return 0;
      return bundle.frames.map((f) => f.src.height).reduce(max);
    }

    final idleMaxBboxHeight = resolveMaxBboxHeight(idleBundle);
    final runMaxBboxHeight = resolveMaxBboxHeight(runBundle);
    final jumpMaxBboxHeight = resolveMaxBboxHeight(jumpBundle);
    final targetBboxHeight =
        _referenceIdleMaxBboxHeight ??
        (idleMaxBboxHeight > 0 ? idleMaxBboxHeight : 1.0);

    final autoRunScaleMultiplier = runMaxBboxHeight > 0
        ? targetBboxHeight / runMaxBboxHeight
        : 1.0;
    final autoJumpScaleMultiplier = jumpMaxBboxHeight > 0
        ? (targetBboxHeight / jumpMaxBboxHeight).clamp(0.95, 1.20).toDouble()
        : 1.0;

    final idleScaleMultiplier = idleVisualMultiplier;
    final runScaleMultiplier =
        runVisualMultiplierOverride ?? autoRunScaleMultiplier;
    final jumpScaleMultiplier =
        jumpVisualMultiplierOverride ?? autoJumpScaleMultiplier;
    final weaponScaleMultiplier = weapon == WeaponType.sniperGun
        ? sniperRenderScale
        : 1.0;
    final sniperRunOnlyScaleMultiplier = weapon == WeaponType.sniperGun
        ? sniperRunRenderScale
        : 1.0;

    final scaleMultipliers = <PlayerAnimState, double>{
      PlayerAnimState.idle: idleScaleMultiplier * weaponScaleMultiplier,
      PlayerAnimState.run:
          runScaleMultiplier *
          weaponScaleMultiplier *
          sniperRunOnlyScaleMultiplier,
      PlayerAnimState.jump: jumpScaleMultiplier * weaponScaleMultiplier,
      PlayerAnimState.dash: 1.0 * weaponScaleMultiplier,
      PlayerAnimState.gun: 1.0 * weaponScaleMultiplier,
      PlayerAnimState.death: deathVisualMultiplier * weaponScaleMultiplier,
    };

    final bundles = debugIdleTwoFramesOnly
        ? <PlayerAnimState, _AtlasAnimationBundle>{
            PlayerAnimState.idle: idleOnlyBundle,
            PlayerAnimState.run: idleOnlyBundle,
            PlayerAnimState.jump: idleOnlyBundle,
            PlayerAnimState.gun: idleOnlyBundle,
            PlayerAnimState.death: idleOnlyBundle,
            PlayerAnimState.dash: idleOnlyBundle,
          }
        : <PlayerAnimState, _AtlasAnimationBundle>{
            PlayerAnimState.idle: idleBundle,
            PlayerAnimState.run: runBundle ?? idleBundle,
            PlayerAnimState.jump: jumpBundle ?? runBundle ?? idleBundle,
            PlayerAnimState.gun: idleBundle,
            PlayerAnimState.death:
                deathBundle ?? jumpBundle ?? runBundle ?? idleBundle,
            PlayerAnimState.dash: runBundle ?? idleBundle,
          };

    final renderOffsetsLogical = <PlayerAnimState, Offset>{};
    for (final entry in bundles.entries) {
      final bundle = entry.value;
      final bundleWeapon = _weaponTypeFromImagePath(bundle.imagePath);
      final manualOffset =
          _manualWeaponRenderOffsetsLogical[bundleWeapon] ?? Offset.zero;
      final autoOffsetX = _referenceBodyCenterX == null
          ? 0.0
          : _referenceBodyCenterX! - _estimateBodyCenterX(bundle);
      final offset = Offset(autoOffsetX + manualOffset.dx, manualOffset.dy);
      renderOffsetsLogical[entry.key] = offset;

      if (debugWeaponSwitchLogs) {
        if (false)
          print(
            '[PlayerRenderNormalize] state=${entry.key.name} weapon=${bundleWeapon.name} '
            'autoOffsetX=${autoOffsetX.toStringAsFixed(2)} '
            'manualOffset=(${manualOffset.dx.toStringAsFixed(2)},${manualOffset.dy.toStringAsFixed(2)}) '
            'finalOffset=(${offset.dx.toStringAsFixed(2)},${offset.dy.toStringAsFixed(2)})',
          );
      }
    }

    final debugMeta = <PlayerAnimState, _DebugAnimMeta>{
      PlayerAnimState.idle: _DebugAnimMeta(
        label: 'idle',
        frameCount: debugIdleTwoFramesOnly
            ? idleOnlyBundle.frames.length
            : idleBundle.frames.length,
        stepTime: 0.12,
        loop: true,
        bundle: debugIdleTwoFramesOnly ? idleOnlyBundle : idleBundle,
      ),
      PlayerAnimState.run: _DebugAnimMeta(
        label: 'run',
        frameCount: debugIdleTwoFramesOnly
            ? idleOnlyBundle.frames.length
            : runBundle?.frames.length ?? 0,
        stepTime: runAnimationStepTime,
        loop: true,
        bundle: debugIdleTwoFramesOnly ? idleOnlyBundle : runBundle,
      ),
      PlayerAnimState.jump: _DebugAnimMeta(
        label: 'jump',
        frameCount: debugIdleTwoFramesOnly
            ? idleOnlyBundle.frames.length
            : jumpBundle?.frames.length ?? 0,
        stepTime: 0.12,
        loop: !debugIdleTwoFramesOnly,
        bundle: debugIdleTwoFramesOnly ? idleOnlyBundle : jumpBundle,
      ),
      PlayerAnimState.dash: _DebugAnimMeta(
        label: 'dash',
        frameCount: debugIdleTwoFramesOnly
            ? idleOnlyBundle.frames.length
            : runBundle?.frames.length ?? 0,
        stepTime: 0.08,
        loop: true,
        bundle: debugIdleTwoFramesOnly ? idleOnlyBundle : runBundle,
      ),
      PlayerAnimState.death: _DebugAnimMeta(
        label: 'death',
        frameCount: debugIdleTwoFramesOnly
            ? idleOnlyBundle.frames.length
            : deathBundle?.frames.length ?? 0,
        stepTime: 0.06,
        loop: false,
        bundle: debugIdleTwoFramesOnly ? idleOnlyBundle : deathBundle,
      ),
      PlayerAnimState.gun: _DebugAnimMeta(
        label: 'gun',
        frameCount: debugIdleTwoFramesOnly
            ? idleOnlyBundle.frames.length
            : idleBundle.frames.length,
        stepTime: 0.12,
        loop: true,
        bundle: debugIdleTwoFramesOnly ? idleOnlyBundle : idleBundle,
      ),
    };

    return _PlayerVisualData(
      bundles: bundles,
      debugMeta: debugMeta,
      scaleMultipliers: scaleMultipliers,
      renderOffsetsLogical: renderOffsetsLogical,
    );
  }

  Future<void> _ensureRenderNormalizationReference() async {
    if (_referenceIdleMaxBboxHeight != null && _referenceBodyCenterX != null) {
      return;
    }

    final refIdle = await _loadBundleCached(
      PlayerAnimState.idle,
      WeaponType.autoGun,
    );
    if (refIdle == null) {
      return;
    }

    _referenceIdleMaxBboxHeight = _resolveMaxBboxHeight(refIdle);
    _referenceBodyCenterX = _estimateBodyCenterX(refIdle);

    if (debugWeaponSwitchLogs) {
      if (false)
        print(
          '[PlayerRenderNormalize] reference idle autoGun '
          'bboxHeight=${_referenceIdleMaxBboxHeight!.toStringAsFixed(2)} '
          'bodyCenterX=${_referenceBodyCenterX!.toStringAsFixed(2)}',
        );
    }
  }

  double _resolveMaxBboxHeight(_AtlasAnimationBundle bundle) {
    if (bundle.frames.isEmpty) return 0.0;
    return bundle.frames.map((f) => f.src.height).reduce(max);
  }

  double _estimateBodyCenterX(_AtlasAnimationBundle bundle) {
    if (bundle.frames.isEmpty) {
      return _AtlasAnimationBundle.logicalFrameWidth / 2.0;
    }
    var sum = 0.0;
    for (final frame in bundle.frames) {
      sum += frame.originalX + frame.src.width / 2.0;
    }
    return sum / bundle.frames.length;
  }

  WeaponType _weaponTypeFromImagePath(String imagePath) {
    if (imagePath.contains('_sniper_gun')) {
      return WeaponType.sniperGun;
    }
    return WeaponType.autoGun;
  }

  Future<_AtlasAnimationBundle?> _resolveBundleWithFallback(
    PlayerAnimState state,
    WeaponType weapon,
  ) async {
    final resolvedState = _resolveAssetAnimState(state);
    final primary = await _loadBundleCached(resolvedState, weapon);
    if (primary != null) return primary;
    if (weapon == WeaponType.autoGun) return null;

    if (debugWeaponSwitchLogs) {
      if (false)
        print(
          '[PlayerWeapon] fallback -> autoGun state=${resolvedState.name} weapon=${weapon.name}',
        );
    }
    return _loadBundleCached(resolvedState, WeaponType.autoGun);
  }

  Future<_AtlasAnimationBundle?> _loadBundleCached(
    PlayerAnimState state,
    WeaponType weapon,
  ) async {
    final key = '${state.name}_${weapon.name}';
    if (_animationBundleCache.containsKey(key)) {
      if (debugWeaponSwitchLogs) {
        if (false) print('[PlayerWeapon] cache hit key=$key');
      }
      return _animationBundleCache[key];
    }

    final paths = _resolveAssetPaths(state: state, weapon: weapon);
    final bundle = await _loadAtlasBundle(
      imagePath: paths.imagePath,
      atlasPath: paths.atlasPath,
      label: paths.label,
    );
    _animationBundleCache[key] = bundle;

    if (debugWeaponSwitchLogs) {
      if (bundle == null) {
        if (false)
          print(
            '[PlayerWeapon] load failed key=$key image=${paths.imagePath} atlas=${paths.atlasPath}',
          );
      } else {
        if (false)
          print(
            '[PlayerWeapon] loaded key=$key image=${paths.imagePath.split('/').last} '
            'atlas=${paths.atlasPath.split('/').last} frames=${bundle.frames.length}',
          );
      }
    }

    return bundle;
  }

  _WeaponAssetPaths _resolveAssetPaths({
    required PlayerAnimState state,
    required WeaponType weapon,
  }) {
    final resolvedState = _resolveAssetAnimState(state);
    final animName = switch (resolvedState) {
      PlayerAnimState.idle => 'idle',
      PlayerAnimState.run => 'run',
      PlayerAnimState.jump => 'jump',
      PlayerAnimState.death => 'death',
      PlayerAnimState.dash => 'run',
      PlayerAnimState.gun => 'idle',
    };

    final suffix = switch (weapon) {
      WeaponType.autoGun => '_auto_gun',
      WeaponType.sniperGun => '_sniper_gun',
    };

    final base = '$_playerAtlasAssetsRoot/player_${animName}$suffix';
    return _WeaponAssetPaths(
      imagePath: '$base.png',
      atlasPath: '${base}_atlas.json',
      label: '${animName}_${weapon.name}',
    );
  }

  PlayerAnimState _resolveAssetAnimState(PlayerAnimState state) {
    switch (state) {
      case PlayerAnimState.dash:
        return PlayerAnimState.run;
      case PlayerAnimState.gun:
        return PlayerAnimState.idle;
      case PlayerAnimState.idle:
      case PlayerAnimState.run:
      case PlayerAnimState.jump:
      case PlayerAnimState.death:
        return state;
    }
  }

  // _buildAnimationFromBundle is NO LONGER USED - replaced by custom _PlayerAnimationRenderer

  Future<_AtlasAnimationBundle?> _loadAtlasBundle({
    required String imagePath,
    required String atlasPath,
    required String label,
    int? minFrameIndex,
    int? maxFrameIndex,
  }) async {
    final image = await loadUiImageSafe(imagePath);
    if (image == null) {
      if (_debugRunAtlas) {
        if (false) print('[PlayerAtlas] $label image load failed: $imagePath');
      }
      return null;
    }

    if (_debugRunAtlas) {
      if (false)
        print(
          '[PlayerAtlas] $label image source: $imagePath (${image.width}x${image.height})',
        );
      if (false) print('[PlayerAtlas] $label atlas source: $atlasPath');
    }

    try {
      final atlasRaw = await rootBundle.loadString(atlasPath);
      final decoded = jsonDecode(atlasRaw);
      if (decoded is! List) {
        if (_debugRunAtlas) {
          if (false)
            print(
              '[PlayerAtlas] $label atlas format error: root is not a List',
            );
        }
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

      final selected = atlasFrames
          .where((frame) {
            final idx = (frame['frameIndex'] as num).toInt();
            if (minFrameIndex != null && idx < minFrameIndex) return false;
            if (maxFrameIndex != null && idx > maxFrameIndex) return false;
            return true;
          })
          .toList(growable: false);

      final frameDefs =
          selected
              .map((frame) {
                final idx = (frame['frameIndex'] as num).toInt();
                final row = (frame['row'] as num?)?.toInt() ?? -1;
                final col = (frame['col'] as num?)?.toInt() ?? -1;
                final x = (frame['x'] as num).toDouble();
                final y = (frame['y'] as num).toDouble();
                final w = (frame['width'] as num).toDouble();
                final h = (frame['height'] as num).toDouble();
                final origX = (frame['originalX'] as num?)?.toDouble() ?? 0.0;
                final origY = (frame['originalY'] as num?)?.toDouble() ?? 0.0;

                final right = x + w;
                final bottom = y + h;
                final inBounds =
                    x >= 0 &&
                    y >= 0 &&
                    right <= image.width &&
                    bottom <= image.height;
                if (!inBounds && _debugRunAtlas) {
                  if (false)
                    print(
                      '[PlayerAtlas] $label frame $idx OUT OF BOUNDS: '
                      'x=$x y=$y w=$w h=$h image=${image.width}x${image.height}',
                    );
                }
                if (!inBounds) {
                  return null;
                }

                return _AtlasFrameDef(
                  frameIndex: idx,
                  row: row,
                  col: col,
                  src: Rect.fromLTWH(x, y, w, h),
                  originalX: origX,
                  originalY: origY,
                );
              })
              .whereType<_AtlasFrameDef>()
              .toList(growable: false)
            ..sort((a, b) => a.frameIndex.compareTo(b.frameIndex));

      if (_debugRunAtlas) {
        final indexes = frameDefs
            .map((f) => f.frameIndex)
            .toList(growable: false);
        if (false)
          print('[PlayerAtlas] $label frames loaded: ${frameDefs.length}');
        if (false) print('[PlayerAtlas] $label frameIndex order: $indexes');
        for (final f in frameDefs.take(3)) {
          if (false)
            print(
              '[PlayerAtlas] $label frame ${f.frameIndex} '
              'src=(${f.src.left.toInt()}, ${f.src.top.toInt()}, ${f.src.width.toInt()}x${f.src.height.toInt()}) '
              'orig=(${f.originalX.toInt()}, ${f.originalY.toInt()}) row=${f.row} col=${f.col}',
            );
        }
        if (frameDefs.length > 3) {
          if (false)
            print(
              '[PlayerAtlas] $label ... (${frameDefs.length - 3} more frames)',
            );
        }
        if (minFrameIndex == 0 && maxFrameIndex == 12) {
          if (false)
            print(
              '[PlayerAtlas] $label loop: 0 → 1 → ... → 12 → 0 (run/idle only)',
            );
        }
      }

      if (frameDefs.isEmpty) {
        return null;
      }

      return _AtlasAnimationBundle(
        imagePath: imagePath,
        atlasPath: atlasPath,
        image: image,
        frames: frameDefs,
      );
    } catch (e) {
      if (_debugRunAtlas) {
        if (false)
          print(
            '[PlayerAtlas] $label atlas load/parse failed: $atlasPath ($e)',
          );
      }
      return null;
    }
  }

  Color _resolvePlaceholderColor() {
    switch (_animState) {
      case PlayerAnimState.idle:
        return const Color(0xFFFF3A3A);
      case PlayerAnimState.run:
        return _animTime % 0.2 < 0.1
            ? const Color(0xFFFF6A6A)
            : const Color(0xFFFF4A4A);
      case PlayerAnimState.jump:
        return const Color(0xFFFF9A3A);
      case PlayerAnimState.dash:
        return const Color(0xFFFFFF3A);
      case PlayerAnimState.gun:
        return const Color(0xFF7AA4FF);
      case PlayerAnimState.death:
        return const Color(0xFF777777);
    }
  }

  void beginDying() {
    if (!isAlive) return;
    _lifeState = PlayerLifeState.dying;
    velocity.setZero();
    weaponManager.setTriggerHeld(false);
    _isMovementInputActive = false;
    _isSprintHeld = false;
    isOnGround = true;
    _setAnimationState(PlayerAnimState.death);

    if (kDebugMode) {
      debugPrint('[PLAYER_DEATH] started');
      debugPrint('[PLAYER_DEATH] velocity zeroed');
      debugPrint('[PLAYER_DEATH] death animation speed x2');
    }
  }

  void markDead() {
    if (_lifeState == PlayerLifeState.dead) return;
    _lifeState = PlayerLifeState.dead;
    velocity.setZero();
    weaponManager.setTriggerHeld(false);
    _isMovementInputActive = false;
    _isSprintHeld = false;
    isOnGround = true;
    _setAnimationState(PlayerAnimState.death);

    if (kDebugMode) {
      debugPrint('[PLAYER_DEATH] velocity zeroed');
    }
  }
}
