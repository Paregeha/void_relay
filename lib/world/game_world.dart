import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

import '../config/game_config.dart';
import '../core/debug/render_trace.dart';
import '../enemies/base_enemy.dart';
import '../enemies/basic_enemy/basic_enemy_component.dart';
import '../enemies/basic_enemy/enemy_config.dart';
import '../enemies/enemy_manager.dart';
import '../enemies/hover_drone/hover_drone.dart';
import '../enemies/sentry_turret/sentry_turret.dart';
import '../flame_game.dart';
import '../player/player_component.dart';
import '../systems/collision_handler.dart';
import '../systems/difficulty_profile.dart';
import '../systems/interaction_system.dart';
import '../systems/pickup_manager.dart';
import '../systems/save_state_models.dart';
import 'background/background_component.dart';
import 'interactive/cooling_station.dart';
import 'interactive/heart_pickup.dart';
import 'interactive/relay_gate.dart';
import 'interactive/repair_terminal.dart';
import 'platform/platform_component.dart';
import 'room/room.dart';
import 'room/room_builder.dart';
import 'room/room_types.dart';

enum EnemyDifficultyModifier {
  none,
  extraHp,
  extraDamage,
  fasterProjectiles,
  fasterMovement,
}

class GameWorld extends Component {
  // ── CLEANUP: enemies are controlled by global config flag
  static const bool enableEnemies = GameConfig.enableEnemies;

  static const int backgroundPriority = WorldVisualConfig.backgroundPriority;
  static const int perileVisualPriority = WorldVisualConfig.perilePriority;
  static const int terrainPriority = WorldVisualConfig.platformPriority;
  static const int enemyPriority = Enemy3Config.priority;
  static const int playerPriority = 100;
  static const int projectilePriority = Enemy3Config.bulletPriority;
  static const int effectsPriority = 300;
  static const int maxActiveCoolingPickups = 3;
  static const int maxActiveHeartPickups = 3;
  static const bool _debugPickupSpawnLogs = false;

  final int roomIndex;
  final double playerMaxHealthBonus;
  final DifficultyProfile difficultyProfile;

  late PlayerComponent player;
  late List<PlatformComponent> platforms;
  CollisionHandler? collisionHandler;
  EnemyManager? enemyManager;
  late InteractionSystem interactionSystem;
  PickupManager? pickupManager;
  late Set<RoomType> roomTypes;
  late Room _roomTemplate;
  Vector2 roomSize = Vector2.zero();

  /// Викликається при завершенні сектора.
  /// Причина: 'Relay reached'.
  void Function(String reason)? onSectorComplete;

  bool _sectorCompleted = false;
  double _sectorElapsedSeconds = 0;
  bool _didLogCrawlerReplacement = false;
  static const double _maxPhysicsDt = 1 / 30;
  final Map<String, EnemySpawn> _enemySpawnById = {};
  final Map<String, BaseEnemy> _enemiesById = {};
  final Set<String> _scoredEnemyIds = {};
  final Map<String, CoolingStation> _coolingStationsById = {};
  final Map<String, HeartPickup> _heartPickupsById = {};
  final Map<String, RepairTerminal> _repairTerminalsById = {};
  final Set<String> _collectedCoolingStationIds = {};
  final Set<String> _collectedHeartPickupIds = {};
  int _coolingSpawnSerial = 1000;
  int _heartSpawnSerial = 1000;
  RelayGate? _relayGate;
  bool _exitUnlocked = false;
  final math.Random _pickupRandom = math.Random();
  List<MapEntry<int, Rect>>? _cachedPickupSpawnPlatforms;

  GameWorld({
    this.roomIndex = 0,
    this.playerMaxHealthBonus = 0,
    this.difficultyProfile = DifficultyProfile.baseline,
  });

