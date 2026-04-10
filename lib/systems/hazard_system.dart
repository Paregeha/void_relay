import 'dart:math';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../flame_game.dart';
import '../sound_assets.dart';
import '../world/game_world.dart';

/// Базовий клас для аварійних подій (blackout, toxic gas, door failure).
abstract class HazardEvent {
  final String eventId;
  final double duration;
  final VoidRelayGame? game;

  double _elapsedTime = 0;
  bool _isResolved = false;

  HazardEvent({required this.eventId, required this.duration, this.game});

  bool get requiresManualResolve => false;

  bool get isActive =>
      requiresManualResolve ? !_isResolved : _elapsedTime < duration;

  void resetLifecycle() {
    _elapsedTime = 0;
    _isResolved = false;
  }

  void markResolved() {
    _isResolved = true;
  }

  /// Оновлює час активності события.
  void updateTime(double dt) {
    _elapsedTime += dt;
  }

  /// Викликається при активації события.
  void onStart() {}

  /// Викликається при деактивації события.
  void onEnd() {}
}

/// Затемнення - гравець не бачить ворогів, гейнгплей наближується до вищого рівня складності.
class BlackoutEvent extends HazardEvent {
  BlackoutEvent({double? duration, super.game})
    : super(
        eventId: 'BLACKOUT',
        duration: duration ?? GameConfig.blackoutDuration,
      );

  @override
  void onStart() {
    // Затемнення активне - UI показує затемнення автоматично
    // через isBlackoutActive getter у HazardSystem
  }

  @override
  void onEnd() {
    // Затемнення завершилось - видимість врацає в нормальний стан
  }
}

/// Отруйний газ - завдає постійну шкоду гравцю, створює стиск необхідності рухатися.
class ToxicGasEvent extends HazardEvent {
  double _damageAccumulator = 0;

  ToxicGasEvent({double? duration, super.game})
    : super(
        eventId: 'TOXIC_GAS',
        duration: duration ?? GameConfig.toxicGasDuration,
      );

  @override
  void onStart() {
    // Газ активний - почати завдавати шкоду
    _damageAccumulator = 0;
  }

  @override
  void onEnd() {
    // Газ закінчився - шкода припиняється
    _damageAccumulator = 0;
  }

  /// Оновлює накопичену шкоду. Викликається з HazardSystem.update()
  void updateDamage(double dt) {
    _damageAccumulator += dt;

    // Завдаємо шкоду кожен GameConfig.toxicGasDamageInterval
    if (_damageAccumulator >= GameConfig.toxicGasDamageInterval) {
      _damageAccumulator -= GameConfig.toxicGasDamageInterval;

      // Завдаємо шкоду гравцю
      final player = game?.gameWorld?.player;
      if (player != null) {
        player.takeDamage(GameConfig.toxicGasDamagePerTick);
      }
    }
  }
}

/// Door failure - блокує прогрес сектора, поки гравець не завершить repair.
class DoorFailureEvent extends HazardEvent {
  DoorFailureEvent({super.game})
    : super(eventId: 'DOOR_FAILURE', duration: GameConfig.doorFailureDuration);

  @override
  bool get requiresManualResolve => true;
}

/// System breakdown - окрема блокуюча поломка з короткою troubleshooting-ціллю.
class SystemBreakdownEvent extends HazardEvent {
  SystemBreakdownEvent({super.game})
    : super(
        eventId: 'SYSTEM_BREAKDOWN',
        duration: GameConfig.systemBreakdownDuration,
      );

  @override
  bool get requiresManualResolve => true;
}

/// Система управління аварійними подіями.
class HazardSystem extends Component {
  HazardEvent? _currentEvent;
  double _timeSinceLastEvent = 0;
  final List<String> _completedEventIds = [];

  // Детерміновані cooldown-таймери без randomness/clock-time.
  double _timeSinceLastBlackout = 9999;
  double _timeSinceLastToxicGas = 9999;
  double _timeSinceLastSystemBreakdown = 9999;
  double _timeSinceLastDoorFailure = 9999;

  int _lastProcessedSectorIndex = -1;
  bool _doorFailureTriggeredInSector = false;
  final Random _random = Random();

  HazardEvent? get currentEvent => _currentEvent;
  bool get isBlackoutActive => _currentEvent?.eventId == 'BLACKOUT';
  bool get isToxicGasActive => _currentEvent?.eventId == 'TOXIC_GAS';
  bool get isSystemBreakdownActive =>
      _currentEvent?.eventId == 'SYSTEM_BREAKDOWN';
  bool get isDoorFailureActive => _currentEvent?.eventId == 'DOOR_FAILURE';

