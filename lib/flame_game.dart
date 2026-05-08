import 'dart:async';
import 'dart:ui';

import 'package:flame/camera.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:void_relay/systems/particle_system.dart';

import 'audio/audio_manager.dart';
import 'config/game_config.dart';
import 'core/bloc/heat_bloc.dart';
import 'core/bloc/states/heat_state.dart';
import 'core/debug/render_trace.dart';
import 'enemies/hover_drone/hover_drone.dart';
import 'player/player_component.dart';
import 'sound_assets.dart';
import 'systems/difficulty_director.dart';
import 'systems/difficulty_profile.dart';
import 'systems/hazard_system.dart';
import 'systems/heat_system.dart';
import 'systems/leaderboard_service.dart';
import 'systems/save_game_service.dart';
import 'ui/ui_manager.dart';
import 'world/game_world.dart';

enum SectorRewardChoice { hullPatch, coolingPulse }

enum PlayerDeathPhase { none, dying, gameOver }

class VoidRelayGame extends FlameGame {
  final DifficultyDirector difficultyDirector = const DifficultyDirector();
  final GameAudio audio = GameAudio();
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
  double? _fixedCameraY;
  bool _appHasFocus = true;
  bool _menuAutoplayFallbackPending = false;
  bool _initialMenuAutoplayPending = true;
  bool _gameMusicPendingAfterGesture = false;
  DifficultyProfile _difficultyProfile = DifficultyProfile.baseline;
  int _score = 0;
  String? _exitBlockedMessage;
  double _exitBlockedMessageTimer = 0.0;
  bool _leaderboardSubmittedForRun = false;

  double get playerMaxHealthBonus => _playerMaxHealthBonus;
  DifficultyProfile get difficultyProfile => _difficultyProfile;
  int get score => _score;
  String? get exitBlockedMessage => _exitBlockedMessage;

  /// Index of the room currently loaded (survives room transitions).
  int currentRoomIndex = 0;
  int get currentLevel => currentRoomIndex + 1;

  /// Причина останнього переходу між секторами.
  String transitionReason = 'Relay reached';

  bool get isPauseOpen => overlays.isActive(UiManager.pauseOverlay);
  bool get isSaveSlotsOpen => overlays.isActive(UiManager.saveSlotsOverlay);
  bool get isMainMenuOpen => overlays.isActive(UiManager.mainMenuOverlay);
  bool get isRewardOpen => overlays.isActive(UiManager.rewardOverlay);
  bool get isGameOverOpen => overlays.isActive(UiManager.gameOverOverlay);
  bool get isTransitionOpen => overlays.isActive(UiManager.transitionOverlay);
  bool get isFirstTimePromptOpen =>
      overlays.isActive(UiManager.firstTimePromptOverlay);
  bool get isFirstTimeInstructionOpen =>
      overlays.isActive(UiManager.firstTimeInstructionOverlay);
  bool get isGameplayInputBlocked =>
      isMainMenuOpen ||
      isRewardOpen ||
      isPauseOpen ||
      isSaveSlotsOpen ||
      isGameOverOpen ||
      isTransitionOpen ||
      isFirstTimePromptOpen ||
      isFirstTimeInstructionOpen ||
      isDeathSequenceActive;
  bool get isDeathSequenceActive => _playerDeathPhase == PlayerDeathPhase.dying;

  Future<void> playSfx(String key, {int? minIntervalMs}) async {
    if (!_appHasFocus) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final interval = minIntervalMs ?? SoundAssets.minIntervalMs[key] ?? 120;
    final lastMs = _lastSfxAtMs[key];
    if (lastMs != null && nowMs - lastMs < interval) return;
    _lastSfxAtMs[key] = nowMs;
    await SystemSound.play(SoundAssets.toSystemSound(key));
  }

  void setAppFocus(bool focused) {
    if (_appHasFocus == focused) return;
    _appHasFocus = focused;
    unawaited(audio.setAppAudioFocus(focused));

    if (!_appHasFocus) {
      return;
    }

    if (isMainMenuOpen) {
      unawaited(playMenuSound());
      return;
    }

    if (!isMainMenuOpen) {
      unawaited(ensureGameplayMusic());
    }

    final hasActiveHazard = hazardSystem?.currentEvent != null;
    if (hasActiveHazard) {
      unawaited(playAlarmSound());
    } else {
      unawaited(stopAlarmSound());
      unawaited(restoreGameMusicAfterEvent());
    }
  }

