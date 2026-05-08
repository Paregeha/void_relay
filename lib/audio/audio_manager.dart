import 'dart:async';

import 'package:flame_audio/bgm.dart';
import 'package:flame_audio/flame_audio.dart';

class GameAudio {
  static const double gameMusicVolume = 0.38;
  static const double gameMusicDuckedVolume = 0.18;
  static const String menuSoundAsset = 'menu-sound.mp3';
  static const String _legacyMenuSoundAsset = 'menu_sound.mp3';
  static const String gameMusicAsset = 'game-music.mp3';
  static const String alarmSoundAsset = 'alarm.mp3';
  static const String doorSoundAsset = 'door.mp3';
  static const String switchButtonAsset = 'switch-button.mp3';
  static const String blasterShotAsset = 'blaster_shot.mp3';
  static const String enemyBlasterShotAsset = 'blaster-enemy.mp3';
  static const String coolingPickupAsset = 'cooling.mp3';
  static const String terminalSoundAsset = 'terminal.mp3';

  final _menuBgm = FlameAudio.bgm;
  final Bgm _gameBgm = Bgm(audioCache: FlameAudio.audioCache);
  final Bgm _alarmBgm = Bgm(audioCache: FlameAudio.audioCache);
  AudioPool? _switchButtonPool;
  Future<void>? _switchButtonPoolInit;
  AudioPool? _blasterShotPool;
  Future<void>? _blasterShotPoolInit;
  bool _blasterShotPoolFailed = false;
  AudioPool? _enemyBlasterShotPool;
  Future<void>? _enemyBlasterShotPoolInit;
  bool _enemyBlasterShotPoolFailed = false;
  AudioPool? _terminalPool;
  Future<void>? _terminalPoolInit;
  bool _terminalPoolFailed = false;
  AudioPool? _doorPool;
  Future<void>? _doorPoolInit;
  bool _doorPoolFailed = false;
  AudioPool? _coolingPickupPool;
  Future<void>? _coolingPickupPoolInit;
  bool _coolingPickupPoolFailed = false;

  bool _isMuted = false;
  bool _appHasFocus = true;
  bool _menuLoopPlaying = false;
  bool _gameLoopPlaying = false;
  bool _alarmLoopPlaying = false;
  bool _disposed = false;
  bool _initialized = false;
  bool _menuPlayStarting = false;

  bool get isMuted => _isMuted;
  bool get appHasFocus => _appHasFocus;
  bool get isMenuLoopPlaying => _menuLoopPlaying;
  bool get isGameLoopPlaying => _gameLoopPlaying;
  bool get isAlarmLoopPlaying => _alarmLoopPlaying;

  void _syncMenuLoopState() {
    if (_disposed) {
      _menuLoopPlaying = false;
      return;
    }
    if (_menuLoopPlaying && !_menuBgm.isPlaying) {
      _menuLoopPlaying = false;
    }
  }

  Future<void> setAppAudioFocus(bool focused) async {
    if (_appHasFocus == focused) return;
    _appHasFocus = focused;
    if (!_appHasFocus) {
      await pauseAllForFocusLoss();
      return;
    }
    await resumeAudioAfterFocusReturn();
  }

  Future<void> pauseAllForFocusLoss() async {
    await pauseMenuSound();
    await pauseGameMusic();
    await pauseAlarmSound();
  }

  Future<void> resumeAudioAfterFocusReturn() async {
    await resumeMenuSound();
    await resumeGameMusic();
    await resumeAlarmSound();
  }

  Future<void> _safeAudioCall(
    String label,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (_) {}
  }