  @override
  Future<void> onLoad() async {
    // ── DEBUG: Log render order for diagnostic ────────────────────────────────
    if (PlayerComponent.debugRenderOrderLogs) {
      if (false) print('[RenderOrder] === GameWorld render order ===');
    }

    final room = RoomBuilder.buildRoom(
      roomIndex,
      difficultyProfile: difficultyProfile,
    );
    _roomTemplate = room;
    final profileLog =
        'DifficultyProfile('
        'level=${difficultyProfile.level}, '
        'enemyCount=${difficultyProfile.enemyCount}, '
        'speed=${difficultyProfile.enemySpeedMultiplier.toStringAsFixed(2)}, '
        'hp=${difficultyProfile.enemyHpMultiplier.toStringAsFixed(2)}, '
        'turret=${difficultyProfile.turretChance.toStringAsFixed(2)}, '
        'drone=${difficultyProfile.droneChance.toStringAsFixed(2)}, '
        'enemy3=${difficultyProfile.enemy3Chance.toStringAsFixed(2)}, '
        'cooling=${difficultyProfile.coolingPickupChance.toStringAsFixed(2)}, '
        'health=${difficultyProfile.healthPickupChance.toStringAsFixed(2)})';
    if (kDebugMode) {
      debugPrint('[DIFFICULTY] generated level with profile=$profileLog');
    }
    platforms = room.platforms;
    roomTypes = room.roomTypes;
    roomSize = room.roomSize.clone();

    add(
      BackgroundComponent(
        roomSize: roomSize,
        layerType: WorldVisualLayerType.back,
        parallaxSpeed: WorldVisualConfig.backgroundParallaxSpeed,
      )..priority = backgroundPriority,
    );
    add(
      BackgroundComponent(
        roomSize: roomSize,
        layerType: WorldVisualLayerType.perile,
      )..priority = perileVisualPriority,
    );
    if (PlayerComponent.debugRenderOrderLogs) {
      if (false) print('[RenderOrder] background priority=$backgroundPriority');
      if (false)
        print('[RenderOrder] perileVisual priority=$perileVisualPriority');
    }

    if (!PlayerComponent.debugHideLevelGeometry) {
      for (final platform in platforms) {
        platform.priority = terrainPriority;
        add(platform);
      }
      if (PlayerComponent.debugRenderOrderLogs) {
        if (false)
          print(
            '[RenderOrder] terrain priority=$terrainPriority (${platforms.length} platforms)',
          );
      }
    } else {
      if (PlayerComponent.debugRenderOrderLogs) {
        if (false)
          print(
            '[RenderOrder] terrain/platform render skipped (debugHideLevelGeometry=true)',
          );
      }
    }

    // Spawn player
    player = PlayerComponent();
    player.priority = PlayerComponent.debugRenderPlayerOnTop
        ? 9000 // Debug: render above most elements
        : playerPriority;
    if (PlayerComponent.debugRenderOrderLogs) {
      if (false)
        print(
          '[RenderOrder] player priority=${player.priority}${PlayerComponent.debugRenderPlayerOnTop ? " (DEBUG TOP)" : ""}',
        );
    }

    if (playerMaxHealthBonus > 0) {
      player.maxHealth += playerMaxHealthBonus;
      player.health = player.maxHealth;
    }
    player.position = room.playerSpawn.clone();
    add(player);
    await player.loaded;

    final groundBaselineY =
        roomSize.y *
        (WorldVisualConfig.groundBaselineY / GameConfig.defaultWorldHeight);
    final platformVisualHeight =
        WorldVisualConfig.platformVisualHeight *
        WorldVisualConfig.scaleYForRoom(roomSize);
    final platformY =
        groundBaselineY -
        platformVisualHeight +
        WorldVisualConfig.platformYOffset *
            WorldVisualConfig.scaleYForRoom(roomSize);
    final playerFeetY = player.position.y + player.size.y / 2;
    if (false)
      print(
        '[WorldVisual] groundBaselineY=${groundBaselineY.toStringAsFixed(1)} '
        'platformVisualHeight=${platformVisualHeight.toStringAsFixed(1)} '
        'platformY=${platformY.toStringAsFixed(1)} '
        'playerPosY=${player.position.y.toStringAsFixed(1)} '
        'playerFeetY=${playerFeetY.toStringAsFixed(1)}',
      );

    if (PlayerComponent.debugRenderOrderLogs) {
      // Debug: dump player component structure
      if (false) print('[RenderOrder] player children:');
      for (final child in player.children) {
        if (child is PositionComponent) {
          if (false)
            print(
              '[RenderOrder]   - ${child.runtimeType} '
              'priority=${child.priority} '
              'pos=${child.position} '
              'size=${child.size} '
              'anchor=${child.anchor}',
            );
        } else {
          if (false) print('[RenderOrder]   - ${child.runtimeType}');
        }
      }
    }

    _snapPlayerToSpawnSupport(room.playerSpawn);

    interactionSystem = InteractionSystem(player: player);
    add(interactionSystem);

    // Spawn enemies (CLEANUP: disabled when enableEnemies=false)
    if (enableEnemies) {
      enemyManager = EnemyManager(
        enemyRenderPriority: enemyPriority,
        projectileRenderPriority: projectilePriority,
      )..priority = enemyPriority;
      if (kDebugMode) {
        debugPrint('[DIFFICULTY] applied to EnemyManager');
      }
      add(enemyManager!);
      if (PlayerComponent.debugRenderOrderLogs) {
        if (false) print('[RenderOrder] enemyManager priority=$enemyPriority');
      }

      player.weaponManager.setEnemyManager(enemyManager!);

      for (final entry in room.enemySpawns.asMap().entries) {
        final index = entry.key;
        final spawn = entry.value;
        final enemyId = spawn.id ?? 'enemy_${index + 1}';
        _enemySpawnById[enemyId] = spawn;

        final enemy = _createEnemyForSpawn(spawn);
        if (enemy == null) {
          continue;
        }
        enemy.saveId = enemyId;
        enemy.saveType = spawn.type;
        _applyDifficultyToEnemy(enemy, enemyId: enemyId);
        enemy.priority = enemyPriority;
        enemyManager!.addEnemy(enemy);
        _enemiesById[enemyId] = enemy;
      }
      _spawnAdditionalEnemiesIfNeeded(room);
    } else {
      if (PlayerComponent.debugRenderOrderLogs) {
        if (false)
          print(
            '[GameWorld] enemies disabled (GameConfig.enableEnemies=false)',
          );
      }
    }

    if (!PlayerComponent.debugHideLevelGeometry) {
      // Spawn cooling stations
      for (final entry in room.coolingStationSpawns.asMap().entries) {
        if (_coolingStationsById.length >= 3) {
          break;
        }
        final index = entry.key;
        final pos = entry.value;
        if (!_isValidPickupSpawnPosition(pos)) {
          continue;
        }
        if (!_shouldSpawnCoolingPickup(index)) {
          continue;
        }
        _spawnCoolingPickup(position: pos, id: 'cooling_${index + 1}');
      }

      for (final entry in room.heartPickupSpawns.asMap().entries) {
        if (_heartPickupsById.length >= 3) {
          break;
        }
        final index = entry.key;
        final pos = entry.value;
        if (!_isValidPickupSpawnPosition(pos)) {
          continue;
        }
        if (!_shouldSpawnHealthPickup(index)) {
          continue;
        }
        _spawnHeartPickup(position: pos, id: 'heart_${index + 1}');
      }
      if (kDebugMode) {
        debugPrint('[DIFFICULTY] applied to PickupManager');
      }

      pickupManager = PickupManager(
        trySpawnCooling: trySpawnCoolingFromInterval,
        trySpawnHeart: trySpawnHeartFromInterval,
      );
      add(pickupManager!);
    }

    if (!PlayerComponent.debugHideLevelGeometry) {
      // Spawn repair terminals (used to resolve blocking failures)
      for (final entry in room.repairTerminalSpawns.asMap().entries) {
        final index = entry.key;
        final pos = entry.value;
        final terminalId = 'repair_terminal_${index + 1}';
        final terminal = RepairTerminal(
          position: pos,
          saveId: terminalId,
          onRepairCompleted: _onRepairTerminalCompleted,
          isDoorFailureActive: () {
            final game = findGame();
            return game is VoidRelayGame && game.isDoorFailureActive;
          },
        );
        _repairTerminalsById[terminalId] = terminal;
        terminal.priority = terrainPriority;
        add(terminal);
        interactionSystem.register(
          InteractionBinding(
            component: terminal,
            interactionRange: terminal.interactionRange,
            isEnabled: () {
              final game = findGame();
              return terminal.canStartRepair &&
                  game is VoidRelayGame &&
                  game.isDoorFailureActive;
            },
            onInteract: (_) {
              if (!terminal.canStartRepair) return;
              final game = findGame();
              if (game is VoidRelayGame && game.isDoorFailureActive) {
                game.playTerminalSound();
              }
              terminal.startRepair();
            },
          ),
        );
      }
    }

    // Spawn relay gate
    if (!PlayerComponent.debugHideLevelGeometry &&
        room.relayGatePosition != null) {
      _relayGate = RelayGate(
        position: room.relayGatePosition!,
        player: player,
        saveId: 'relay_gate_1',
        isExitUnlocked: _exitUnlocked,
        onReached: () => _completeSector('Relay reached'),
      )..priority = terrainPriority;
      add(_relayGate!);
    }

    collisionHandler = CollisionHandler(
      player: player,
      platforms: platforms,
      enemies: enemyManager?.enemies ?? const [],
      enemyProjectiles: enemyManager?.projectiles ?? const [],
    );

    if (PlayerComponent.debugRenderOrderLogs) {
      if (false) print('[RenderOrder] === GameWorld setup complete ===');
      _debugDumpWorldRenderOrder();
    }
  }

