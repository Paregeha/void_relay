class EnemySaveData {
  const EnemySaveData({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.hp,
    required this.isAlive,
    required this.facingRight,
    required this.state,
    this.feetX,
    this.feetY,
    this.velocityX,
    this.velocityY,
    this.isGrounded,
  });

  final String id;
  final String type;
  final double x;
  final double y;
  final int hp;
  final bool isAlive;
  final bool facingRight;
  final String state;
  final double? feetX;
  final double? feetY;
  final double? velocityX;
  final double? velocityY;
  final bool? isGrounded;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'x': x,
    'y': y,
    'hp': hp,
    'isAlive': isAlive,
    'facingRight': facingRight,
    'state': state,
    'feetX': feetX,
    'feetY': feetY,
    'velocityX': velocityX,
    'velocityY': velocityY,
    'isGrounded': isGrounded,
  };

  static EnemySaveData? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final type = json['type'];
    final x = json['x'];
    final y = json['y'];
    final hp = json['hp'];
    final isAlive = json['isAlive'];
    final facingRight = json['facingRight'];
    final state = json['state'];
    final feetX = json['feetX'];
    final feetY = json['feetY'];
    final velocityX = json['velocityX'];
    final velocityY = json['velocityY'];
    final isGrounded = json['isGrounded'];

    if (id is! String ||
        type is! String ||
        x is! num ||
        y is! num ||
        hp is! num ||
        isAlive is! bool ||
        facingRight is! bool ||
        state is! String) {
      return null;
    }

    if (feetX != null && feetX is! num) return null;
    if (feetY != null && feetY is! num) return null;
    if (velocityX != null && velocityX is! num) return null;
    if (velocityY != null && velocityY is! num) return null;
    if (isGrounded != null && isGrounded is! bool) return null;

    return EnemySaveData(
      id: id,
      type: type,
      x: x.toDouble(),
      y: y.toDouble(),
      hp: hp.toInt(),
      isAlive: isAlive,
      facingRight: facingRight,
      state: state,
      feetX: feetX is num ? feetX.toDouble() : null,
      feetY: feetY is num ? feetY.toDouble() : null,
      velocityX: velocityX is num ? velocityX.toDouble() : null,
      velocityY: velocityY is num ? velocityY.toDouble() : null,
      isGrounded: isGrounded as bool?,
    );
  }
}

class CoolingStationSaveData {
  const CoolingStationSaveData({required this.id, required this.isCollected});

  final String id;
  final bool isCollected;

  Map<String, dynamic> toJson() => {'id': id, 'isCollected': isCollected};

  static CoolingStationSaveData? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final isCollected = json['isCollected'];
    if (id is! String || isCollected is! bool) {
      return null;
    }
    return CoolingStationSaveData(id: id, isCollected: isCollected);
  }
}

class HeartPickupSaveData {
  const HeartPickupSaveData({required this.id, required this.isCollected});

  final String id;
  final bool isCollected;

  Map<String, dynamic> toJson() => {'id': id, 'isCollected': isCollected};

  static HeartPickupSaveData? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final isCollected = json['isCollected'];
    if (id is! String || isCollected is! bool) {
      return null;
    }
    return HeartPickupSaveData(id: id, isCollected: isCollected);
  }
}

class RepairTerminalSaveData {
  const RepairTerminalSaveData({
    required this.id,
    required this.isRepairing,
    required this.isRepaired,
    required this.repairProgress,
    required this.completedTimer,
  });

  final String id;
  final bool isRepairing;
  final bool isRepaired;
  final double repairProgress;
  final double completedTimer;

  Map<String, dynamic> toJson() => {
    'id': id,
    'isRepairing': isRepairing,
    'isRepaired': isRepaired,
    'repairProgress': repairProgress,
    'completedTimer': completedTimer,
  };

  static RepairTerminalSaveData? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final isRepairing = json['isRepairing'];
    final isRepaired = json['isRepaired'];
    final repairProgress = json['repairProgress'];
    final completedTimer = json['completedTimer'];

    if (id is! String ||
        isRepairing is! bool ||
        isRepaired is! bool ||
        repairProgress is! num ||
        completedTimer is! num) {
      return null;
    }

    return RepairTerminalSaveData(
      id: id,
      isRepairing: isRepairing,
      isRepaired: isRepaired,
      repairProgress: repairProgress.toDouble(),
      completedTimer: completedTimer.toDouble(),
    );
  }
}

class RelayGateSaveData {
  const RelayGateSaveData({
    required this.doorState,
    required this.progress,
    required this.triggered,
    required this.wasCloseEventActive,
  });

  final String doorState;
  final double progress;
  final bool triggered;
  final bool wasCloseEventActive;

  Map<String, dynamic> toJson() => {
    'doorState': doorState,
    'progress': progress,
    'triggered': triggered,
    'wasCloseEventActive': wasCloseEventActive,
  };

  static RelayGateSaveData? fromJson(Map<String, dynamic> json) {
    final doorState = json['doorState'];
    final progress = json['progress'];
    final triggered = json['triggered'];
    final wasCloseEventActive = json['wasCloseEventActive'];

    if (doorState is! String ||
        progress is! num ||
        triggered is! bool ||
        wasCloseEventActive is! bool) {
      return null;
    }

    return RelayGateSaveData(
      doorState: doorState,
      progress: progress.toDouble(),
      triggered: triggered,
      wasCloseEventActive: wasCloseEventActive,
    );
  }
}

class WorldStateSaveData {
  const WorldStateSaveData({
    required this.enemies,
    required this.coolingStations,
    required this.heartPickups,
    required this.repairTerminals,
    required this.relayGate,
  });