  /// Показує скільки часу залишилось для поточного события.
  double get currentEventProgress => _currentEvent == null
      ? 0
      : _currentEvent!._elapsedTime / _currentEvent!.duration;

  @override
  void update(double dt) {
    super.update(dt);

    if (!GameConfig.hazardEventsEnabled) return;

    final game = findGame();
    if (game is VoidRelayGame && game.isGameplayInputBlocked) {
      return;
    }

    if (game is! VoidRelayGame) return;

    _timeSinceLastBlackout += dt;
    _timeSinceLastToxicGas += dt;
    _timeSinceLastSystemBreakdown += dt;
    _timeSinceLastDoorFailure += dt;

    final world = game.gameWorld;
    final currentSectorIndex = world?.roomIndex ?? -1;
    if (currentSectorIndex != _lastProcessedSectorIndex) {
      _lastProcessedSectorIndex = currentSectorIndex;
      _doorFailureTriggeredInSector = false;
    }

    // Оновлюємо поточне событие
    if (_currentEvent != null && _currentEvent!.isActive) {
      _currentEvent!.updateTime(dt);

      // Для toxic gas - застосуємо шкоду
      if (_currentEvent is ToxicGasEvent) {
        (_currentEvent as ToxicGasEvent).updateDamage(dt);
      }
    } else if (_currentEvent != null) {
      // Событие завершилось
      _currentEvent!.onEnd();
      _completedEventIds.add(_currentEvent!.eventId);
      _currentEvent = null;
      _timeSinceLastEvent = 0;
    }

    // Перевіряємо чи потрібно розпочати нове событие
    if (_currentEvent == null) {
      _timeSinceLastEvent += dt;
      _tryTriggerNextEvent(game);
    }
  }

  /// Спроба розпочати наступне событие на основі часу.
  void _tryTriggerNextEvent(VoidRelayGame game) {
    final world = game.gameWorld;
    if (world == null) return;

    final triggerInterval = _effectiveTriggerInterval(world.sectorRiskLevel);
    if (_timeSinceLastEvent >= triggerInterval) {
      _triggerDeterministicEvent(game, world);
    }
  }

  void _triggerDeterministicEvent(VoidRelayGame game, GameWorld world) {
    final normalizedHeat = game.heatSystem?.getNormalizedHeat() ?? 0.0;
    final sectorElapsed = world.sectorElapsedSeconds;
    final sectorIndex = world.roomIndex;

    final candidates = <String>[];

    // Priority 1: door failure (найвищий ризик, блокує прогрес)
    final canTriggerDoorFailure =
        _timeSinceLastDoorFailure >= GameConfig.doorFailureCooldown &&
        (!GameConfig.doorFailureOncePerSector ||
            !_doorFailureTriggeredInSector) &&
        sectorIndex >= GameConfig.doorFailureMinSectorIndex;
    final shouldTriggerDoorFailure =
        normalizedHeat >= GameConfig.doorFailureHeatThreshold ||
        sectorElapsed >= GameConfig.doorFailureSectorTimeThreshold;
    if (canTriggerDoorFailure && shouldTriggerDoorFailure) {
      candidates.add('DOOR_FAILURE');
    }

    // Priority 2: system breakdown (окрема troubleshooting-ціль)
    final canTriggerSystemBreakdown =
        _timeSinceLastSystemBreakdown >= GameConfig.systemBreakdownCooldown;
    final shouldTriggerSystemBreakdown =
        normalizedHeat >= GameConfig.systemBreakdownHeatThreshold ||
        sectorElapsed >= GameConfig.systemBreakdownSectorTimeThreshold;
    if (canTriggerSystemBreakdown && shouldTriggerSystemBreakdown) {
      // Separate troubleshooting flow. Keep deterministic priority outside random room-events trio.
      _startEvent(SystemBreakdownEvent(game: game));
      _timeSinceLastSystemBreakdown = 0;
      return;
    }

    // Priority 3: toxic gas (heat pressure)
    final canTriggerToxicGas =
        _timeSinceLastToxicGas >= GameConfig.toxicGasCooldown;
    final shouldTriggerToxicGas =
        normalizedHeat >= GameConfig.toxicGasHeatThreshold ||
        sectorElapsed >= GameConfig.toxicGasSectorTimeThreshold;
    if (canTriggerToxicGas && shouldTriggerToxicGas) {
      candidates.add('TOXIC_GAS');
    }

    // Priority 4: blackout (базова ескалація)
    final canTriggerBlackout =
        _timeSinceLastBlackout >= GameConfig.blackoutCooldown;
    final shouldTriggerBlackout =
        normalizedHeat >= GameConfig.blackoutHeatThreshold ||
        sectorElapsed >= GameConfig.blackoutSectorTimeThreshold;
    if (canTriggerBlackout && shouldTriggerBlackout) {
      candidates.add('BLACKOUT');
    }

    if (candidates.isNotEmpty) {
      final selected = candidates[_random.nextInt(candidates.length)];
      switch (selected) {
        case 'DOOR_FAILURE':
          _startEvent(DoorFailureEvent(game: game));
          _timeSinceLastDoorFailure = 0;
          _doorFailureTriggeredInSector = true;
          return;
        case 'TOXIC_GAS':
          _startEvent(ToxicGasEvent(game: game));
          _timeSinceLastToxicGas = 0;
          return;
        case 'BLACKOUT':
        default:
          _startEvent(BlackoutEvent(game: game));
          _timeSinceLastBlackout = 0;
          return;
      }
    }

    // Fallback: щоб події не зупинялися у дуже «чистому» забігу.
    if (canTriggerBlackout &&
        _timeSinceLastEvent >= GameConfig.timeBetweenHazardEvents * 2) {
      _startEvent(BlackoutEvent(game: game));
      _timeSinceLastBlackout = 0;
    }
  }