  @override
  void render(Canvas canvas) {
    if (PlayerComponent.debugTraceRenderSequence) {
      if (false)
        RenderTrace.log('GameWorld.render START (before super.render)');
    }
    super.render(canvas);
    if (PlayerComponent.debugTraceRenderSequence) {
      if (false) RenderTrace.log('GameWorld.render END (after super.render)');
    }
  }

  @override
  void update(double dt) {
    final safeDt = dt.clamp(0.0, _maxPhysicsDt).toDouble();
    super.update(safeDt);
    final game = findGame();
    if (game is VoidRelayGame && game.isGameplayInputBlocked) {
      return;
    }
    if (!_sectorCompleted) {
      _sectorElapsedSeconds += safeDt;
    }
    collisionHandler?.update(safeDt);
    _updateEnemyKillScore();
    _checkAllEnemiesKilled();
  }

  void _updateEnemyKillScore() {
    final game = findGame();
    if (game is! VoidRelayGame) return;

    for (final entry in _enemiesById.entries) {
      final enemyId = entry.key;
      if (_scoredEnemyIds.contains(enemyId)) continue;

      final enemy = entry.value;
      final defeated = enemy.health <= 0 || enemy.isDead || !enemy.isMounted;
      if (!defeated) continue;

      _scoredEnemyIds.add(enemyId);
      game.onEnemyKilled(enemyType: enemy.saveType);
    }
  }

  void _checkAllEnemiesKilled() {
    if (!enableEnemies) return;
    if (_exitUnlocked) return;
    final manager = enemyManager;
    if (manager == null || manager.enemies.isEmpty) return;

    final allDead = manager.enemies.every((e) => e.health <= 0);
    if (!allDead) return;

    if (kDebugMode) {
      debugPrint('[LEVEL_EXIT] enemies defeated: opening door');
    }
    _openExitDoor();
  }

  void _openExitDoor() {
    if (_exitUnlocked) return;
    _exitUnlocked = true;
    _relayGate?.unlockDoor();

    final game = findGame();
    if (game is VoidRelayGame) {
      game.notifyLevelExitUnlocked();
    }
  }

  void _completeSector(String reason) {
    if (_sectorCompleted) return;

    final game = findGame();
    if (game is VoidRelayGame && game.isDoorFailureActive) {
      // Door failure блокує прогрес сектора, поки не завершено repair.
      return;
    }

    _sectorCompleted = true;
    onSectorComplete?.call(reason);
  }

  void _onRepairTerminalCompleted() {
    final game = findGame();
    if (game is VoidRelayGame && game.isDoorFailureActive) {
      game.resolveDoorFailure();
    }
  }

  bool get hasAliveHostiles {
    // Safe: return false if enemies disabled or manager empty
    if (!enableEnemies) return false;
    try {
      final manager = enemyManager;
      if (manager == null || manager.enemies.isEmpty) return false;
      return manager.enemies.any((e) => e.health > 0);
    } catch (e) {
      // During initialization phase, enemyManager may not be fully ready
      return false;
    }
  }

  int get aliveHostilesCount {
    // Safe: return 0 if enemies disabled
    if (!enableEnemies) return 0;
    try {
      final manager = enemyManager;
      if (manager == null) return 0;
      return manager.enemies.where((e) => e.health > 0).length;
    } catch (e) {
      // During initialization phase, enemyManager may not be fully ready
      return 0;
    }
  }

  bool canUseLevelExit() {
    final alive = aliveHostilesCount;
    if (alive > 0) {
      if (kDebugMode) {
        debugPrint('[LEVEL_EXIT] blocked: enemiesAlive=$alive');
      }
      return false;
    }
    if (kDebugMode) {
      debugPrint('[LEVEL_EXIT] allowed: all enemies defeated');
    }
    return true;
  }

  bool get isExitUnlocked => _exitUnlocked;

  bool hasRoomType(RoomType type) => roomTypes.contains(type);

  double get lowestPlatformBottom {
    if (platforms.isEmpty) return roomSize.y;
    double maxBottom = 0;
    for (final platform in platforms) {
      final rect = platform.toRect();
      if (rect.bottom > maxBottom) {
        maxBottom = rect.bottom;
      }
    }
    return maxBottom;
  }

  double get sectorElapsedSeconds => _sectorElapsedSeconds;

  int get sectorRiskLevel => roomIndex;

  void _snapPlayerToSpawnSupport(Vector2 desiredSpawn) {
    double? closestTop;
    var closestDistance = double.infinity;

    for (final platform in platforms) {
      final rect = platform.toRect();
      // Only use walkable horizontal platforms for spawn support.
      if (rect.width <= rect.height) continue;
      if (desiredSpawn.x < rect.left || desiredSpawn.x > rect.right) continue;

      final distance = (rect.top - desiredSpawn.y).abs();
      if (distance < closestDistance) {
        closestDistance = distance;
        closestTop = rect.top;
      }
    }

    if (closestTop == null) {
      player.position = desiredSpawn.clone();
      return;
    }

    player.position = Vector2(desiredSpawn.x, closestTop - player.size.y / 2);
    player.velocity.setZero();
    player.land();
  }

