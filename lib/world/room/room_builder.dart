import 'package:flame/components.dart';

import '../../config/game_config.dart';
import '../platform/platform_component.dart';
import 'room.dart';
import 'room_types.dart';

class RoomBuilder {
  static const int _totalRooms = 2;
  // Authoring coordinates in this file are defined for this baseline room.
  static const double _designWidth = 3840;
  static const double _designHeight = 540;
  static const double _designGroundTopY = 440;
  static const double _playerHeight = 64;
  static const double _defaultPlatformHeight = 24;
  static const double _designContentLiftY = 154;

  static Vector2 get _defaultRoomSize =>
      Vector2(GameConfig.defaultWorldWidth, GameConfig.defaultWorldHeight);

  /// Returns a room by index. Wraps around when index exceeds known rooms.
  static Room buildRoom(int index) {
    return buildRoomForSize(index, _defaultRoomSize);
  }

  /// Builds a room for a provided size (used by tests and adaptive layouts).
  static Room buildRoomForSize(int index, Vector2 roomSize) {
    switch (index % _totalRooms) {
      case 1:
        return _buildRoom1(roomSize);
      case 0:
      default:
        return _buildRoom0(roomSize);
    }
  }

  /// Returns the sector/room number (1-indexed) for display.
  static int getSectorNumber(int roomIndex) {
    return roomIndex + 1;
  }

  // ── Room 0 — intro sector ──────────────────────────────────────────
  static Room _buildRoom0(Vector2 roomSize) {
    final floorY = roomSize.y - _sy(roomSize, 50);
    final wallCenterY = roomSize.y / 2;
    final rightWallX = roomSize.x - _sx(roomSize, 10);
    final relayX = roomSize.x - _sx(roomSize, 60);

    final platforms = <PlatformComponent>[
      // Long base floor
      PlatformComponent(
        position: Vector2(roomSize.x / 2, floorY),
        size: Vector2(roomSize.x, _sy(roomSize, 100)),
      ),
      PlatformComponent(
        position: _p(roomSize, 220, 450),
        size: _size(roomSize, 180, 24),
      ),
      PlatformComponent(
        position: _p(roomSize, 460, 420),
        size: _size(roomSize, 220, 24),
      ),
      PlatformComponent(
        position: _p(roomSize, 760, 380),
        size: _size(roomSize, 260, 24),
      ),
      PlatformComponent(
        position: _p(roomSize, 1120, 350),
        size: _size(roomSize, 220, 24),
      ),
      PlatformComponent(
        position: _p(roomSize, 1450, 380),
        size: _size(roomSize, 200, 24),
      ),
      PlatformComponent(
        position: _p(roomSize, 1720, 430),
        size: _size(roomSize, 170, 24),
      ),
      PlatformComponent(
        position: _p(roomSize, 1320, 460),
        size: _size(roomSize, 140, 24),
      ),
      // Extra traversal segment for long horizontal world
      PlatformComponent(
        position: _p(roomSize, 2220, 450),
        size: _size(roomSize, 200, 24),
      ),
      PlatformComponent(
        position: _p(roomSize, 2540, 410),
        size: _size(roomSize, 240, 24),
      ),
      PlatformComponent(
        position: _p(roomSize, 2860, 380),
        size: _size(roomSize, 230, 24),
      ),
      PlatformComponent(
        position: _p(roomSize, 3140, 430),
        size: _size(roomSize, 180, 24),
      ),
      PlatformComponent(
        position: _p(roomSize, 3440, 400),
        size: _size(roomSize, 220, 24),
      ),
      // Ceiling boundary
      PlatformComponent(
        position: Vector2(roomSize.x / 2, _sy(roomSize, 10)),
        size: Vector2(roomSize.x, _sy(roomSize, 20)),
      ),
      // Side walls
      PlatformComponent(
        position: Vector2(_sx(roomSize, 10), wallCenterY),
        size: Vector2(_sx(roomSize, 20), roomSize.y),
      ),
      PlatformComponent(
        position: Vector2(rightWallX, wallCenterY),
        size: Vector2(_sx(roomSize, 20), roomSize.y),
      ),
    ];
    return Room(
      platforms: platforms,
      playerSpawn: _playerGroundSpawn(roomSize, 80),
      enemySpawns: [
        EnemySpawn(_p(roomSize, 520, 404), type: 'crawler'),
        EnemySpawn(_p(roomSize, 900, 310), type: 'hover_drone'),
        EnemySpawn(
          _enemyBottomAnchoredOnGround(roomSize, 1580, enemyHeight: 32),
          type: 'sentry_turret',
        ),
        EnemySpawn(_p(roomSize, 2460, 394), type: 'crawler'),
        EnemySpawn(_p(roomSize, 3020, 320), type: 'hover_drone'),
      ],
      roomSize: roomSize.clone(),
      // Multiple cooling stations across traversal path.
      coolingStationSpawns: [
        _bottomAnchoredOnPlatform(roomSize, 760, 380),
        _bottomAnchoredOnPlatform(roomSize, 1450, 380),
        _bottomAnchoredOnPlatform(roomSize, 2860, 380),
      ],
      switchConsoleSpawns: [
        _bottomAnchoredOnGround(roomSize, 1240),
        _bottomAnchoredOnGround(roomSize, 2860),
      ],
      repairTerminalSpawns: [
        _bottomAnchoredOnPlatform(roomSize, 1680, 430),
        _bottomAnchoredOnGround(roomSize, 3320),
      ],
      // Relay gate at right end of room
      relayGatePosition: _bottomAnchoredOnGround(
        roomSize,
        relayX,
        alreadyScaledX: true,
      ),
      roomTypes: {
        RoomType.transit,
        RoomType.combat,
        RoomType.cooling,
        RoomType.relay,
      },
    );
  }

