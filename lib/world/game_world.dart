import 'package:flame/components.dart';

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
  late EnemyManager enemyManager;
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
    final room = RoomBuilder.buildRoom(roomIndex);
    platforms = room.platforms;
    roomTypes = room.roomTypes;
    roomSize = room.roomSize.clone();

    add(BackgroundComponent(roomSize: roomSize)..priority = backgroundPriority);

    for (final platform in platforms) {
      platform.priority = terrainPriority;
      add(platform);
    }

    // Spawn player
    player = PlayerComponent();
    player.priority = playerPriority;
    if (playerMaxHealthBonus > 0) {
      player.maxHealth += playerMaxHealthBonus;
      player.health = player.maxHealth;
    }
    player.position = room.playerSpawn.clone();
    add(player);

    interactionSystem = InteractionSystem(player: player);
    add(interactionSystem);

    // Spawn enemies
    enemyManager = EnemyManager(
      enemyRenderPriority: enemyPriority,
      projectileRenderPriority: projectilePriority,
    )..priority = enemyPriority;
    add(enemyManager);
    player.weaponManager.setEnemyManager(enemyManager);

    for (final spawn in room.enemySpawns) {
      final enemy = _createEnemyForSpawn(spawn);
      if (enemy == null) {
        continue;
      }
      enemy.priority = enemyPriority;
      enemyManager.addEnemy(enemy);
    }

    // Spawn cooling stations
    for (final pos in room.coolingStationSpawns) {
      add(
        CoolingStation(position: pos, player: player)
          ..priority = terrainPriority,
      );
    }

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

    // Spawn relay gate
    if (room.relayGatePosition != null) {
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
      enemies: enemyManager.enemies,
      enemyProjectiles: enemyManager.projectiles,
    );
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
    if (enemyManager.enemies.isEmpty) return; // ще не ініціалізовано
    // Не використовуємо isMounted як критерій смерті: під час onLoad монтування
    // може ще не завершитись, що раніше викликало хибний автоперехід сектора.
    final allDead = enemyManager.enemies.every((e) => e.health <= 0);
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
    if (enemyManager.enemies.isEmpty) return false;
    return enemyManager.enemies.any((e) => e.isMounted && e.health > 0);
  }

  int get aliveHostilesCount {
    return enemyManager.enemies
        .where((e) => e.isMounted && e.health > 0)
        .length;
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
}