  void snapPlayerToGroundNearCurrentPosition({double maxDistance = 84}) {
    double? closestTop;
    var closestDistance = maxDistance;
    final x = player.position.x;
    final desiredBottom = player.toRect().bottom;

    for (final platform in platforms) {
      final rect = platform.toRect();
      if (rect.width <= rect.height) continue;
      if (x < rect.left || x > rect.right) continue;

      final distance = (rect.top - desiredBottom).abs();
      if (distance < closestDistance) {
        closestDistance = distance;
        closestTop = rect.top;
      }
    }

    if (closestTop == null) {
      return;
    }

    player.position.y = closestTop - player.size.y / 2;
    player.velocity.setZero();
    player.land();
  }

  BaseEnemy? _createEnemyForSpawn(EnemySpawn spawn) {
    switch (spawn.type) {
      case 'crawler':
        if (!_didLogCrawlerReplacement) {
          _didLogCrawlerReplacement = true;
          if (false)
            print(
              '[GameWorld] crawler spawning disabled: replaced with basic_enemy',
            );
        }
        final basic = BasicEnemyComponent();
        basic.player = player;
        final snappedBaselineY = _resolveCrawlerBaselineY(
          spawn.position.x,
          spawn.position.y,
        );
        basic.position = Vector2(spawn.position.x, snappedBaselineY);
        return basic;
      case 'hover_drone':
        final drone = HoverDrone();
        drone.player = player;
        drone.platforms = platforms;
        drone.floorY = roomSize.y;
        drone.position = spawn.position.clone();
        return drone;
      case 'sentry_turret':
        final turret = SentryTurret();
        turret.player = player;
        turret.position = spawn.position.clone()
          ..y += GameConfig.sentryTurretGroundYOffset;
        return turret;
      case 'basic_enemy':
      case 'enemy3':
        final basic = BasicEnemyComponent();
        basic.player = player;
        basic.platforms = platforms;
        final snappedBaselineY = _resolveCrawlerBaselineY(
          spawn.position.x,
          spawn.position.y,
        );
        basic.spawnPlatformTopY = snappedBaselineY;
        basic.position = Vector2(spawn.position.x, spawn.position.y);
        enemy3Log(
          'spawn platformTopY=$snappedBaselineY '
          'enemyY=${basic.position.y} '
          'anchor=${basic.anchor} '
          'size=${basic.size}',
        );
        return basic;
      default:
        return null;
    }
  }

  void _applyDifficultyToEnemy(BaseEnemy enemy, {required String enemyId}) {
    enemy.difficultyHpMultiplier = difficultyProfile.enemyHpMultiplier;
    enemy.difficultySpeedMultiplier = difficultyProfile.enemySpeedMultiplier;
    enemy.difficultyDamageMultiplier = difficultyProfile.enemyDamageMultiplier;
    enemy.difficultyProjectileSpeedMultiplier = 1.0;

    final modifier = _pickEnemyModifier(enemyId);
    if (kDebugMode) {
      debugPrint(
        '[DIFFICULTY] enemy modifier enemyType=${enemy.saveType} modifier=${modifier.name}',
      );
    }
    _applyEnemyModifier(enemy: enemy, modifier: modifier);

    enemy.maxHealth = enemy.maxHealth * enemy.difficultyHpMultiplier;
    enemy.health = enemy.maxHealth;

    if (kDebugMode) {
      debugPrint(
        '[DIFFICULTY] applied hpMultiplier=${enemy.difficultyHpMultiplier.toStringAsFixed(2)}',
      );
      debugPrint(
        '[DIFFICULTY] applied damageMultiplier=${enemy.difficultyDamageMultiplier.toStringAsFixed(2)}',
      );
      debugPrint(
        '[DIFFICULTY] applied projectileSpeedMultiplier=${enemy.difficultyProjectileSpeedMultiplier.toStringAsFixed(2)}',
      );
      debugPrint(
        '[DIFFICULTY] applied speedMultiplier=${enemy.difficultySpeedMultiplier.toStringAsFixed(2)}',
      );
    }
  }

  EnemyDifficultyModifier _pickEnemyModifier(String enemyId) {
    final level = difficultyProfile.level;
    if (level <= 1) return EnemyDifficultyModifier.none;

    final modifierChance = _modifierChanceForLevel(level);
    final chanceRoll = _stableRoll(enemyId.hashCode, 0.17);
    if (chanceRoll > modifierChance) {
      return EnemyDifficultyModifier.none;
    }

    final pickRoll = _stableRoll(enemyId.hashCode, 0.53);
    if (pickRoll < 0.25) return EnemyDifficultyModifier.extraHp;
    if (pickRoll < 0.50) return EnemyDifficultyModifier.extraDamage;
    if (pickRoll < 0.75) return EnemyDifficultyModifier.fasterProjectiles;
    return EnemyDifficultyModifier.fasterMovement;
  }

  double _modifierChanceForLevel(int level) {
    final value = 0.08 + (level - 1) * 0.09;
    return value.clamp(0.08, 0.72);
  }

  void _applyEnemyModifier({
    required BaseEnemy enemy,
    required EnemyDifficultyModifier modifier,
  }) {
    switch (modifier) {
      case EnemyDifficultyModifier.none:
        return;
      case EnemyDifficultyModifier.extraHp:
        enemy.difficultyHpMultiplier = (enemy.difficultyHpMultiplier + 0.22)
            .clamp(1.0, 3.8);
        return;
      case EnemyDifficultyModifier.extraDamage:
        enemy.difficultyDamageMultiplier =
            (enemy.difficultyDamageMultiplier + 0.18).clamp(1.0, 3.0);
        return;
      case EnemyDifficultyModifier.fasterProjectiles:
        enemy.difficultyProjectileSpeedMultiplier =
            (enemy.difficultyProjectileSpeedMultiplier + 0.25).clamp(1.0, 1.9);
        return;
      case EnemyDifficultyModifier.fasterMovement:
        enemy.difficultySpeedMultiplier =
            (enemy.difficultySpeedMultiplier + 0.16).clamp(1.0, 2.2);
        return;
    }
  }