  Future<void> initialize() async {
    if (_disposed || _initialized) return;
    _initialized = true;
    await _safeAudioCall('menu_bgm.initialize', () => _menuBgm.initialize());
    await _safeAudioCall('game_bgm.initialize', () => _gameBgm.initialize());
    await _safeAudioCall('alarm_bgm.initialize', () => _alarmBgm.initialize());

    await _safeAudioCall('audio_cache.preload', () async {
      await FlameAudio.audioCache.loadAll(const [
        menuSoundAsset,
        _legacyMenuSoundAsset,
        gameMusicAsset,
        alarmSoundAsset,
        doorSoundAsset,
        switchButtonAsset,
        blasterShotAsset,
        enemyBlasterShotAsset,
        coolingPickupAsset,
        terminalSoundAsset,
      ]);
    });

    // Prebuild a small low-latency pool so UI clicks start instantly.
    _switchButtonPoolInit ??= _initSwitchButtonPool();
    await (_switchButtonPoolInit ?? Future.value());
    _blasterShotPoolInit ??= _initBlasterShotPool();
    await (_blasterShotPoolInit ?? Future.value());
    _enemyBlasterShotPoolInit ??= _initEnemyBlasterShotPool();
    await (_enemyBlasterShotPoolInit ?? Future.value());
    _terminalPoolInit ??= _initTerminalPool();
    await (_terminalPoolInit ?? Future.value());
    _doorPoolInit ??= _initDoorPool();
    await (_doorPoolInit ?? Future.value());
    _coolingPickupPoolInit ??= _initCoolingPickupPool();
    await (_coolingPickupPoolInit ?? Future.value());
  }

  Future<void> _initSwitchButtonPool() async {
    if (_disposed || _switchButtonPool != null) return;
    try {
      _switchButtonPool = await AudioPool.create(
        source: AssetSource(switchButtonAsset),
        audioCache: FlameAudio.audioCache,
        minPlayers: 2,
        maxPlayers: 8,
        playerMode: PlayerMode.lowLatency,
      );
    } catch (_) {
      // Pool is an optimization; fallback playback keeps UI functional.
      _switchButtonPool = null;
    }
  }

  Future<void> _initBlasterShotPool() async {
    if (_disposed || _blasterShotPool != null) return;
    try {
      _blasterShotPool = await FlameAudio.createPool(
        blasterShotAsset,
        minPlayers: 3,
        maxPlayers: 8,
      );
    } catch (_) {
      _blasterShotPool = null;
      _blasterShotPoolFailed = true;
    }
  }

  Future<void> _initEnemyBlasterShotPool() async {
    if (_disposed || _enemyBlasterShotPool != null) return;
    try {
      _enemyBlasterShotPool = await FlameAudio.createPool(
        enemyBlasterShotAsset,
        minPlayers: 2,
        maxPlayers: 6,
      );
    } catch (_) {
      _enemyBlasterShotPool = null;
      _enemyBlasterShotPoolFailed = true;
    }
  }

  Future<void> _initTerminalPool() async {
    if (_disposed || _terminalPool != null) return;
    try {
      _terminalPool = await FlameAudio.createPool(
        terminalSoundAsset,
        minPlayers: 1,
        maxPlayers: 3,
      );
    } catch (_) {
      _terminalPool = null;
      _terminalPoolFailed = true;
    }
  }

  Future<void> _initDoorPool() async {
    if (_disposed || _doorPool != null) return;
    try {
      _doorPool = await FlameAudio.createPool(
        doorSoundAsset,
        minPlayers: 1,
        maxPlayers: 4,
      );
    } catch (_) {
      _doorPool = null;
      _doorPoolFailed = true;
    }
  }

  Future<void> _initCoolingPickupPool() async {
    if (_disposed || _coolingPickupPool != null) return;
    try {
      _coolingPickupPool = await FlameAudio.createPool(
        coolingPickupAsset,
        minPlayers: 1,
        maxPlayers: 4,
      );
    } catch (_) {
      _coolingPickupPool = null;
      _coolingPickupPoolFailed = true;
    }
  }

  Future<void> setMuted(bool muted) async {
    _isMuted = muted;
    if (_isMuted) {
      unawaited(stopMenuSound());
      unawaited(stopGameMusic());
      unawaited(stopAlarmSound());
    }
  }

  Future<void> playMenuSound() async {
    if (_disposed) return;
    _syncMenuLoopState();
    if (_isMuted) return;
    if (_menuPlayStarting) return;
    if (!_appHasFocus) {
      return;
    }
    if (_menuLoopPlaying) {
      return;
    }
    _menuPlayStarting = true;
    try {
      if (_gameLoopPlaying) {
        unawaited(stopGameMusic());
      }

      await _safeAudioCall('play_menu_sound.initialize', () async {
        await initialize();
      });

      try {
        await _menuBgm.play(menuSoundAsset, volume: 0.45);
        if (_menuBgm.isPlaying) {
          _menuLoopPlaying = true;
          return;
        }
      } catch (_) {}

      try {
        await _menuBgm.play(_legacyMenuSoundAsset, volume: 0.45);
        if (_menuBgm.isPlaying) {
          _menuLoopPlaying = true;
          return;
        }
      } catch (_) {}

      _menuLoopPlaying = false;
    } finally {
      _menuPlayStarting = false;
    }
  }

