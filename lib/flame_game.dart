import 'package:flame/camera.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';

import 'config/game_config.dart';
import 'core/bloc/heat_bloc.dart';
import 'core/bloc/states/heat_state.dart';
import 'player/player_component.dart';
import 'sound_assets.dart';
import 'systems/hazard_system.dart';
import 'systems/heat_system.dart';
import 'systems/particle_system.dart';
import 'ui/ui_manager.dart';
import 'world/game_world.dart';

enum SectorRewardChoice { hullPatch, coolingPulse }

enum PlayerDeathPhase { none, dying, gameOver }

class VoidRelayGame extends FlameGame {
  HeatBloc? heatBloc;
  HeatSystem? heatSystem;
  HazardSystem? hazardSystem;
  ParticleSystem? particleSystem;
  GameWorld? gameWorld;
  final UiManager uiManager = const UiManager();
  bool _isGameOverShown = false;
  PlayerDeathPhase _playerDeathPhase = PlayerDeathPhase.none;
  double _playerDeathTimer = 0.0;
  double _playerMaxHealthBonus = 0;
  final Map<String, int> _lastSfxAtMs = {};
  final Map<LogicalKeyboardKey, bool> _appKeyPrev = {};
  double? _fixedCameraY;

  /// Index of the room currently loaded (survives room transitions).
  int currentRoomIndex = 0;

  /// Причина останнього переходу між секторами.
  String transitionReason = 'Room cleared';

  bool get isPauseOpen => overlays.isActive(UiManager.pauseOverlay);
  bool get isMainMenuOpen => overlays.isActive(UiManager.mainMenuOverlay);
  bool get isRewardOpen => overlays.isActive(UiManager.rewardOverlay);
  bool get isGameOverOpen => overlays.isActive(UiManager.gameOverOverlay);
  bool get isTransitionOpen => overlays.isActive(UiManager.transitionOverlay);
  bool get isGameplayInputBlocked =>
      isMainMenuOpen ||
      isRewardOpen ||
      isPauseOpen ||
      isGameOverOpen ||
      isTransitionOpen ||
      isDeathSequenceActive;
  bool get isDeathSequenceActive => _playerDeathPhase == PlayerDeathPhase.dying;

