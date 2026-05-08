import 'package:flutter_test/flutter_test.dart';
import 'package:void_relay/world/room/room_builder.dart';

String _positionKey(double x, double y) =>
    '${x.toStringAsFixed(3)}:${y.toStringAsFixed(3)}';

void main() {
  group('Cooling station spawns', () {
    test('room 0 has expected amount without duplicate positions', () {
      final room = RoomBuilder.buildRoom(0);
      final keys = room.coolingStationSpawns
          .map((pos) => _positionKey(pos.x, pos.y))
          .toSet();

      expect(room.coolingStationSpawns.length, 3);
      expect(keys.length, room.coolingStationSpawns.length);
    });

    test('room 1 has expected amount without duplicate positions', () {
      final room = RoomBuilder.buildRoom(1);
      final keys = room.coolingStationSpawns
          .map((pos) => _positionKey(pos.x, pos.y))
          .toSet();

      expect(room.coolingStationSpawns.length, 4);
      expect(keys.length, room.coolingStationSpawns.length);
    });

    test('room 0 heart pickups have expected amount without duplicates', () {
      final room = RoomBuilder.buildRoom(0);
      final keys = room.heartPickupSpawns
          .map((pos) => _positionKey(pos.x, pos.y))
          .toSet();

      expect(room.heartPickupSpawns.length, 2);
      expect(keys.length, room.heartPickupSpawns.length);
    });

    test('room 1 heart pickups have expected amount without duplicates', () {
      final room = RoomBuilder.buildRoom(1);
      final keys = room.heartPickupSpawns
          .map((pos) => _positionKey(pos.x, pos.y))
          .toSet();

      expect(room.heartPickupSpawns.length, 2);
      expect(keys.length, room.heartPickupSpawns.length);
    });
  });
}