  // ── Room 1 — second sector ──────────────────────────────────────────
  static Room _buildRoom1(Vector2 roomSize) {
    final floorY = roomSize.y - _sy(roomSize, 50);
    final wallCenterY = roomSize.y / 2;
    final rightWallX = roomSize.x - _sx(roomSize, 10);
    final relayX = roomSize.x - _sx(roomSize, 60);

    final platforms = <PlatformComponent>[
      PlatformComponent(
        position: Vector2(roomSize.x / 2, floorY),
        size: Vector2(roomSize.x, _sy(roomSize, 100)),
      ),
      PlatformComponent(
        position: _p(roomSize, 260, 460),
        size: _size(roomSize, 200, 24),
      ),
      PlatformComponent(
        position: _p(roomSize, 520, 420),
        size: _size(roomSize, 220, 24),
      ),
      PlatformComponent(
        position: _p(roomSize, 820, 380),
        size: _size(roomSize, 250, 24),
      ),
      PlatformComponent(
        position: _p(roomSize, 1120, 340),
        size: _size(roomSize, 200, 24),
      ),
      PlatformComponent(
        position: _p(roomSize, 1380, 380),
        size: _size(roomSize, 230, 24),
      ),
      PlatformComponent(
        position: _p(roomSize, 1660, 430),
        size: _size(roomSize, 180, 24),
      ),
      PlatformComponent(
        position: _p(roomSize, 980, 450),
        size: _size(roomSize, 160, 24),
      ),
      PlatformComponent(
        position: _p(roomSize, 2240, 430),
        size: _size(roomSize, 210, 24),
      ),
      PlatformComponent(
        position: _p(roomSize, 2520, 380),
        size: _size(roomSize, 240, 24),
      ),
      PlatformComponent(
        position: _p(roomSize, 2820, 340),
        size: _size(roomSize, 230, 24),
      ),
      PlatformComponent(
        position: _p(roomSize, 3140, 380),
        size: _size(roomSize, 240, 24),
      ),
      PlatformComponent(
        position: _p(roomSize, 3440, 430),
        size: _size(roomSize, 200, 24),
      ),
      // Ceiling boundary
      PlatformComponent(
        position: Vector2(roomSize.x / 2, _sy(roomSize, 10)),
        size: Vector2(roomSize.x, _sy(roomSize, 20)),
      ),
      // Side walls
      PlatformComponent(
        position: Vector2(_sx(roomSize, 10), wallCenterY),
        size: Vector2(_sx(roomSize, 20), roomSize.y),
      ),
      PlatformComponent(
        position: Vector2(rightWallX, wallCenterY),
        size: Vector2(_sx(roomSize, 20), roomSize.y),
      ),
    ];
    return Room(
      platforms: platforms,
      playerSpawn: _playerGroundSpawn(roomSize, 140),
      enemySpawns: [
        EnemySpawn(_p(roomSize, 560, 404), type: 'crawler'),
        EnemySpawn(_p(roomSize, 920, 310), type: 'hover_drone'),
        EnemySpawn(_p(roomSize, 1260, 310), type: 'hover_drone'),
        EnemySpawn(
          _enemyBottomAnchoredOnPlatform(roomSize, 1600, 430, enemyHeight: 32),
          type: 'sentry_turret',
        ),
        EnemySpawn(_p(roomSize, 2480, 360), type: 'crawler'),
        EnemySpawn(_p(roomSize, 2960, 320), type: 'hover_drone'),
        EnemySpawn(
          _enemyBottomAnchoredOnPlatform(roomSize, 3380, 430, enemyHeight: 32),
          type: 'sentry_turret',
        ),
      ],
      roomSize: roomSize.clone(),
      // Multiple cooling stations in harder room
      coolingStationSpawns: [
        _bottomAnchoredOnPlatform(roomSize, 520, 420),
        _bottomAnchoredOnPlatform(roomSize, 1120, 340),
        _bottomAnchoredOnPlatform(roomSize, 2240, 430),
        _bottomAnchoredOnPlatform(roomSize, 2820, 340),
      ],
      switchConsoleSpawns: [
        _bottomAnchoredOnGround(roomSize, 1460),
        _bottomAnchoredOnGround(roomSize, 3000),
      ],
      repairTerminalSpawns: [
        _bottomAnchoredOnPlatform(roomSize, 1700, 430),
        _bottomAnchoredOnPlatform(roomSize, 3480, 430),
      ],
      relayGatePosition: _bottomAnchoredOnGround(
        roomSize,
        relayX,
        alreadyScaledX: true,
      ),
      roomTypes: {
        RoomType.transit,
        RoomType.combat,
        RoomType.hazard,
        RoomType.relay,
      },
    );
  }