  Future<void> debugTestMenuAudioPipeline() async {
    const path = menuSoundAsset;
    try {
      await FlameAudio.bgm.stop();
    } catch (_) {}

    try {
      await FlameAudio.bgm.play(path, volume: 0.45);
      _menuLoopPlaying = FlameAudio.bgm.isPlaying;
    } catch (_) {
      _menuLoopPlaying = false;
    }
  }

  Future<void> playGameMusic() async {
    if (_disposed || _isMuted || !_appHasFocus || _gameLoopPlaying) return;
    if (_menuLoopPlaying) {
      await stopMenuSound();
    }
    await _safeAudioCall('play_game_music', () async {
      await initialize();
      _gameLoopPlaying = true;
      await _gameBgm.play(gameMusicAsset, volume: gameMusicVolume);
      if (!_gameBgm.isPlaying) {
        _gameLoopPlaying = false;
      }
    });
    if (!_gameBgm.isPlaying) {
      _gameLoopPlaying = false;
    }
  }

  Future<void> duckGameMusicForEvent() async {
    if (_disposed || _isMuted || !_gameLoopPlaying) return;
    await _safeAudioCall(
      'duck_game_music_for_event',
      () => _gameBgm.audioPlayer.setVolume(gameMusicDuckedVolume),
    );
  }

  Future<void> restoreGameMusicAfterEvent() async {
    if (_disposed || _isMuted || !_gameLoopPlaying) return;
    await _safeAudioCall(
      'restore_game_music_after_event',
      () => _gameBgm.audioPlayer.setVolume(gameMusicVolume),
    );
  }

  Future<void> playAlarmSound() async {
    if (_disposed || _isMuted || !_appHasFocus || _alarmLoopPlaying) return;
    await _safeAudioCall('play_alarm_sound', () async {
      await initialize();
      _alarmLoopPlaying = true;
      await _alarmBgm.play(alarmSoundAsset, volume: 0.65);
      if (!_alarmBgm.isPlaying) {
        _alarmLoopPlaying = false;
      }
    });
    if (!_alarmBgm.isPlaying) {
      _alarmLoopPlaying = false;
    }
  }

  Future<void> playButtonClickSound({double playbackRate = 1.0}) async {
    if (_disposed || _isMuted || !_appHasFocus) return;

    final pool = _switchButtonPool;
    if (pool != null && playbackRate == 1.0) {
      unawaited(pool.start(volume: 0.75));
      return;
    }

    try {
      await initialize();
      final initializedPool = _switchButtonPool;
      if (initializedPool != null && playbackRate == 1.0) {
        unawaited(initializedPool.start(volume: 0.75));
        return;
      }

      final player = await FlameAudio.play(switchButtonAsset, volume: 0.75);
      if (playbackRate != 1.0) {
        await player.setPlaybackRate(playbackRate);
      }
    } catch (_) {
      // Ignore click SFX failures to avoid blocking UI actions.
    }
  }

  Future<void> playBlasterShotSound() async {
    if (_disposed || _isMuted || !_appHasFocus) return;

    final pool = _blasterShotPool;
    if (pool != null) {
      unawaited(pool.start(volume: 0.8));
      return;
    }

    if (_blasterShotPoolFailed) return;
    await initialize();
    final initializedPool = _blasterShotPool;
    if (initializedPool != null) {
      unawaited(initializedPool.start(volume: 0.8));
    }
  }

  Future<void> playEnemyBlasterShotSound() async {
    if (_disposed || _isMuted || !_appHasFocus) return;

    final pool = _enemyBlasterShotPool;
    if (pool != null) {
      unawaited(pool.start(volume: 0.72));
      return;
    }

    if (_enemyBlasterShotPoolFailed) return;
    await initialize();
    final initializedPool = _enemyBlasterShotPool;
    if (initializedPool != null) {
      unawaited(initializedPool.start(volume: 0.72));
    }
  }

  Future<void> playCoolingPickupSound() async {
    if (_disposed || _isMuted || !_appHasFocus) return;

    final pool = _coolingPickupPool;
    if (pool != null) {
      unawaited(pool.start(volume: 0.8));
      return;
    }

    if (_coolingPickupPoolFailed) return;
    try {
      await initialize();
      final initializedPool = _coolingPickupPool;
      if (initializedPool != null) {
        unawaited(initializedPool.start(volume: 0.8));
      }
    } catch (_) {}
  }

