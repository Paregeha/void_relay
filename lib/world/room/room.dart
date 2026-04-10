import 'package:flame/components.dart';

import '../platform/platform_component.dart';
import 'room_types.dart';

class Room {
  final List<PlatformComponent> platforms;
  final Vector2 playerSpawn;
  final List<EnemySpawn> enemySpawns;
  final Vector2 roomSize;
  final List<Vector2> coolingStationSpawns;
  final List<Vector2> switchConsoleSpawns;
  final List<Vector2> repairTerminalSpawns;
  final Vector2? relayGatePosition;
  final Set<RoomType> roomTypes;

  Room({
    required this.platforms,
    required this.playerSpawn,
    required this.enemySpawns,
    required this.roomSize,
    this.coolingStationSpawns = const [],
    this.switchConsoleSpawns = const [],
    this.repairTerminalSpawns = const [],
    this.relayGatePosition,
    this.roomTypes = const {RoomType.transit},
  });
}

class EnemySpawn {
  final Vector2 position;
  final String type;

  EnemySpawn(this.position, {this.type = 'base'});
}