  Future<void> playSfx(String key, {int? minIntervalMs}) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final interval = minIntervalMs ?? SoundAssets.minIntervalMs[key] ?? 120;
    final lastMs = _lastSfxAtMs[key];
    if (lastMs != null && nowMs - lastMs < interval) return;
    _lastSfxAtMs[key] = nowMs;
    await SystemSound.play(SoundAssets.toSystemSound(key));
  }

  // ── World lifecycle ────────────────────────────────────────────────────────

  void _rebuildGameWorld() {
    final oldWorld = gameWorld;
    if (oldWorld != null && oldWorld.isMounted) {
      oldWorld.removeFromParent();
    }
    final newWorld = GameWorld(
      roomIndex: currentRoomIndex,
      playerMaxHealthBonus: _playerMaxHealthBonus,
    );
    newWorld.onSectorComplete = triggerSectorTransition;
    gameWorld = newWorld;
    world.add(newWorld);

    final newParticles = ParticleSystem();
    particleSystem = newParticles;
    newWorld.add(newParticles);

    _fixedCameraY = null;
    _updateCameraFollow(snap: true);
  }

  void _freezeGameplayMotion() {
    final player = gameWorld?.player;
    if (player == null) return;
    player.stopHorizontal();
    player.velocity.y = 0;
  }

  // ── Flame lifecycle ────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    camera.viewport = FixedResolutionViewport(
      resolution: Vector2(GameConfig.logicalWidth, GameConfig.logicalHeight),
    );

    heatBloc = HeatBloc();
    heatSystem = HeatSystem(heatBloc: heatBloc!);
    add(heatSystem!);

    hazardSystem = HazardSystem();
    add(hazardSystem!);

    final world = GameWorld(
      roomIndex: currentRoomIndex,
      playerMaxHealthBonus: _playerMaxHealthBonus,
    );
    world.onSectorComplete = triggerSectorTransition;
    gameWorld = world;
    this.world.add(world);

    final worldParticles = ParticleSystem();
    particleSystem = worldParticles;
    world.add(worldParticles);

    _updateCameraFollow(snap: true);
  }

  void spawnHitSpark(Vector2 worldPosition) {
    particleSystem?.spawnHitSpark(worldPosition);
  }

  void spawnDashTrail(Vector2 worldPosition, {required int direction}) {
    particleSystem?.spawnDashTrail(worldPosition, direction: direction);
  }

  void spawnWarningPulse(Vector2 worldPosition) {
    particleSystem?.spawnWarningPulse(worldPosition);
  }

  @override
  void update(double dt) {
    super.update(dt);

    _updateAppHotkeys();
    _updateCameraFollow();

    if (isDeathSequenceActive) {
      _playerDeathTimer -= dt;
      if (_playerDeathTimer <= 0) {
        _playerDeathPhase = PlayerDeathPhase.gameOver;
        gameWorld?.player.markDead();
        triggerGameOver();
      }
      return;
    }

    final currentHeatState = heatBloc?.state;
    if (!_isGameOverShown && currentHeatState is HeatOverheated) {
      triggerGameOver();
    }
  }

  void _updateAppHotkeys() {
    _handleHotkeyOnce(LogicalKeyboardKey.escape);
    _handleHotkeyOnce(LogicalKeyboardKey.keyP);
    _handleHotkeyOnce(LogicalKeyboardKey.keyN);
    _handleHotkeyOnce(LogicalKeyboardKey.keyG);
    _handleHotkeyOnce(LogicalKeyboardKey.keyB);
    _handleHotkeyOnce(LogicalKeyboardKey.keyT);
    _handleHotkeyOnce(LogicalKeyboardKey.keyL);
    _handleHotkeyOnce(LogicalKeyboardKey.keyY);
    _handleHotkeyOnce(LogicalKeyboardKey.keyR);
    _handleHotkeyOnce(LogicalKeyboardKey.keyU);
    _handleHotkeyOnce(LogicalKeyboardKey.enter);

    // 1/2 app-level only in reward screen; in gameplay they stay for weapon slots.
    if (isRewardOpen) {
      _handleHotkeyOnce(LogicalKeyboardKey.digit1);
      _handleHotkeyOnce(LogicalKeyboardKey.digit2);
    }
  }

  void _handleHotkeyOnce(LogicalKeyboardKey key) {
    final pressed = HardwareKeyboard.instance.isLogicalKeyPressed(key);
    final wasPressed = _appKeyPrev[key] ?? false;
    if (pressed && !wasPressed) {
      handleAppInputKey(key);
    }
    _appKeyPrev[key] = pressed;
  }

  void _updateCameraFollow({bool snap = false}) {
    final world = gameWorld;
    if (world == null) return;
    if (world.roomSize.x <= 0 || world.roomSize.y <= 0) return;

    PlayerComponent player;
    try {
      player = world.player;
    } catch (_) {
      return;
    }
    final visible = camera.visibleWorldRect;
    final halfW = visible.width / 2;
    final halfH = visible.height / 2;

    final minX = halfW;
    final maxX = world.roomSize.x - halfW;
    final minY = halfH;
    final maxY = world.roomSize.y - halfH;

    final targetX = maxX < minX
        ? world.roomSize.x / 2
        : player.position.x.clamp(minX, maxX).toDouble();

    // Camera moves only on X. Y is anchored to the bottom of the lowest platform.
    _fixedCameraY ??= () {
      if (maxY < minY) return world.roomSize.y / 2;
      final lowestBottom = world.lowestPlatformBottom;
      final anchoredY = lowestBottom - halfH;
      return anchoredY.clamp(minY, maxY).toDouble();
    }();
    final targetY = _fixedCameraY!;

    final smoothing = GameConfig.cameraFollowSmoothing;
    if (snap || smoothing >= 1.0) {
      camera.viewfinder.position = Vector2(targetX, targetY);
      return;
    }

    final current = camera.viewfinder.position;
    camera.viewfinder.position = Vector2(
      current.x + (targetX - current.x) * smoothing,
      current.y + (targetY - current.y) * smoothing,
    );
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Keep camera clamped when user resizes desktop window.
    _updateCameraFollow(snap: true);
  }

  // ── UI triggers ───────────────────────────────────────────────────────────

  void triggerPause() {
    if (isMainMenuOpen) return;
    if (isDeathSequenceActive) return;
    if (isGameOverOpen || isTransitionOpen) return;
    if (isPauseOpen) return;
    _freezeGameplayMotion();
    uiManager.showPause(this);
  }

  void startFromMainMenu() {
    if (!isMainMenuOpen) return;
    uiManager.hideMainMenu(this);
    uiManager.showHud(this);
    resumeEngine();
  }

  void openMainMenu() {
    if (isMainMenuOpen) return;
    if (isDeathSequenceActive) return;
    _freezeGameplayMotion();
    uiManager.showMainMenu(this);
  }

  void resumeFromPause() {
    if (!isPauseOpen) return;
    uiManager.hidePause(this);
  }

  void triggerGameOver() {
    if (isGameOverOpen) return;
    _isGameOverShown = true;
    if (_playerDeathPhase == PlayerDeathPhase.none) {
      _playerDeathPhase = PlayerDeathPhase.gameOver;
    }
    _freezeGameplayMotion();
    if (isPauseOpen) uiManager.hidePause(this);
    if (isTransitionOpen) uiManager.hideTransition(this);
    uiManager.showGameOver(this);
  }

  void beginPlayerDeathSequence() {
    if (_playerDeathPhase != PlayerDeathPhase.none) return;
    if (isGameOverOpen) return;
    _playerDeathPhase = PlayerDeathPhase.dying;
    _playerDeathTimer = GameConfig.playerDeathSequenceDuration;
    _freezeGameplayMotion();
    gameWorld?.player.beginDying();
    if (isPauseOpen) uiManager.hidePause(this);
    if (isTransitionOpen) uiManager.hideTransition(this);
  }

  void resetAfterGameOver() {
    _isGameOverShown = false;
    _playerDeathPhase = PlayerDeathPhase.none;
    _playerDeathTimer = 0.0;
    currentRoomIndex = 0;
    _playerMaxHealthBonus = 0;
    uiManager.closeTransientScreens(this);
    heatSystem?.resetHeat();
    hazardSystem?.reset();
    _rebuildGameWorld();
    resumeEngine();
  }

  /// Охолоджує heat гравця (викликається CoolingStation через game reference).
  void coolHeat(double amount) => heatSystem?.coolHeat(amount);

  /// Запускає blackout событие (для тестування або ручної активації).
  void triggerBlackout({double? duration}) {
    hazardSystem?.triggerBlackout(duration: duration);
  }

  bool get isBlackoutActive => hazardSystem?.isBlackoutActive ?? false;

  /// Запускає toxic gas событие (для тестування або ручної активації).
  void triggerToxicGas({double? duration}) {
    hazardSystem?.triggerToxicGas(duration: duration);
  }

  bool get isToxicGasActive => hazardSystem?.isToxicGasActive ?? false;

  /// Запускає system breakdown событие (для тестування або ручної активації).
  void triggerSystemBreakdown() {
    hazardSystem?.triggerSystemBreakdown();
  }

  /// Завершує system breakdown через troubleshooting flow.
  void resolveSystemBreakdown() {
    hazardSystem?.resolveSystemBreakdown();
  }

  bool get isSystemBreakdownActive =>
      hazardSystem?.isSystemBreakdownActive ?? false;

  /// Запускає door failure событие (для тестування або ручної активації).
  void triggerDoorFailure() {
    hazardSystem?.triggerDoorFailure();
  }

  /// Завершує door failure (викликається repair-взаємодією або debug input).
  void resolveDoorFailure() {
    hazardSystem?.resolveDoorFailure();
  }

  bool get isDoorFailureActive => hazardSystem?.isDoorFailureActive ?? false;

  void triggerSectorTransition([String reason = 'Room cleared']) {
    if (isGameOverOpen) return;
    if (isDeathSequenceActive) return;
    if (isTransitionOpen) return;
    if (isDoorFailureActive) return;
    transitionReason = reason;
    playSfx(SoundAssets.transition);
    _freezeGameplayMotion();
    if (isPauseOpen) uiManager.hidePause(this);
    uiManager.showTransition(this);
  }

  void completeSectorTransition() {
    if (!isTransitionOpen) return;
    uiManager.hideTransition(this);
    heatSystem?.resetHeat(); // скидаємо heat при вході в новий сектор
    currentRoomIndex++;
    _rebuildGameWorld();
  }

  void openRewardStepFromTransition() {
    if (!isTransitionOpen) return;
    overlays.remove(UiManager.transitionOverlay);
    uiManager.showReward(this);
  }

  void applyRewardAndAdvance(SectorRewardChoice choice) {
    if (!isRewardOpen) return;

    switch (choice) {
      case SectorRewardChoice.hullPatch:
        _playerMaxHealthBonus += 10;
        break;
      case SectorRewardChoice.coolingPulse:
        heatSystem?.resetHeat();
        hazardSystem?.delayNextEvent(8);
        break;
    }

    uiManager.hideReward(this);

    heatSystem?.resetHeat();
    currentRoomIndex++;
    _rebuildGameWorld();
    resumeEngine();
  }

  // ── Keyboard shortcuts ────────────────────────────────────────────────────

  bool handleAppInputKey(LogicalKeyboardKey key) {
    if (isDeathSequenceActive) {
      return false;
    }

    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.keyP) {
      if (isPauseOpen) {
        resumeFromPause();
      } else {
        triggerPause();
      }
      return true;
    }

    if (key == LogicalKeyboardKey.keyN) {
      triggerSectorTransition();
      return true;
    }

    if (key == LogicalKeyboardKey.keyG) {
      triggerGameOver();
      return true;
    }

    if (key == LogicalKeyboardKey.keyB) {
      triggerBlackout();
      return true;
    }

    if (key == LogicalKeyboardKey.keyT) {
      triggerToxicGas();
      return true;
    }

    if (key == LogicalKeyboardKey.keyL) {
      triggerDoorFailure();
      return true;
    }

    if (key == LogicalKeyboardKey.keyY) {
      triggerSystemBreakdown();
      return true;
    }

    if (key == LogicalKeyboardKey.keyR) {
      resolveDoorFailure();
      return true;
    }

    if (key == LogicalKeyboardKey.keyU) {
      resolveSystemBreakdown();
      return true;
    }

    if (key == LogicalKeyboardKey.enter && isGameOverOpen) {
      resetAfterGameOver();
      return true;
    }

    if (key == LogicalKeyboardKey.enter && isMainMenuOpen) {
      startFromMainMenu();
      return true;
    }

    if (key == LogicalKeyboardKey.enter &&
        !isMainMenuOpen &&
        !isGameOverOpen &&
        !isRewardOpen) {
      openMainMenu();
      return true;
    }

    if (isRewardOpen && key == LogicalKeyboardKey.digit1) {
      applyRewardAndAdvance(SectorRewardChoice.hullPatch);
      return true;
    }

    if (isRewardOpen && key == LogicalKeyboardKey.digit2) {
      applyRewardAndAdvance(SectorRewardChoice.coolingPulse);
      return true;
    }

    return false;
  }

  @override
  void onRemove() {
    heatBloc?.close();
    super.onRemove();
  }

  double get currentHeatValue => heatBloc?.state.currentHeat ?? 0.0;

  double get currentHealthValue => gameWorld?.player.health ?? 0.0;

  double get maxHealthValue => gameWorld?.player.maxHealth ?? 100.0;

  bool get hasAliveHostiles => gameWorld?.hasAliveHostiles ?? false;

  int get aliveHostilesCount => gameWorld?.aliveHostilesCount ?? 0;
}