  static double _sx(Vector2 roomSize, double value) =>
      value * (roomSize.x / _designWidth);

  static double _sy(Vector2 roomSize, double value) =>
      value * (roomSize.y / _designHeight);

  static Vector2 _p(Vector2 roomSize, double x, double y) =>
      Vector2(_sx(roomSize, x), _sy(roomSize, y - _designContentLiftY));

  static Vector2 _size(Vector2 roomSize, double w, double h) =>
      Vector2(_sx(roomSize, w), _sy(roomSize, h));

  static double _groundTopY(Vector2 roomSize) =>
      _sy(roomSize, _designGroundTopY);

  static Vector2 _playerGroundSpawn(Vector2 roomSize, double designX) =>
      Vector2(
        _sx(roomSize, designX),
        _groundTopY(roomSize) - _playerHeight / 2,
      );

  static Vector2 _bottomAnchoredOnGround(
    Vector2 roomSize,
    double x, {
    bool alreadyScaledX = false,
  }) => Vector2(alreadyScaledX ? x : _sx(roomSize, x), _groundTopY(roomSize));

  static Vector2 _bottomAnchoredOnPlatform(
    Vector2 roomSize,
    double designX,
    double designPlatformCenterY, {
    double designPlatformHeight = _defaultPlatformHeight,
  }) => Vector2(
    _sx(roomSize, designX),
    _sy(
      roomSize,
      designPlatformCenterY - designPlatformHeight / 2 - _designContentLiftY,
    ),
  );

  static Vector2 _enemyBottomAnchoredOnGround(
    Vector2 roomSize,
    double designX, {
    required double enemyHeight,
  }) =>
      Vector2(_sx(roomSize, designX), _groundTopY(roomSize) - enemyHeight / 2);

  static Vector2 _enemyBottomAnchoredOnPlatform(
    Vector2 roomSize,
    double designX,
    double designPlatformCenterY, {
    double designPlatformHeight = _defaultPlatformHeight,
    required double enemyHeight,
  }) {
    final platformTop = _sy(
      roomSize,
      designPlatformCenterY - designPlatformHeight / 2 - _designContentLiftY,
    );
    return Vector2(_sx(roomSize, designX), platformTop - enemyHeight / 2);
  }
}
