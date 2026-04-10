enum RoomType { transit, combat, cooling, hazard, relay }

extension RoomTypeLabel on RoomType {
  String get id {
    switch (this) {
      case RoomType.transit:
        return 'TRANSIT';
      case RoomType.combat:
        return 'COMBAT';
      case RoomType.cooling:
        return 'COOLING';
      case RoomType.hazard:
        return 'HAZARD';
      case RoomType.relay:
        return 'RELAY';
    }
  }
}
