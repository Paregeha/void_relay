import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../core/debug/render_trace.dart';
import '../enemies/base_enemy.dart';
import '../enemies/crawler/crawler.dart';
import '../enemies/enemy_manager.dart';
import '../enemies/hover_drone/hover_drone.dart';
import '../enemies/sentry_turret/sentry_turret.dart';
import '../flame_game.dart';
import '../player/player_component.dart';
import '../systems/collision_handler.dart';
import '../systems/interaction_system.dart';
import 'background/background_component.dart';
import 'interactive/cooling_station.dart';
import 'interactive/relay_gate.dart';
import 'interactive/repair_terminal.dart';
import 'interactive/switch_console.dart';
import 'platform/platform_component.dart';
import 'room/room.dart';
import 'room/room_builder.dart';
import 'room/room_types.dart';

class GameWorld extends Component {
  // ── CLEANUP: enemies are controlled by global config flag
  static const bool enableEnemies = GameConfig.enableEnemies;

  static const int backgroundPriority = -1000;
  static const int terrainPriority = -500;
  static const int enemyPriority = 0;
  static const int playerPriority = 100;
  static const int projectilePriority = 200;
  static const int effectsPriority = 300;

  final int roomIndex;
  final double playerMaxHealthBonus;

  late PlayerComponent player;
  late List<PlatformComponent> platforms;
  late CollisionHandler collisionHandler;
  EnemyManager? enemyManager;
  late InteractionSystem interactionSystem;
  late Set<RoomType> roomTypes;
  Vector2 roomSize = Vector2.zero();

  /// Викликається при завершенні сектора.
  /// Причина: 'Relay reached' або 'Room cleared'.
  void Function(String reason)? onSectorComplete;

  bool _sectorCompleted = false;
  double _sectorElapsedSeconds = 0;

  GameWorld({this.roomIndex = 0, this.playerMaxHealthBonus = 0});