  // ── World lifecycle ────────────────────────────────────────────────────────

  void _rebuildGameWorld() {
    final oldWorld = gameWorld;
    if (oldWorld != null && oldWorld.isMounted) {
      oldWorld.removeFromParent();
    }
    _difficultyProfile = difficultyDirector.generateProfile(
      currentLevel: currentRoomIndex + 1,
    );
    _logDifficultyProfile();
    final newWorld = GameWorld(
      roomIndex: currentRoomIndex,
      playerMaxHealthBonus: _playerMaxHealthBonus,
      difficultyProfile: _difficultyProfile,
    );
    newWorld.onSectorComplete = triggerSectorTransition;
    gameWorld = newWorld;
    world.add(newWorld);

    final newParticles = ParticleSystem(
      renderPriority: GameWorld.effectsPriority,
    );
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

    _difficultyProfile = difficultyDirector.generateProfile(
      currentLevel: currentRoomIndex + 1,
    );
    _logDifficultyProfile();

    final world = GameWorld(
      roomIndex: currentRoomIndex,
      playerMaxHealthBonus: _playerMaxHealthBonus,
      difficultyProfile: _difficultyProfile,
    );
    world.onSectorComplete = triggerSectorTransition;
    gameWorld = world;
    this.world.add(world);

    final worldParticles = ParticleSystem(
      renderPriority: GameWorld.effectsPriority,
    );
    particleSystem = worldParticles;
    world.add(worldParticles);

    _updateCameraFollow(snap: true);

    // Ensure SFX pools are ready before gameplay starts to avoid first-shot audio lag.
    await audio.initialize();
    // Initial overlays may not be attached yet during onLoad, so defer one retry.
    _initialMenuAutoplayPending = true;
    unawaited(tryAutoplayMenuSound());
  }

  void notifyMainMenuUserGesture() {
    notifyGlobalUserGesture();
  }

  void notifyGlobalUserGesture() {
    if (isMainMenuOpen) {
      unawaited(playMenuSound());
    }
    if (!isMainMenuOpen && _gameMusicPendingAfterGesture) {
      unawaited(ensureGameplayMusic());
    }
  }

  Future<void> tryAutoplayMenuSound() async {
    if (!_appHasFocus) {
      if (kDebugMode) debugPrint('[AUDIO_MENU] skip: app inactive');
      return;
    }
    if (!isMainMenuOpen) {
      if (kDebugMode) debugPrint('[AUDIO_MENU] skip: main menu not active');
      return;
    }
    if (audio.isMenuLoopPlaying) {
      if (kDebugMode) debugPrint('[AUDIO_MENU] skip: already playing');
      return;
    }

    await playMenuSound();
    if (!isMainMenuOpen || audio.isMuted || audio.isMenuLoopPlaying) {
      return;
    }

    if (kDebugMode) debugPrint('[AUDIO_MENU] skip: audio not unlocked');
    if (_menuAutoplayFallbackPending) {
      return;
    }
    _menuAutoplayFallbackPending = true;
    if (kDebugMode) {
      debugPrint(
        '[AUDIO] Menu sound autoplay blocked, waiting for first user gesture',
      );
    }
  }

  Future<void> playMenuSound() async {
    if (kDebugMode) debugPrint('[AUDIO_MENU] play requested');
    await audio.playMenuSound();
    if (audio.isMenuLoopPlaying) {
      if (kDebugMode) debugPrint('[AUDIO_MENU] play success');
      _menuAutoplayFallbackPending = false;
      return;
    }
    if (kDebugMode) debugPrint('[AUDIO_MENU] play failed');
  }

  Future<void> debugTestMenuAudio() async {
    await audio.debugTestMenuAudioPipeline();
  }

  Future<void> playButtonClickSound() => audio.playButtonClickSound();

  Future<void> playBlasterShotSound() => audio.playBlasterShotSound();

  Future<void> playEnemyBlasterShotSound() => audio.playEnemyBlasterShotSound();