  Future<void> playTerminalSound() async {
    if (_disposed || _isMuted || !_appHasFocus) return;

    final pool = _terminalPool;
    if (pool != null) {
      unawaited(pool.start(volume: 0.8));
      return;
    }

    if (_terminalPoolFailed) return;
    await initialize();
    final initializedPool = _terminalPool;
    if (initializedPool != null) {
      unawaited(initializedPool.start(volume: 0.8));
    }
  }

  Future<void> playDoorSound() async {
    if (_disposed || _isMuted || !_appHasFocus) return;

    final pool = _doorPool;
    if (pool != null) {
      unawaited(pool.start(volume: 0.78));
      return;
    }

    if (_doorPoolFailed) return;
    await initialize();
    final initializedPool = _doorPool;
    if (initializedPool != null) {
      unawaited(initializedPool.start(volume: 0.78));
    }
  }

  Future<void> stopMenuSound() async {
    if (_disposed) return;
    _menuPlayStarting = false;
    _menuLoopPlaying = false;
    await _safeAudioCall('stop_menu_sound', () => _menuBgm.stop());
    _syncMenuLoopState();
  }

  Future<void> stopGameMusic() async {
    if (_disposed) return;
    _gameLoopPlaying = false;
    await _safeAudioCall('stop_game_music', () => _gameBgm.stop());
  }

  Future<void> stopAlarmSound() async {
    if (_disposed) return;
    _alarmLoopPlaying = false;
    await _safeAudioCall('stop_alarm_sound', () => _alarmBgm.stop());
  }

  Future<void> pauseMenuSound() async {
    if (_disposed || !_menuLoopPlaying) return;
    await _safeAudioCall('pause_menu_sound', () => _menuBgm.pause());
    _syncMenuLoopState();
  }

  Future<void> pauseGameMusic() async {
    if (_disposed || !_gameLoopPlaying) return;
    await _safeAudioCall('pause_game_music', () => _gameBgm.pause());
  }

  Future<void> pauseAlarmSound() async {
    if (_disposed || !_alarmLoopPlaying) return;
    await _safeAudioCall('pause_alarm_sound', () => _alarmBgm.pause());
  }

  Future<void> resumeMenuSound() async {
    if (_disposed || _isMuted || !_appHasFocus || !_menuLoopPlaying) return;
    await _safeAudioCall('resume_menu_sound', () => _menuBgm.resume());
    if (_menuBgm.isPlaying) {
      _menuLoopPlaying = true;
    }
  }

  Future<void> resumeGameMusic() async {
    if (_disposed || _isMuted || !_appHasFocus || !_gameLoopPlaying) return;
    await _safeAudioCall('resume_game_music', () => _gameBgm.resume());
  }

  Future<void> resumeAlarmSound() async {
    if (_disposed || _isMuted || !_appHasFocus || !_alarmLoopPlaying) return;
    await _safeAudioCall('resume_alarm_sound', () => _alarmBgm.resume());
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _safeAudioCall('dispose.switch_button_pool', () async {
      await _switchButtonPool?.dispose();
    });
    await _safeAudioCall('dispose.blaster_pool', () async {
      await _blasterShotPool?.dispose();
    });
    await _safeAudioCall('dispose.enemy_blaster_pool', () async {
      await _enemyBlasterShotPool?.dispose();
    });
    await _safeAudioCall('dispose.terminal_pool', () async {
      await _terminalPool?.dispose();
    });
    await _safeAudioCall('dispose.door_pool', () async {
      await _doorPool?.dispose();
    });
    await _safeAudioCall('dispose.cooling_pool', () async {
      await _coolingPickupPool?.dispose();
    });
    await _safeAudioCall('dispose.menu_bgm.stop', () => _menuBgm.stop());
    await _safeAudioCall('dispose.game_bgm.stop', () => _gameBgm.stop());
    await _safeAudioCall('dispose.alarm_bgm.stop', () => _alarmBgm.stop());
    await _safeAudioCall('dispose.menu_bgm', () => _menuBgm.dispose());
    await _safeAudioCall('dispose.game_bgm', () => _gameBgm.dispose());
    await _safeAudioCall('dispose.alarm_bgm', () => _alarmBgm.dispose());
  }
}
