import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:void_relay/world/room/room.dart';
import 'package:void_relay/world/room/room_builder.dart';

void main() {
  group('RoomBuilder adaptive layout', () {
    test('default room layout stays within room bounds', () {
      for (var i = 0; i < 2; i++) {
        final room = RoomBuilder.buildRoom(i);
        _expectRoomInsideBounds(room.roomSize, room);
      }
    });

    test('scaled down room keeps all spawns and platforms inside bounds', () {
      final scaledRoomSize = Vector2(960, 540);

      for (var i = 0; i < 2; i++) {
        final room = RoomBuilder.buildRoomForSize(i, scaledRoomSize);
        _expectRoomInsideBounds(room.roomSize, room);
      }
    });

    test('player and interactives are not embedded into floor/platforms', () {
      for (var i = 0; i < 2; i++) {
        final room = RoomBuilder.buildRoom(i);
        _expectPlayerNotInsidePlatform(room);
        _expectBottomAnchoredNotBelowFloor(room);
      }
    });

    test('sentry turrets are placed on platform or floor support', () {
      for (var i = 0; i < 2; i++) {
        final room = RoomBuilder.buildRoom(i);
        _expectTurretsSupported(room);
      }
    });
  });
}

void _expectRoomInsideBounds(Vector2 roomSize, Room room) {
  const epsilon = 0.001;

  for (final platform in room.platforms) {
    final rect = platform.toRect();
    expect(rect.left, greaterThanOrEqualTo(-epsilon));
    expect(rect.top, greaterThanOrEqualTo(-epsilon));
    expect(rect.right, lessThanOrEqualTo(roomSize.x + epsilon));
    expect(rect.bottom, lessThanOrEqualTo(roomSize.y + epsilon));
  }

  _expectPointInside(room.playerSpawn, roomSize, epsilon);

  for (final enemy in room.enemySpawns) {
    _expectPointInside(enemy.position, roomSize, epsilon);
  }

  for (final position in room.coolingStationSpawns) {
    _expectPointInside(position, roomSize, epsilon);
  }

  for (final position in room.switchConsoleSpawns) {
    _expectPointInside(position, roomSize, epsilon);
  }

  for (final position in room.repairTerminalSpawns) {
    _expectPointInside(position, roomSize, epsilon);
  }

  final relay = room.relayGatePosition;
  if (relay != null) {
    _expectPointInside(relay, roomSize, epsilon);
  }
}

void _expectPointInside(Vector2 point, Vector2 roomSize, double epsilon) {
  expect(point.x, greaterThanOrEqualTo(-epsilon));
  expect(point.y, greaterThanOrEqualTo(-epsilon));
  expect(point.x, lessThanOrEqualTo(roomSize.x + epsilon));
  expect(point.y, lessThanOrEqualTo(roomSize.y + epsilon));
}

void _expectPlayerNotInsidePlatform(Room room) {
  const halfPlayerW = 16.0;
  const halfPlayerH = 32.0;
  final playerRect = Rect.fromLTRB(
    room.playerSpawn.x - halfPlayerW,
    room.playerSpawn.y - halfPlayerH,
    room.playerSpawn.x + halfPlayerW,
    room.playerSpawn.y + halfPlayerH,
  );

  for (final platform in room.platforms) {
    expect(
      playerRect.overlaps(platform.toRect()),
      isFalse,
      reason: 'Player spawn intersects a platform in room.',
    );
  }
}

void _expectBottomAnchoredNotBelowFloor(Room room) {
  final floorTop = room.platforms
      .map((p) => p.toRect())
      .where((rect) => rect.width >= room.roomSize.x * 0.9 && rect.height >= 40)
      .map((rect) => rect.top)
      .reduce((a, b) => a > b ? a : b);

  final bottomAnchored = <Vector2>[
    ...room.coolingStationSpawns,
    ...room.switchConsoleSpawns,
    ...room.repairTerminalSpawns,
    if (room.relayGatePosition != null) room.relayGatePosition!,
  ];

  for (final spawn in bottomAnchored) {
    expect(
      spawn.y,
      lessThanOrEqualTo(floorTop + 0.001),
      reason: 'Bottom-anchored object is below floor top and likely embedded.',
    );
  }
}

void _expectTurretsSupported(Room room) {
  const turretHalfHeight = 16.0;
  const supportTolerance = 1.0;

  final horizontalPlatforms = room.platforms
      .map((p) => p.toRect())
      .where((rect) => rect.width >= rect.height)
      .toList();

  final turrets = room.enemySpawns.where((e) => e.type == 'sentry_turret');
  for (final turret in turrets) {
    final turretBottom = turret.position.y + turretHalfHeight;
    final hasSupport = horizontalPlatforms.any((rect) {
      final insideX =
          turret.position.x >= rect.left + 1 &&
          turret.position.x <= rect.right - 1;
      final onTop = (turretBottom - rect.top).abs() <= supportTolerance;
      return insideX && onTop;
    });

    expect(
      hasSupport,
      isTrue,
      reason: 'Sentry turret must stand on floor/platform support.',
    );
  }
}