  Future<void> playTerminalSound() => audio.playTerminalSound();

  Future<void> playDoorSound() => audio.playDoorSound();

  Future<void> playCoolingPickupSound() => audio.playCoolingPickupSound();

  Future<void> playGameMusic() => audio.playGameMusic();

  Future<void> ensureGameplayMusic() async {
    await playGameMusic();
    if (audio.isGameLoopPlaying) {
      _gameMusicPendingAfterGesture = false;
      return;
    }
    if (audio.isMuted || isMainMenuOpen) {
      return;
    }
    if (_gameMusicPendingAfterGesture) {
      return;
    }
    _gameMusicPendingAfterGesture = true;
    if (kDebugMode) {
      debugPrint(
        '[AUDIO] Game music autoplay blocked, waiting for first user gesture',
      );
    }
  }

  Future<void> playAlarmSound() => audio.playAlarmSound();

  Future<void> duckGameMusicForEvent() => audio.duckGameMusicForEvent();

  Future<void> restoreGameMusicAfterEvent() =>
      audio.restoreGameMusicAfterEvent();

  Future<void> stopMenuSound() => audio.stopMenuSound();

  Future<void> stopGameMusic() async {
    _gameMusicPendingAfterGesture = false;
    await audio.stopGameMusic();
  }

  Future<void> stopAlarmSound() => audio.stopAlarmSound();

  Future<void> pauseMenuSound() => audio.pauseMenuSound();

  Future<void> pauseGameMusic() => audio.pauseGameMusic();

  Future<void> pauseAlarmSound() => audio.pauseAlarmSound();

  Future<void> resumeMenuSound() => audio.resumeMenuSound();

  Future<void> resumeGameMusic() => audio.resumeGameMusic();

  Future<void> resumeAlarmSound() => audio.resumeAlarmSound();

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
    if (PlayerComponent.debugTraceRenderSequence) {
      RenderTrace.beginFrame(source: 'VoidRelayGame.update');
    }
    super.update(dt);

    _tryInitialMenuAutoplay();
    _updateCameraFollow();

    if (_exitBlockedMessageTimer > 0) {
      _exitBlockedMessageTimer -= dt;
      if (_exitBlockedMessageTimer <= 0) {
        _exitBlockedMessageTimer = 0;
        _exitBlockedMessage = null;
      }
    }

    if (isDeathSequenceActive) {
      _playerDeathTimer -= dt;
      if (_playerDeathTimer <= 0) {
        if (kDebugMode) {
          debugPrint('[PLAYER_DEATH] death animation completed');
        }
        _playerDeathPhase = PlayerDeathPhase.gameOver;
        gameWorld?.player.markDead();
        triggerGameOver();
      }
      return;
    }