  double _stableRoll(int seed, double salt) {
    final value =
        seed * 0.137 + difficultyProfile.level * salt + roomIndex * 0.11;
    final fraction = value - value.floorToDouble();
    return fraction.clamp(0.0, 1.0);
  }

  void _spawnAdditionalEnemiesIfNeeded(Room room) {
    final manager = enemyManager;
    if (manager == null) return;

    final currentCount = manager.enemies.length;
    final additional = difficultyProfile.enemyCount - currentCount;
    if (additional <= 0) return;

    for (var i = 0; i < additional; i++) {
      final type = _chooseExtraEnemyType(i);
      final spawn = _buildExtraEnemySpawn(room: room, index: i, type: type);
      final enemy = _createEnemyForSpawn(spawn);
      if (enemy == null) continue;

      final enemyId = 'enemy_extra_${currentCount + i + 1}';
      _enemySpawnById[enemyId] = spawn;
      enemy.saveId = enemyId;
      enemy.saveType = spawn.type;
      _applyDifficultyToEnemy(enemy, enemyId: enemyId);
      enemy.priority = enemyPriority;
      manager.addEnemy(enemy);
      _enemiesById[enemyId] = enemy;
    }
  }

  String _chooseExtraEnemyType(int index) {
    final score = _normalizedDeterministicValue(index: index, salt: 0.31);
    final turretWeight = difficultyProfile.turretChance;
    final droneWeight = difficultyProfile.droneChance;
    final enemy3Weight = difficultyProfile.enemy3Chance;
    final totalWeight = turretWeight + droneWeight + enemy3Weight;
    if (totalWeight <= 0.0001) {
      return 'enemy3';
    }

    final turretEdge = turretWeight / totalWeight;
    final droneEdge = turretEdge + (droneWeight / totalWeight);

    if (score <= turretEdge) return 'sentry_turret';
    if (score <= droneEdge) return 'hover_drone';
    return 'enemy3';
  }

  EnemySpawn _buildExtraEnemySpawn({
    required Room room,
    required int index,
    required String type,
  }) {
    final spread = room.roomSize.x / (difficultyProfile.enemyCount + 1);
    final x = (spread * (index + 1)).clamp(80.0, room.roomSize.x - 80.0);
    final fallbackY = room.roomSize.y * 0.70;

    switch (type) {
      case 'hover_drone':
        return EnemySpawn(Vector2(x, room.roomSize.y * 0.52), type: type);
      case 'sentry_turret':
        final top = _resolveCrawlerBaselineY(x, fallbackY);
        return EnemySpawn(Vector2(x, top), type: type);
      case 'enemy3':
      default:
        final top = _resolveCrawlerBaselineY(x, fallbackY);
        return EnemySpawn(Vector2(x, top), type: 'enemy3');
    }
  }

  bool _shouldSpawnCoolingPickup(int index) {
    final score = _normalizedDeterministicValue(index: index, salt: 0.77);
    return score <= difficultyProfile.coolingPickupChance;
  }

  bool _shouldSpawnHealthPickup(int index) {
    final score = _normalizedDeterministicValue(index: index, salt: 0.93);
    return score <= difficultyProfile.healthPickupChance;
  }

  bool trySpawnCoolingFromInterval() {
    _pruneInactivePickups();
    final activeCount = activeCoolingCount;
    if (kDebugMode && _debugPickupSpawnLogs) {
      debugPrint('[PICKUP_SPAWN] attempt type=cooling');
    }
    if (kDebugMode && _debugPickupSpawnLogs) {
      debugPrint(
        '[PICKUP_SPAWN] cooling count=$activeCount max=$maxActiveCoolingPickups',
      );
    }
    if (activeCount >= maxActiveCoolingPickups) {
      if (kDebugMode && _debugPickupSpawnLogs) {
        debugPrint(
          '[PICKUP_SPAWN] skipped cooling: max active reached count=$activeCount',
        );
      }
      return false;
    }

    final candidate = _pickRandomSpawnCandidate(
      type: 'cooling',
      minDistanceToPlayer: 180,
      minDistanceToRelay: 140,
      avoidEnemiesRadius: 84,
      maxAttempts: 16,
    );
    if (candidate == null) {
      return false;
    }

    _coolingSpawnSerial++;
    _spawnCoolingPickup(
      position: candidate,
      id: 'cooling_dyn_$_coolingSpawnSerial',
    );
    return true;
  }

  bool trySpawnHeartFromInterval() {
    _pruneInactivePickups();
    final activeCount = activeHeartCount;
    if (kDebugMode && _debugPickupSpawnLogs) {
      debugPrint('[PICKUP_SPAWN] attempt type=heart');
    }
    if (kDebugMode && _debugPickupSpawnLogs) {
      debugPrint(
        '[PICKUP_SPAWN] heart count=$activeCount max=$maxActiveHeartPickups',
      );
    }
    if (activeCount >= maxActiveHeartPickups) {
      if (kDebugMode && _debugPickupSpawnLogs) {
        debugPrint(
          '[PICKUP_SPAWN] skipped heart: max active reached count=$activeCount',
        );
      }
      return false;
    }

    final candidate = _pickRandomSpawnCandidate(
      type: 'heart',
      minDistanceToPlayer: 210,
      minDistanceToRelay: 160,
      avoidEnemiesRadius: 90,
      maxAttempts: 16,
    );
    if (candidate == null) {
      return false;
    }

    _heartSpawnSerial++;
    _spawnHeartPickup(position: candidate, id: 'heart_dyn_$_heartSpawnSerial');
    return true;
  }