  @override
  Future<void> onLoad() async {
    // ── DEBUG: Log render order for diagnostic ────────────────────────────────
    if (PlayerComponent.debugRenderOrderLogs) {
      print('[RenderOrder] === GameWorld render order ===');
    }

    final room = RoomBuilder.buildRoom(roomIndex);
    platforms = room.platforms;
    roomTypes = room.roomTypes;
    roomSize = room.roomSize.clone();

    add(BackgroundComponent(roomSize: roomSize)..priority = backgroundPriority);
    if (PlayerComponent.debugRenderOrderLogs) {
      print('[RenderOrder] background priority=$backgroundPriority');
    }

    if (!PlayerComponent.debugHideLevelGeometry) {
      for (final platform in platforms) {
        platform.priority = terrainPriority;
        add(platform);
      }
      if (PlayerComponent.debugRenderOrderLogs) {
        print(
          '[RenderOrder] terrain priority=$terrainPriority (${platforms.length} platforms)',
        );
      }
    } else {
      if (PlayerComponent.debugRenderOrderLogs) {
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

    if (PlayerComponent.debugRenderOrderLogs) {
      // Debug: dump player component structure
      print('[RenderOrder] player children:');
      for (final child in player.children) {
        if (child is PositionComponent) {
          print(
            '[RenderOrder]   - ${child.runtimeType} '
            'priority=${child.priority} '
            'pos=${child.position} '
            'size=${child.size} '
            'anchor=${child.anchor}',
          );
        } else {
          print('[RenderOrder]   - ${child.runtimeType}');
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
      add(enemyManager!);
      if (PlayerComponent.debugRenderOrderLogs) {
        print('[RenderOrder] enemyManager priority=$enemyPriority');
      }

      player.weaponManager.setEnemyManager(enemyManager!);

      for (final spawn in room.enemySpawns) {
        final enemy = _createEnemyForSpawn(spawn);
        if (enemy == null) {
          continue;
        }
        enemy.priority = enemyPriority;
        enemyManager!.addEnemy(enemy);
      }
    } else {
      if (PlayerComponent.debugRenderOrderLogs) {
        print('[GameWorld] enemies disabled (GameConfig.enableEnemies=false)');
      }
    }

    if (!PlayerComponent.debugHideLevelGeometry) {
      // Spawn cooling stations
      for (final pos in room.coolingStationSpawns) {
        add(
          CoolingStation(position: pos, player: player)
            ..priority = terrainPriority,
        );
      }
    }

    if (!PlayerComponent.debugHideLevelGeometry) {
      // Spawn switch consoles
      for (final pos in room.switchConsoleSpawns) {
        final console = SwitchConsole(
          position: pos,
          player: player,
          onToggled: _onSwitchConsoleToggled,
        );
        console.priority = terrainPriority;
        add(console);
        interactionSystem.register(
          InteractionBinding(
            component: console,
            interactionRange: console.interactionRange,
            onInteract: (_) => console.toggle(),
          ),
        );
      }
    }

    if (!PlayerComponent.debugHideLevelGeometry) {
      // Spawn repair terminals (used to resolve blocking failures)
      for (final pos in room.repairTerminalSpawns) {
        final terminal = RepairTerminal(
          position: pos,
          onRepairCompleted: _onRepairTerminalCompleted,
        );
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
            onInteract: (_) => terminal.startRepair(),
          ),
        );
      }
    }

    // Spawn relay gate
    if (!PlayerComponent.debugHideLevelGeometry &&
        room.relayGatePosition != null) {
      add(
        RelayGate(
          position: room.relayGatePosition!,
          player: player,
          onReached: () => _completeSector('Relay reached'),
        )..priority = terrainPriority,
      );
    }

    collisionHandler = CollisionHandler(
      player: player,
      platforms: platforms,
      enemies: enemyManager?.enemies ?? const [],
      enemyProjectiles: enemyManager?.projectiles ?? const [],
    );

    if (PlayerComponent.debugRenderOrderLogs) {
      print('[RenderOrder] === GameWorld setup complete ===');
      _debugDumpWorldRenderOrder();
    }
  }

  @override
  void render(Canvas canvas) {
    if (PlayerComponent.debugTraceRenderSequence) {
      RenderTrace.log('GameWorld.render START (before super.render)');
    }
    super.render(canvas);
    if (PlayerComponent.debugTraceRenderSequence) {
      RenderTrace.log('GameWorld.render END (after super.render)');
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final game = findGame();
    if (game is VoidRelayGame && game.isGameplayInputBlocked) {
      return;
    }
    if (!_sectorCompleted) {
      _sectorElapsedSeconds += dt;
    }
    collisionHandler.update(dt);
    _checkAllEnemiesKilled();
  }

  void _checkAllEnemiesKilled() {
    if (_sectorCompleted) return;
    if (!enableEnemies) return;
    final manager = enemyManager;
    if (manager == null || manager.enemies.isEmpty) return;
    // Не використовуємо isMounted як критерій смерті: під час onLoad монтування
    // може ще не завершитись, що раніше викликало хибний автоперехід сектора.
    final allDead = manager.enemies.every((e) => e.health <= 0);
    if (allDead) {
      _completeSector('Room cleared');
    }
  }

  void _completeSector(String reason) {
    if (_sectorCompleted) return;

    final game = findGame();
    if (game is VoidRelayGame &&
        (game.isDoorFailureActive || game.isSystemBreakdownActive)) {
      // Door failure/system breakdown блокують прогрес сектора,
      // поки не завершено troubleshooting.
      return;
    }

    _sectorCompleted = true;
    onSectorComplete?.call(reason);
  }

  void _onSwitchConsoleToggled(bool isActive) {
    if (!isActive) return;
    final game = findGame();
    // MVP troubleshooting: system breakdown резолвиться через switch console.
    if (game is VoidRelayGame && game.isSystemBreakdownActive) {
      game.resolveSystemBreakdown();
    }
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
      return manager.enemies.any((e) => e.isMounted && e.health > 0);
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
      return manager.enemies.where((e) => e.isMounted && e.health > 0).length;
    } catch (e) {
      // During initialization phase, enemyManager may not be fully ready
      return 0;
    }
  }

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

  BaseEnemy? _createEnemyForSpawn(EnemySpawn spawn) {
    switch (spawn.type) {
      case 'crawler':
        final crawler = Crawler();
        crawler.player = player;
        crawler.platforms = platforms;
        final snappedBaselineY = _resolveCrawlerBaselineY(
          spawn.position.x,
          spawn.position.y,
        );
        crawler.position = Vector2(spawn.position.x, snappedBaselineY);
        return crawler;
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
        turret.position = spawn.position.clone();
        return turret;
      default:
        return null;
    }
  }

  double _resolveCrawlerBaselineY(double x, double fallbackY) {
    double? closestTop;
    double closestDistance = double.infinity;

    for (final platform in platforms) {
      final rect = platform.toRect();
      // Ignore vertical walls and non-ground geometry for crawler grounding.
      if (rect.width <= rect.height) continue;
      if (x < rect.left || x > rect.right) continue;

      final distance = (rect.top - fallbackY).abs();
      if (distance < closestDistance) {
        closestDistance = distance;
        closestTop = rect.top;
      }
    }

    return closestTop ?? fallbackY;
  }

  void _debugDumpWorldRenderOrder() {
    print('[RenderOrder] component=Background priority=$backgroundPriority');
    print(
      '[RenderOrder] component=Terrain/Platforms priority=$terrainPriority',
    );
    print('[RenderOrder] component=Ground priority=$terrainPriority');
    print(
      '[RenderOrder] component=PlayerComponent priority=${player.priority}',
    );

    final renderer = player.children.whereType<PositionComponent?>().firstWhere(
      (c) => c?.runtimeType.toString() == '_PlayerAnimationRenderer',
      orElse: () => null,
    );
    print(
      '[RenderOrder] component=_PlayerAnimationRenderer priority=${renderer?.priority ?? "not-found"}',
    );
    print('[RenderOrder] component=Effects priority=$effectsPriority');
    print(
      '[RenderOrder] component=HUD overlay=UiManager.hudOverlay (Flutter overlay)',
    );
  }
}
