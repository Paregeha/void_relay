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
import 'interactive/cooling_station.dart';
import 'interactive/relay_gate.dart';
import 'interactive/repair_terminal.dart';
import 'interactive/switch_console.dart';
import 'platform/platform_component.dart';
import 'room/room_builder.dart';
import 'room/room_types.dart';

class GameWorld extends Component {
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

    for (final platform in platforms) {
      add(platform);
    }

    // Spawn player
    player = PlayerComponent();
    if (playerMaxHealthBonus > 0) {
      player.maxHealth += playerMaxHealthBonus;
      player.health = player.maxHealth;
    }
    player.position = room.playerSpawn.clone();
    add(player);

    interactionSystem = InteractionSystem(player: player);
    add(interactionSystem);

    // Spawn enemies
    enemyManager = EnemyManager();
    add(enemyManager);
    player.weaponManager.setEnemyManager(enemyManager);

    for (final spawn in room.enemySpawns) {
      BaseEnemy enemy;
      switch (spawn.type) {
        case 'crawler':
          final crawler = Crawler();
          crawler.player = player;
          crawler.platforms = platforms;
          enemy = crawler;
        case 'hover_drone':
          final drone = HoverDrone();
          drone.player = player;
          enemy = drone;
        case 'sentry_turret':
          final turret = SentryTurret();
          turret.player = player;
          enemy = turret;
        default:
          enemy = BaseEnemy();
      }
      enemy.position = spawn.position.clone();
      enemyManager.addEnemy(enemy);
    }

    // Spawn cooling stations
    for (final pos in room.coolingStationSpawns) {
      add(CoolingStation(position: pos, player: player));
    }

    // Spawn switch consoles
    for (final pos in room.switchConsoleSpawns) {
      final console = SwitchConsole(
        position: pos,
        player: player,
        onToggled: _onSwitchConsoleToggled,
      );
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
        ),
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
}