    if (GameConfig.enableCoreHeating) {
      final currentHeatState = heatBloc?.state;
      if (!_isGameOverShown && currentHeatState is HeatOverheated) {
        triggerGameOver();
      }
    }
  }

  void _tryInitialMenuAutoplay() {
    if (!_initialMenuAutoplayPending) return;
    if (!isMainMenuOpen) return;
    _initialMenuAutoplayPending = false;
    unawaited(tryAutoplayMenuSound());
  }

  void notifyLevelExitBlocked({required int enemiesAlive}) {
    _exitBlockedMessage = 'ELIMINATE ALL HOSTILES';
    _exitBlockedMessageTimer = 1.6;
    if (kDebugMode) {
      debugPrint('[LEVEL_EXIT] blocked: enemiesAlive=$enemiesAlive');
    }
  }

  void notifyLevelExitUnlocked() {
    _exitBlockedMessage = 'EXIT UNLOCKED';
    _exitBlockedMessageTimer = 1.6;
  }

  void onEnemyKilled({required String enemyType}) {
    final normalized = enemyType.toLowerCase();
    var gained = 0;
    if (normalized == 'enemy3' || normalized == 'basic_enemy') {
      gained = 1;
    } else if (normalized == 'hover_drone') {
      gained = 2;
    } else if (normalized == 'sentry_turret') {
      gained = 3;
    }
    if (gained <= 0) return;
    _score += gained;
    if (kDebugMode) {
      final label = normalized == 'basic_enemy' ? 'enemy3' : normalized;
      debugPrint('[SCORE] $label killed +$gained total=$_score');
    }
  }

  void setScoreFromSave(int value) {
    _score = value < 0 ? 0 : value;
    if (kDebugMode) {
      debugPrint('[LOAD] score=$_score');
      debugPrint('[LOAD] level=$currentLevel');
    }
  }

  void openLeaderboardFromMainMenu() {
    if (!isMainMenuOpen) return;
    if (kDebugMode) {
      debugPrint('[LEADERBOARD] opened');
    }
    if (!overlays.isActive(UiManager.leaderboardOverlay)) {
      overlays.add(UiManager.leaderboardOverlay);
    }
  }

  void closeLeaderboardOverlay() {
    overlays.remove(UiManager.leaderboardOverlay);
  }

  void _logDifficultyProfile() {
    if (!kDebugMode) return;
    final p = _difficultyProfile;
    debugPrint(
      '[DIFFICULTY] generated level with profile='
      'DifficultyProfile('
      'level=${p.level}, '
      'enemyCount=${p.enemyCount}, '
      'hpMultiplier=${p.enemyHpMultiplier.toStringAsFixed(2)}, '
      'speedMultiplier=${p.enemySpeedMultiplier.toStringAsFixed(2)}, '
      'turretChance=${p.turretChance.toStringAsFixed(2)}, '
      'droneChance=${p.droneChance.toStringAsFixed(2)}, '
      'coolingPickupChance=${p.coolingPickupChance.toStringAsFixed(2)}, '
      'healthPickupChance=${p.healthPickupChance.toStringAsFixed(2)})',
    );
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
  void render(Canvas canvas) {
    if (PlayerComponent.debugTraceRenderSequence) {
      if (false)
        RenderTrace.log('VoidRelayGame.render START (before super.render)');
    }

    super.render(canvas);

    if (PlayerComponent.debugTraceRenderSequence) {
      if (false)
        RenderTrace.log('VoidRelayGame.render END (after super.render)');
      if (false)
        RenderTrace.log(
          'HUD active=${overlays.isActive(UiManager.hudOverlay)} '
          'Pause=${overlays.isActive(UiManager.pauseOverlay)} '
          'GameOver=${overlays.isActive(UiManager.gameOverOverlay)}',
        );
    }
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

  Future<void> cleanupBeforeExitToMenu() async {
    _freezeGameplayMotion();
    uiManager.hideHud(this);
    uiManager.closeTransientScreens(this);
    overlays.remove(UiManager.loadGameOverlay);
    overlays.remove(UiManager.saveSlotsOverlay);

    hazardSystem?.reset();
    heatSystem?.resetHeat();
    _isGameOverShown = false;
    _playerDeathPhase = PlayerDeathPhase.none;
    _playerDeathTimer = 0.0;

    final oldWorld = gameWorld;
    if (oldWorld != null && oldWorld.isMounted) {
      oldWorld.removeFromParent();
    }
    gameWorld = null;
    particleSystem = null;
    _fixedCameraY = null;

    pauseEngine();
    unawaited(stopAlarmSound());
    unawaited(restoreGameMusicAfterEvent());
    _gameMusicPendingAfterGesture = false;
    unawaited(stopGameMusic());
    uiManager.showMainMenu(this);
  }

  Future<void> startFromMainMenu() async {
    await startFromMainMenuWithFirstTime(isFirstTime: false);
  }

  void openNewGameFirstTimePrompt() {
    if (!isMainMenuOpen) return;
    if (isFirstTimePromptOpen) return;
    uiManager.showFirstTimePrompt(this);
  }

  Future<void> confirmNewGameFirstTimeSelection({
    required bool isFirstTime,
  }) async {
    uiManager.hideFirstTimePrompt(this);
    await startFromMainMenuWithFirstTime(isFirstTime: isFirstTime);
  }

  Future<void> startFromMainMenuWithFirstTime({
    required bool isFirstTime,
  }) async {
    if (!isMainMenuOpen) return;
    unawaited(stopMenuSound());
    currentRoomIndex = 0;
    _playerMaxHealthBonus = 0;
    _score = 0;
    _leaderboardSubmittedForRun = false;
    _isGameOverShown = false;
    _playerDeathPhase = PlayerDeathPhase.none;
    _playerDeathTimer = 0.0;
    overlays.remove(UiManager.loadGameOverlay);
    heatSystem?.resetHeat();
    hazardSystem?.reset();
    _rebuildGameWorld();
    closeLeaderboardOverlay();
    uiManager.hideFirstTimePrompt(this);
    uiManager.hideFirstTimeInstruction(this);
    uiManager.hideMainMenu(this);
    unawaited(ensureGameplayMusic());
    uiManager.showHud(this);
    if (isFirstTime) {
      unawaited(playGameMusic());
      uiManager.showFirstTimeInstruction(this);
      return;
    }
    resumeEngine();
  }

  void closeFirstTimeInstruction() {
    if (!isFirstTimeInstructionOpen) return;
    uiManager.hideFirstTimeInstruction(this);
    if (isMainMenuOpen ||
        isPauseOpen ||
        isRewardOpen ||
        isTransitionOpen ||
        isGameOverOpen ||
        isDeathSequenceActive) {
      return;
    }
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
    closeSaveSlotsOverlay();
    uiManager.hidePause(this);
  }

  Future<void> openMainMenuFromPause() async {
    if (isDeathSequenceActive) return;
    await cleanupBeforeExitToMenu();
  }

  void openSaveSlotsFromPause() {
    if (!isPauseOpen || isDeathSequenceActive) return;
    if (!overlays.isActive(UiManager.saveSlotsOverlay)) {
      overlays.add(UiManager.saveSlotsOverlay);
    }
  }

  void closeSaveSlotsOverlay() {
    overlays.remove(UiManager.saveSlotsOverlay);
  }

  Future<bool> saveGameSafe() async {
    return saveGameToSlot(SaveGameService.defaultQuickSaveSlotId);
  }

  Future<bool> saveGameToSlot(String slotId) async {
    return SaveGameService.saveToSlot(this, slotId);
  }

  Future<void> deleteSaveBySlotId(String slotId) async {
    await SaveGameService.deleteSlot(slotId);
  }

  void openLoadGameFromMainMenu() {
    if (!isMainMenuOpen) return;
    if (!overlays.isActive(UiManager.loadGameOverlay)) {
      overlays.add(UiManager.loadGameOverlay);
    }
  }

  void closeLoadGameOverlay() {
    overlays.remove(UiManager.loadGameOverlay);
  }

  Future<void> loadGameBySlotId(String id) async {
    final save = await SaveGameService.loadById(id);
    if (save == null) {
      return;
    }

    currentRoomIndex = save.roomIndex;
    _playerMaxHealthBonus = save.playerMaxHealthBonus;
    setScoreFromSave(save.score);
    _leaderboardSubmittedForRun = false;
    _isGameOverShown = false;
    _playerDeathPhase = PlayerDeathPhase.none;
    _playerDeathTimer = 0.0;
    heatSystem?.resetHeat();
    hazardSystem?.reset();

    _rebuildGameWorld();
    await gameWorld?.loaded;

    await gameWorld?.applySaveState(save.worldState);

    final player = gameWorld?.player;
    if (player != null) {
      player.position.setValues(save.playerX, save.playerY);
      player.health = save.playerHp
          .toDouble()
          .clamp(0.0, save.playerMaxHp.toDouble())
          .toDouble();
      player.maxHealth = save.playerMaxHp.toDouble();
      player.restoreFacingDirection(save.playerFacingDirection);
      player.setWeapon(SaveGameService.weaponTypeFromName(save.currentWeapon));
      player.velocity.setZero();
      if (save.playerIsGrounded) {
        gameWorld?.snapPlayerToGroundNearCurrentPosition();
      }
    }

    final hazardSave = save.hazardState;
    if (hazardSave != null) {
      hazardSystem?.applySaveState(hazardSave);
    }

    closeLoadGameOverlay();
    uiManager.hideMainMenu(this);
    unawaited(stopMenuSound());
    unawaited(ensureGameplayMusic());
    uiManager.showHud(this);
    resumeEngine();
  }

  Future<Uint8List?> captureGameplayThumbnailPng({
    int width = 320,
    int height = 180,
  }) async {
    final recorder = PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, GameConfig.logicalWidth, GameConfig.logicalHeight),
    );
    render(canvas);
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final bytes = await image.toByteData(format: ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  }

  void triggerGameOver() {
    if (isGameOverOpen) return;
    _isGameOverShown = true;
    if (_playerDeathPhase == PlayerDeathPhase.none) {
      _playerDeathPhase = PlayerDeathPhase.gameOver;
    }
    _freezeGameplayMotion();
    if (isPauseOpen) uiManager.hidePause(this);
    closeSaveSlotsOverlay();
    if (isTransitionOpen) uiManager.hideTransition(this);
    uiManager.showGameOver(this);
    if (!_leaderboardSubmittedForRun) {
      _leaderboardSubmittedForRun = true;
      unawaited(
        LeaderboardService.addEntry(score: _score, level: currentLevel),
      );
    }
    if (kDebugMode) {
      debugPrint('[PLAYER_DEATH] game over shown');
    }
  }

  void beginPlayerDeathSequence() {
    if (_playerDeathPhase != PlayerDeathPhase.none) return;
    if (isGameOverOpen) return;
    _playerDeathPhase = PlayerDeathPhase.dying;
    _playerDeathTimer = GameConfig.playerDeathSequenceDuration;
    _freezeGameplayMotion();
    gameWorld?.player.beginDying();
    if (kDebugMode) {
      debugPrint('[PLAYER_DEATH] started');
      debugPrint('[PLAYER_DEATH] physics disabled');
      debugPrint('[PLAYER_DEATH] death animation started');
    }
    if (isPauseOpen) uiManager.hidePause(this);
    closeSaveSlotsOverlay();
    if (isTransitionOpen) uiManager.hideTransition(this);
  }

  void resetAfterGameOver() {
    _isGameOverShown = false;
    _playerDeathPhase = PlayerDeathPhase.none;
    _playerDeathTimer = 0.0;
    currentRoomIndex = 0;
    _playerMaxHealthBonus = 0;
    _score = 0;
    _leaderboardSubmittedForRun = false;
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

  void triggerSectorTransition([String reason = 'Relay reached']) {
    if (isGameOverOpen) return;
    if (isDeathSequenceActive) return;
    if (isTransitionOpen) return;
    if (isDoorFailureActive) return;
    if (gameWorld?.hasAliveHostiles ?? false) {
      notifyLevelExitBlocked(enemiesAlive: gameWorld?.aliveHostilesCount ?? 0);
      return;
    }
    transitionReason = reason;
    playSfx(SoundAssets.transition);
    _freezeGameplayMotion();
    if (isPauseOpen) uiManager.hidePause(this);
    closeSaveSlotsOverlay();
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
    // App-level keyboard shortcuts are disabled.
    // Gameplay input is handled by dedicated systems (player controller/interactions).
    return false;
  }

  @override
  void onRemove() {
    audio.dispose();
    heatBloc?.close();
    super.onRemove();
  }

  double get currentHeatValue => heatBloc?.state.currentHeat ?? 0.0;

  double get currentHealthValue => gameWorld?.player.health ?? 0.0;

  double get maxHealthValue => gameWorld?.player.maxHealth ?? 100.0;

  bool get hasAliveHostiles => gameWorld?.hasAliveHostiles ?? false;

  int get aliveHostilesCount => gameWorld?.aliveHostilesCount ?? 0;

  bool cycleDroneAnimationDebug() {
    return gameWorld?.cycleFirstDroneAnimationDebug() ?? false;
  }

  bool setDroneAnimationDebugState(String stateName) {
    DroneAnimationState? state;
    switch (stateName) {
      case 'idle':
        state = DroneAnimationState.idle;
        break;
      case 'fly':
        state = DroneAnimationState.fly;
        break;
      case 'shoot':
        state = DroneAnimationState.shoot;
        break;
      default:
        return false;
    }
    return gameWorld?.setFirstDroneAnimationDebugState(state) ?? false;
  }

  bool stepDroneFrameNext() {
    return gameWorld?.stepFirstDroneFrameNext() ?? false;
  }

  bool stepDroneFramePrevious() {
    return gameWorld?.stepFirstDroneFramePrevious() ?? false;
  }
}