  double _effectiveTriggerInterval(int sectorRiskLevel) {
    final reduced =
        GameConfig.timeBetweenHazardEvents -
        sectorRiskLevel * GameConfig.hazardIntervalReductionPerSector;
    return reduced < GameConfig.hazardMinInterval
        ? GameConfig.hazardMinInterval
        : reduced;
  }

  /// Розпочинає конкретне событие.
  void _startEvent(HazardEvent event) {
    if (_currentEvent != null) return; // Уже активне другое событие
    event.resetLifecycle();
    _currentEvent = event;
    _currentEvent!.onStart();

    final game = findGame();
    if (game is VoidRelayGame) {
      game.playSfx(SoundAssets.alert);
      final pulseCenter = game.gameWorld?.player.absolutePosition;
      if (pulseCenter != null) {
        game.spawnWarningPulse(pulseCenter);
      }
    }
  }

  /// Затримує наступне событие на N секунд.
  void delayNextEvent(double seconds) {
    _timeSinceLastEvent = 0;
    if (_currentEvent == null) {
      // Встановлюємо запас часу, щоб событие не запустилось відразу
      _timeSinceLastEvent = GameConfig.timeBetweenHazardEvents - seconds;
    }
  }

  /// Ручна активація события (для тестування).
  void triggerBlackout({double? duration}) {
    if (_currentEvent != null) return;
    final game = findGame();
    if (game is VoidRelayGame) {
      _startEvent(BlackoutEvent(duration: duration, game: game));
      _timeSinceLastBlackout = 0;
    }
  }

  /// Ручна активація toxic gas события (для тестування).
  void triggerToxicGas({double? duration}) {
    if (_currentEvent != null) return;
    final game = findGame();
    if (game is VoidRelayGame) {
      _startEvent(ToxicGasEvent(duration: duration, game: game));
      _timeSinceLastToxicGas = 0;
    }
  }

  /// Ручна активація door failure события (для тестування).
  void triggerDoorFailure() {
    if (_currentEvent != null) return;
    final game = findGame();
    if (game is VoidRelayGame) {
      _startEvent(DoorFailureEvent(game: game));
      _timeSinceLastDoorFailure = 0;
      _doorFailureTriggeredInSector = true;
    }
  }

  /// Ручна активація system breakdown события (для тестування).
  void triggerSystemBreakdown() {
    if (_currentEvent != null) return;
    final game = findGame();
    if (game is VoidRelayGame) {
      _startEvent(SystemBreakdownEvent(game: game));
      _timeSinceLastSystemBreakdown = 0;
    }
  }

  /// Завершити поточний door failure через repair-взаємодію.
  void resolveDoorFailure() {
    if (_currentEvent is DoorFailureEvent) {
      _currentEvent!.markResolved();
    }
  }

  /// Завершити system breakdown через troubleshooting-взаємодію.
  void resolveSystemBreakdown() {
    if (_currentEvent is SystemBreakdownEvent) {
      _currentEvent!.markResolved();
    }
  }

  void reset() {
    _currentEvent?.onEnd();
    _currentEvent = null;
    _timeSinceLastEvent = 0;
    _timeSinceLastBlackout = 9999;
    _timeSinceLastToxicGas = 9999;
    _timeSinceLastSystemBreakdown = 9999;
    _timeSinceLastDoorFailure = 9999;
    _lastProcessedSectorIndex = -1;
    _doorFailureTriggeredInSector = false;
    _completedEventIds.clear();
  }
}