  Vector2? _pickRandomSpawnCandidate({
    required String type,
    required double minDistanceToPlayer,
    required double minDistanceToRelay,
    required double avoidEnemiesRadius,
    required int maxAttempts,
  }) {
    final candidatePlatforms = _pickupSpawnPlatforms();
    if (candidatePlatforms.isEmpty) {
      _logPickupRejected('no_valid_platforms');
      return null;
    }

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final selected =
          candidatePlatforms[_pickupRandom.nextInt(candidatePlatforms.length)];
      final platformId = selected.key;
      final rect = selected.value;

      if (kDebugMode && _debugPickupSpawnLogs) {
        debugPrint(
          '[PICKUP_SPAWN] selected platform id=$platformId '
          'rect=(${rect.left.toStringAsFixed(1)},${rect.top.toStringAsFixed(1)},${rect.width.toStringAsFixed(1)}x${rect.height.toStringAsFixed(1)})',
        );
      }

      final minX = rect.left + 14;
      final maxX = rect.right - 14;
      if (maxX <= minX) {
        _logPickupRejected('platform_too_narrow');
        continue;
      }

      final x = minX + _pickupRandom.nextDouble() * (maxX - minX);
      final pos = Vector2(x, rect.top);

      if (kDebugMode && _debugPickupSpawnLogs) {
        debugPrint(
          '[PICKUP_SPAWN] random position=(${pos.x.toStringAsFixed(1)},${pos.y.toStringAsFixed(1)}) type=$type',
        );
      }

      if (!_isValidPickupSpawnPosition(pos)) {
        _logPickupRejected('invalid_support_or_bounds');
        continue;
      }
      if (_isPickupPointOccupied(pos)) {
        _logPickupRejected('overlap_other_pickup');
        continue;
      }
      if (_isWithinDistanceSq(player.position, pos, minDistanceToPlayer)) {
        _logPickupRejected('too_close_to_player');
        continue;
      }

      final relay = _relayGate;
      if (relay != null &&
          _isWithinDistanceSq(relay.position, pos, minDistanceToRelay)) {
        _logPickupRejected('too_close_to_exit');
        continue;
      }

      final enemies = enemyManager?.enemies ?? const <BaseEnemy>[];
      var tooCloseToEnemy = false;
      for (final e in enemies) {
        if (!e.isMounted || e.health <= 0) continue;
        if (_isWithinDistanceSq(e.position, pos, avoidEnemiesRadius)) {
          tooCloseToEnemy = true;
          break;
        }
      }
      if (tooCloseToEnemy) {
        _logPickupRejected('too_close_to_enemy');
        continue;
      }

      if (_isDirectlyUnderEnemy(pos)) {
        _logPickupRejected('directly_under_enemy');
        continue;
      }

      return pos;
    }