  final List<EnemySaveData> enemies;
  final List<CoolingStationSaveData> coolingStations;
  final List<HeartPickupSaveData> heartPickups;
  final List<RepairTerminalSaveData> repairTerminals;
  final RelayGateSaveData? relayGate;

  Map<String, dynamic> toJson() => {
    'enemies': enemies.map((e) => e.toJson()).toList(growable: false),
    'coolingStations': coolingStations
        .map((c) => c.toJson())
        .toList(growable: false),
    'heartPickups': heartPickups.map((h) => h.toJson()).toList(growable: false),
    'repairTerminals': repairTerminals
        .map((r) => r.toJson())
        .toList(growable: false),
    'relayGate': relayGate?.toJson(),
  };

  static WorldStateSaveData? fromJson(Map<String, dynamic> json) {
    final enemiesRaw = json['enemies'];
    final coolingRaw = json['coolingStations'];
    final heartsRaw = json['heartPickups'];
    final terminalsRaw = json['repairTerminals'];
    final relayGateRaw = json['relayGate'];

    if (enemiesRaw is! List || coolingRaw is! List || terminalsRaw is! List) {
      return null;
    }

    final enemies = enemiesRaw
        .whereType<Map>()
        .map((m) => EnemySaveData.fromJson(Map<String, dynamic>.from(m)))
        .whereType<EnemySaveData>()
        .toList(growable: false);
    final coolingStations = coolingRaw
        .whereType<Map>()
        .map(
          (m) => CoolingStationSaveData.fromJson(Map<String, dynamic>.from(m)),
        )
        .whereType<CoolingStationSaveData>()
        .toList(growable: false);
    final heartPickups = (heartsRaw is List ? heartsRaw : const <dynamic>[])
        .whereType<Map>()
        .map((m) => HeartPickupSaveData.fromJson(Map<String, dynamic>.from(m)))
        .whereType<HeartPickupSaveData>()
        .toList(growable: false);
    final repairTerminals = terminalsRaw
        .whereType<Map>()
        .map(
          (m) => RepairTerminalSaveData.fromJson(Map<String, dynamic>.from(m)),
        )
        .whereType<RepairTerminalSaveData>()
        .toList(growable: false);

    RelayGateSaveData? relayGate;
    if (relayGateRaw is Map) {
      relayGate = RelayGateSaveData.fromJson(
        Map<String, dynamic>.from(relayGateRaw),
      );
    }

    return WorldStateSaveData(
      enemies: enemies,
      coolingStations: coolingStations,
      heartPickups: heartPickups,
      repairTerminals: repairTerminals,
      relayGate: relayGate,
    );
  }
}

class HazardStateSaveData {
  const HazardStateSaveData({
    required this.activeEventId,
    required this.activeEventElapsed,
    required this.timeSinceLastEvent,
    required this.timeSinceLastBlackout,
    required this.timeSinceLastToxicGas,
    required this.timeSinceLastDoorFailure,
    required this.lastProcessedSectorIndex,
    required this.doorFailureTriggeredInSector,
  });

  final String? activeEventId;
  final double activeEventElapsed;
  final double timeSinceLastEvent;
  final double timeSinceLastBlackout;
  final double timeSinceLastToxicGas;
  final double timeSinceLastDoorFailure;
  final int lastProcessedSectorIndex;
  final bool doorFailureTriggeredInSector;

  Map<String, dynamic> toJson() => {
    'activeEventId': activeEventId,
    'activeEventElapsed': activeEventElapsed,
    'timeSinceLastEvent': timeSinceLastEvent,
    'timeSinceLastBlackout': timeSinceLastBlackout,
    'timeSinceLastToxicGas': timeSinceLastToxicGas,
    'timeSinceLastDoorFailure': timeSinceLastDoorFailure,
    'lastProcessedSectorIndex': lastProcessedSectorIndex,
    'doorFailureTriggeredInSector': doorFailureTriggeredInSector,
  };

  static HazardStateSaveData? fromJson(Map<String, dynamic> json) {
    final activeEventId = json['activeEventId'];
    final activeEventElapsed = json['activeEventElapsed'];
    final timeSinceLastEvent = json['timeSinceLastEvent'];
    final timeSinceLastBlackout = json['timeSinceLastBlackout'];
    final timeSinceLastToxicGas = json['timeSinceLastToxicGas'];
    final timeSinceLastDoorFailure = json['timeSinceLastDoorFailure'];
    final lastProcessedSectorIndex = json['lastProcessedSectorIndex'];
    final doorFailureTriggeredInSector = json['doorFailureTriggeredInSector'];

    if (activeEventId != null && activeEventId is! String) {
      return null;
    }
    if (activeEventElapsed is! num ||
        timeSinceLastEvent is! num ||
        timeSinceLastBlackout is! num ||
        timeSinceLastToxicGas is! num ||
        timeSinceLastDoorFailure is! num ||
        lastProcessedSectorIndex is! num ||
        doorFailureTriggeredInSector is! bool) {
      return null;
    }

    return HazardStateSaveData(
      activeEventId: activeEventId as String?,
      activeEventElapsed: activeEventElapsed.toDouble(),
      timeSinceLastEvent: timeSinceLastEvent.toDouble(),
      timeSinceLastBlackout: timeSinceLastBlackout.toDouble(),
      timeSinceLastToxicGas: timeSinceLastToxicGas.toDouble(),
      timeSinceLastDoorFailure: timeSinceLastDoorFailure.toDouble(),
      lastProcessedSectorIndex: lastProcessedSectorIndex.toInt(),
      doorFailureTriggeredInSector: doorFailureTriggeredInSector,
    );
  }
}