    _logPickupRejected('max_attempts_exceeded');
    return null;
  }

  List<MapEntry<int, Rect>> _pickupSpawnPlatforms() {
    final cached = _cachedPickupSpawnPlatforms;
    if (cached != null) {
      return cached;
    }

    final result = <MapEntry<int, Rect>>[];
    for (final entry in platforms.asMap().entries) {
      final rect = entry.value.toRect();
      final isHorizontal = rect.width > rect.height;
      if (!isHorizontal) {
        continue;
      }

      // Ignore hidden ceiling strip and tiny ledges for safer random placement.
      final isVeryWide = rect.width >= GameConfig.defaultWorldWidth * 0.6;
      final isCeilingBoundary = isVeryWide && rect.top <= 4.0;
      if (isCeilingBoundary || rect.width < 48) {
        continue;
      }

      result.add(MapEntry(entry.key, rect));
    }
    _cachedPickupSpawnPlatforms = result;
    return result;
  }

  bool _isDirectlyUnderEnemy(Vector2 pos) {
    final enemies = enemyManager?.enemies ?? const <BaseEnemy>[];
    for (final enemy in enemies) {
      if (!enemy.isMounted || enemy.health <= 0) {
        continue;
      }
      final rect = enemy.toRect();
      final horizontalOverlap =
          pos.x >= rect.left - 10 && pos.x <= rect.right + 10;
      final enemyAbove = rect.bottom <= pos.y && (pos.y - rect.bottom) <= 90;
      if (horizontalOverlap && enemyAbove) {
        return true;
      }
    }
    return false;
  }

  void _logPickupRejected(String reason) {
    if (kDebugMode && _debugPickupSpawnLogs) {
      debugPrint('[PICKUP_SPAWN] rejected position reason=$reason');
    }
  }

  bool _isPickupPointOccupied(Vector2 point) {
    for (final pickup in _coolingStationsById.values) {
      if (pickup.isCollected || !pickup.isMounted) continue;
      if (_isWithinDistanceSq(pickup.position, point, 18)) return true;
    }
    for (final pickup in _heartPickupsById.values) {
      if (pickup.isCollected || !pickup.isMounted) continue;
      if (_isWithinDistanceSq(pickup.position, point, 18)) return true;
    }
    return false;
  }

  void _spawnCoolingPickup({required Vector2 position, required String id}) {
    _pruneInactivePickups();
    if (activeCoolingCount >= maxActiveCoolingPickups) {
      if (kDebugMode) {
        debugPrint(
          '[PICKUP_SPAWN] skipped cooling: max active reached count=$maxActiveCoolingPickups',
        );
      }
      return;
    }
    final station = CoolingStation(
      position: position,
      player: player,
      saveId: id,
      onCollected: (collectedId) {
        _collectedCoolingStationIds.add(collectedId);
        _coolingStationsById.remove(collectedId);
      },
    )..priority = terrainPriority;
    _coolingStationsById[id] = station;
    add(station);
    if (kDebugMode && _debugPickupSpawnLogs) {
      debugPrint(
        '[PICKUP_SPAWN] spawned cooling at=(${position.x.toStringAsFixed(1)},${position.y.toStringAsFixed(1)})',
      );
    }
  }

  void _spawnHeartPickup({required Vector2 position, required String id}) {
    _pruneInactivePickups();
    if (activeHeartCount >= maxActiveHeartPickups) {
      if (kDebugMode) {
        debugPrint(
          '[PICKUP_SPAWN] skipped heart: max active reached count=$maxActiveHeartPickups',
        );
      }
      return;
    }
    final heart = HeartPickup(
      position: position,
      player: player,
      saveId: id,
      onCollected: (collectedId) {
        _collectedHeartPickupIds.add(collectedId);
        _heartPickupsById.remove(collectedId);
      },
    )..priority = terrainPriority;
    _heartPickupsById[id] = heart;
    add(heart);
    if (kDebugMode && _debugPickupSpawnLogs) {
      debugPrint(
        '[PICKUP_SPAWN] spawned heart at=(${position.x.toStringAsFixed(1)},${position.y.toStringAsFixed(1)})',
      );
    }
  }

  int get activeCoolingCount {
    var count = 0;
    for (final pickup in _coolingStationsById.values) {
      if (!pickup.isCollected && pickup.isMounted) {
        count++;
      }
    }
    return count;
  }

  int get activeHeartCount {
    var count = 0;
    for (final pickup in _heartPickupsById.values) {
      if (!pickup.isCollected && pickup.isMounted) {
        count++;
      }
    }
    return count;
  }

  bool _isWithinDistanceSq(Vector2 a, Vector2 b, double distance) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    final limit = distance * distance;
    return dx * dx + dy * dy < limit;
  }

  void _pruneInactivePickups() {
    _coolingStationsById.removeWhere((_, p) => p.isCollected || !p.isMounted);
    _heartPickupsById.removeWhere((_, p) => p.isCollected || !p.isMounted);
  }

  bool _isValidPickupSpawnPosition(Vector2 position) {
    if (position.x < 24 || position.x > roomSize.x - 24) return false;
    if (position.y < 8 || position.y > roomSize.y) return false;

    final supportRect = _resolveSpawnSupportPlatformRect(
      position.x,
      position.y,
    );
    if (supportRect == null) return false;

    final nearTop = (position.y - supportRect.top).abs() <= 2.0;
    if (!nearTop) return false;

    final farEnoughFromWalls =
        position.x > supportRect.left + 8 && position.x < supportRect.right - 8;
    return farEnoughFromWalls;
  }

  double _normalizedDeterministicValue({
    required int index,
    required double salt,
  }) {
    final value =
        (index + 1) * 0.173 +
        roomIndex * 0.197 +
        difficultyProfile.level * salt;
    final fraction = value - value.floorToDouble();
    return fraction.clamp(0.0, 1.0);
  }

  double _resolveCrawlerBaselineY(double x, double fallbackY) {
    final supportRect = _resolveSpawnSupportPlatformRect(x, fallbackY);
    return supportRect?.top ?? fallbackY;
  }

  Rect? _resolveSpawnSupportPlatformRect(double x, double fallbackY) {
    double? bestTop;
    Rect? bestRect;

    for (final platform in platforms) {
      final rect = platform.toRect();
      final isHorizontal = rect.width > rect.height;
      if (!isHorizontal) continue;

      // Ignore hidden ceiling boundary strip.
      final isVeryWide = rect.width >= GameConfig.defaultWorldWidth * 0.6;
      final isCeilingBoundary = isVeryWide && rect.top <= 4.0;
      if (isCeilingBoundary) continue;

      if (x < rect.left || x > rect.right) continue;

      // Select nearest platform below (or at) enemy spawn feet.
      final isBelow = rect.top >= fallbackY;
      if (Enemy3Config.debugLogs) {
        enemy3Log(
          'platform candidate topY=${rect.top} '
          'left=${rect.left} right=${rect.right} '
          'overlapsX=true isBelow=$isBelow '
          'isCeilingBoundary=$isCeilingBoundary',
        );
      }
      if (!isBelow) continue;

      if (bestTop == null || rect.top < bestTop) {
        bestTop = rect.top;
        bestRect = rect;
      }
    }

    if (Enemy3Config.debugLogs) {
      enemy3Log('selected platformTopY=${bestRect?.top} enemyY=$fallbackY');
    }

    return bestRect;
  }

  void _debugDumpWorldRenderOrder() {
    if (false)
      print('[RenderOrder] component=Background priority=$backgroundPriority');
    if (false)
      print(
        '[RenderOrder] component=PerileVisual priority=$perileVisualPriority',
      );
    if (false)
      print(
        '[RenderOrder] component=Terrain/Platforms priority=$terrainPriority',
      );
    if (false)
      print('[RenderOrder] component=Ground priority=$terrainPriority');
    if (false)
      print(
        '[RenderOrder] component=PlayerComponent priority=${player.priority}',
      );

    final renderer = player.children.whereType<PositionComponent?>().firstWhere(
      (c) => c?.runtimeType.toString() == '_PlayerAnimationRenderer',
      orElse: () => null,
    );
    if (false)
      print(
        '[RenderOrder] component=_PlayerAnimationRenderer priority=${renderer?.priority ?? "not-found"}',
      );
    if (false)
      print('[RenderOrder] component=Effects priority=$effectsPriority');
    if (false)
      print(
        '[RenderOrder] component=HUD overlay=UiManager.hudOverlay (Flutter overlay)',
      );
  }

  bool cycleFirstDroneAnimationDebug() {
    final manager = enemyManager;
    if (manager == null) {
      return false;
    }

    for (final enemy in manager.enemies) {
      if (enemy is HoverDrone && enemy.isMounted && enemy.health > 0) {
        enemy.cycleDebugAnimationState();
        return true;
      }
    }

    return false;
  }

  bool setFirstDroneAnimationDebugState(DroneAnimationState state) {
    final manager = enemyManager;
    if (manager == null) {
      return false;
    }

    for (final enemy in manager.enemies) {
      if (enemy is HoverDrone && enemy.isMounted && enemy.health > 0) {
        enemy.setDebugAnimationState(state);
        return true;
      }
    }

    return false;
  }

  bool stepFirstDroneFrameNext() {
    final manager = enemyManager;
    if (manager == null) {
      return false;
    }

    for (final enemy in manager.enemies) {
      if (enemy is HoverDrone && enemy.isMounted && enemy.health > 0) {
        enemy.stepDebugFrameNext();
        return true;
      }
    }

    return false;
  }

  bool stepFirstDroneFramePrevious() {
    final manager = enemyManager;
    if (manager == null) {
      return false;
    }

    for (final enemy in manager.enemies) {
      if (enemy is HoverDrone && enemy.isMounted && enemy.health > 0) {
        enemy.stepDebugFramePrevious();
        return true;
      }
    }

    return false;
  }

  WorldStateSaveData captureSaveState() {
    final enemyEntries = <EnemySaveData>[];
    for (final entry in _enemySpawnById.entries) {
      final enemyId = entry.key;
      final spawn = entry.value;
      final enemy = _enemiesById[enemyId];
      final isAlive = enemy != null && enemy.isMounted && enemy.health > 0;
      final x = enemy?.position.x ?? spawn.position.x;
      final y = enemy?.position.y ?? spawn.position.y;
      final hp = enemy?.health.round() ?? 0;
      final facingRight = enemy?.saveFacingRight ?? true;
      final state = enemy?.saveState ?? (isAlive ? 'alive' : 'dead');
      final feetX = enemy is Enemy3Component ? enemy.position.x : null;
      final feetY = enemy is Enemy3Component ? enemy.position.y : null;
      final velocityX = enemy?.velocity.x;
      final velocityY = enemy?.velocity.y;
      final isGrounded = enemy is Enemy3Component
          ? enemy.isGroundedForSave
          : null;
      enemyEntries.add(
        EnemySaveData(
          id: enemyId,
          type: spawn.type,
          x: x,
          y: y,
          hp: hp,
          isAlive: isAlive,
          facingRight: facingRight,
          state: state,
          feetX: feetX,
          feetY: feetY,
          velocityX: velocityX,
          velocityY: velocityY,
          isGrounded: isGrounded,
        ),
      );
    }

    final coolingEntries = <CoolingStationSaveData>[];
    final coolingIds = <String>{
      ..._coolingStationsById.keys,
      ..._collectedCoolingStationIds,
    }.toList()..sort();
    for (final id in coolingIds) {
      final isCollected =
          _collectedCoolingStationIds.contains(id) ||
          !_coolingStationsById.containsKey(id);
      coolingEntries.add(
        CoolingStationSaveData(id: id, isCollected: isCollected),
      );
    }

    final heartEntries = <HeartPickupSaveData>[];
    final heartIds = <String>{
      ..._heartPickupsById.keys,
      ..._collectedHeartPickupIds,
    }.toList()..sort();
    for (final id in heartIds) {
      final isCollected =
          _collectedHeartPickupIds.contains(id) ||
          !_heartPickupsById.containsKey(id);
      heartEntries.add(HeartPickupSaveData(id: id, isCollected: isCollected));
    }

    final repairEntries = _repairTerminalsById.values
        .map(
          (terminal) => RepairTerminalSaveData(
            id: terminal.saveId,
            isRepairing: terminal.isRepairing,
            isRepaired: terminal.isRepaired,
            repairProgress: terminal.repairProgress,
            completedTimer: terminal.completedTimer,
          ),
        )
        .toList(growable: false);

    final gate = _relayGate;
    RelayGateSaveData? relayGateData;
    if (gate != null) {
      relayGateData = RelayGateSaveData(
        doorState: gate.currentDoorState.name,
        progress: gate.doorProgress,
        triggered: gate.isTriggered,
        wasCloseEventActive: gate.wasCloseEventActive,
      );
    }

    return WorldStateSaveData(
      enemies: enemyEntries,
      coolingStations: coolingEntries,
      heartPickups: heartEntries,
      repairTerminals: repairEntries,
      relayGate: relayGateData,
    );
  }

  Future<void> applySaveState(WorldStateSaveData state) async {
    final enemiesById = {for (final enemy in state.enemies) enemy.id: enemy};

    for (final entry in _enemySpawnById.entries) {
      final id = entry.key;
      final existing = _enemiesById[id];
      final enemySave = enemiesById[id];
      if (existing == null || enemySave == null) {
        continue;
      }

      await existing.loaded;

      if (!enemySave.isAlive || enemySave.hp <= 0) {
        existing.die();
        continue;
      }

      if (existing is Enemy3Component) {
        existing.restoreGroundSavePose(
          feetX: enemySave.feetX ?? enemySave.x,
          feetY: enemySave.feetY ?? enemySave.y,
          facingRight: enemySave.facingRight,
          isGrounded: enemySave.isGrounded ?? true,
          velocityX: enemySave.velocityX ?? 0,
          velocityY: enemySave.velocityY ?? 0,
        );
      } else {
        existing.position.setValues(enemySave.x, enemySave.y);
        existing.applySaveFacingRight(enemySave.facingRight);
      }
      existing.health = enemySave.hp.toDouble().clamp(0.0, existing.maxHealth);
    }

    final coolingById = {
      for (final station in state.coolingStations) station.id: station,
    };
    for (final entry in coolingById.entries) {
      if (!entry.value.isCollected) {
        continue;
      }
      _collectedCoolingStationIds.add(entry.key);
      final station = _coolingStationsById.remove(entry.key);
      station?.removeFromParent();
    }

    final heartsById = {
      for (final heart in state.heartPickups) heart.id: heart,
    };
    for (final entry in heartsById.entries) {
      if (!entry.value.isCollected) {
        continue;
      }
      _collectedHeartPickupIds.add(entry.key);
      final heart = _heartPickupsById.remove(entry.key);
      heart?.removeFromParent();
    }

    final terminalsById = {
      for (final terminal in state.repairTerminals) terminal.id: terminal,
    };
    for (final entry in _repairTerminalsById.entries) {
      final terminalSave = terminalsById[entry.key];
      if (terminalSave == null) {
        continue;
      }
      entry.value.restoreState(
        isRepairing: terminalSave.isRepairing,
        isRepaired: terminalSave.isRepaired,
        repairProgress: terminalSave.repairProgress,
        completedTimer: terminalSave.completedTimer,
      );
    }

    final gateSave = state.relayGate;
    final gate = _relayGate;
    if (gateSave != null && gate != null) {
      final stateName = gateSave.doorState;
      final parsedState = DoorState.values.firstWhere(
        (s) => s.name == stateName,
        orElse: () => DoorState.closed,
      );
      gate.restoreState(
        state: parsedState,
        progress: gateSave.progress,
        triggered: gateSave.triggered,
        closeEventActive: gateSave.wasCloseEventActive,
      );
    }

    if (!_exitUnlocked && canUseLevelExit()) {
      _openExitDoor();
    }

    clearTransientProjectiles();
  }

  void clearTransientProjectiles() {
    final manager = enemyManager;
    if (manager != null) {
      final enemyProjectiles = manager.projectiles.toList(growable: false);
      for (final projectile in enemyProjectiles) {
        manager.removeProjectile(projectile);
      }
    }
    player.weaponManager.clearProjectiles();
  }
}
