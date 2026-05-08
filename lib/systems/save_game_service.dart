import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../flame_game.dart';
import '../player/player_component.dart';
import 'save_state_models.dart';

class SaveGameData {
  const SaveGameData({
    required this.slotId,
    required this.levelId,
    required this.playerX,
    required this.playerY,
    required this.playerHp,
    required this.currentWeapon,
    required this.playerFacingDirection,
    required this.playerIsGrounded,
    required this.savedAtIso,
    required this.thumbnailBase64,
    required this.playerMaxHp,
    required this.playerMaxHealthBonus,
    required this.score,
    required this.worldState,
    required this.hazardState,
  });

  final String slotId;
  final String levelId;
  final double playerX;
  final double playerY;
  final int playerHp;
  final String currentWeapon;
  final int playerFacingDirection;
  final bool playerIsGrounded;
  final String savedAtIso;
  final String? thumbnailBase64;
  final int playerMaxHp;
  final double playerMaxHealthBonus;
  final int score;
  final WorldStateSaveData worldState;
  final HazardStateSaveData? hazardState;

  int get roomIndex {
    final roomMatch = RegExp(r'^room_(\d+)$').firstMatch(levelId);
    if (roomMatch != null) {
      final room = int.tryParse(roomMatch.group(1) ?? '1');
      if (room != null && room > 0) {
        return room - 1;
      }
    }
    final raw = int.tryParse(levelId);
    if (raw != null && raw >= 0) {
      return raw;
    }
    return 0;
  }

  DateTime? get savedAt {
    try {
      return DateTime.parse(savedAtIso);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
    'slotId': slotId,
    'levelId': levelId,
    'playerX': playerX,
    'playerY': playerY,
    'playerHp': playerHp,
    'playerMaxHp': playerMaxHp,
    'currentWeapon': currentWeapon,
    'playerFacingDirection': playerFacingDirection,
    'playerIsGrounded': playerIsGrounded,
    'savedAtIso': savedAtIso,
    'thumbnailBase64': thumbnailBase64,
    'playerMaxHealthBonus': playerMaxHealthBonus,
    'score': score,
    'worldState': worldState.toJson(),
    'hazardState': hazardState?.toJson(),
  };

  static SaveGameData? fromJson(Map<String, dynamic> json) {
    final slotId = json['slotId'] ?? json['id'];
    final levelId = json['levelId'];
    final roomIndex = json['roomId'] ?? json['roomIndex'];
    final playerX = json['playerX'];
    final playerY = json['playerY'];
    final playerHp = json['playerHp'];
    final playerMaxHp = json['playerMaxHp'];
    final currentWeapon = json['currentWeapon'];
    final playerFacingDirection = json['playerFacingDirection'];
    final playerIsGrounded = json['playerIsGrounded'];
    final savedAtIso = json['savedAtIso'];
    final thumbnailBase64 = json['thumbnailBase64'];
    final playerMaxHealthBonus = json['playerMaxHealthBonus'];
    final score = json['score'];
    final worldStateRaw = json['worldState'];
    final hazardStateRaw = json['hazardState'];

    if (slotId is! String ||
        playerX is! num ||
        playerY is! num ||
        playerHp is! num ||
        currentWeapon is! String ||
        savedAtIso is! String) {
      return null;
    }

    if (levelId != null && levelId is! String) {
      return null;
    }

    if (thumbnailBase64 != null && thumbnailBase64 is! String) {
      return null;
    }

    final resolvedLevelId = levelId is String
        ? levelId
        : roomIndex is num
        ? 'room_${roomIndex.toInt() + 1}'
        : 'room_1';

    final hpInt = playerHp.toInt();
    final maxHpInt = playerMaxHp is num ? playerMaxHp.toInt() : hpInt;
    final facing = playerFacingDirection is num
        ? playerFacingDirection.toInt()
        : 1;
    final grounded = playerIsGrounded is bool ? playerIsGrounded : false;
    final bonus = playerMaxHealthBonus is num
        ? playerMaxHealthBonus.toDouble()
        : 0.0;
    final resolvedScore = score is num ? score.toInt() : 0;

    WorldStateSaveData worldState;
    if (worldStateRaw is Map) {
      worldState =
          WorldStateSaveData.fromJson(
            Map<String, dynamic>.from(worldStateRaw),
          ) ??
          const WorldStateSaveData(
            enemies: [],
            coolingStations: [],
            heartPickups: [],
            repairTerminals: [],
            relayGate: null,
          );
    } else {
      worldState = const WorldStateSaveData(
        enemies: [],
        coolingStations: [],
        heartPickups: [],
        repairTerminals: [],
        relayGate: null,
      );
    }

    HazardStateSaveData? hazardState;
    if (hazardStateRaw is Map) {
      hazardState = HazardStateSaveData.fromJson(
        Map<String, dynamic>.from(hazardStateRaw),
      );
    }

    return SaveGameData(
      slotId: slotId,
      levelId: resolvedLevelId,
      playerX: playerX.toDouble(),
      playerY: playerY.toDouble(),
      playerHp: hpInt,
      currentWeapon: currentWeapon,
      playerFacingDirection: facing,
      playerIsGrounded: grounded,
      savedAtIso: savedAtIso,
      thumbnailBase64: thumbnailBase64 as String?,
      playerMaxHp: maxHpInt,
      playerMaxHealthBonus: bonus,
      score: resolvedScore,
      worldState: worldState,
      hazardState: hazardState,
    );
  }
}

class SaveSlotEntry {
  const SaveSlotEntry({
    required this.slotId,
    required this.slotLabel,
    required this.data,
  });

  final String slotId;
  final String slotLabel;
  final SaveGameData? data;

  bool get hasSave => data != null;
}

class SaveGameService {
  static const int maxSlots = 4;
  static const String defaultQuickSaveSlotId = 'slot_1';
  static String? _lastSaveError;

  static String? get lastSaveError => _lastSaveError;

  static String slotIdForIndex(int index) => 'slot_${index + 1}';

  static String slotLabelFromId(String id) {
    final match = RegExp(r'^slot_(\d+)$').firstMatch(id);
    if (match == null) return id;
    return 'Slot ${match.group(1)}';
  }

  static List<String> allSlotIds() =>
      List<String>.generate(maxSlots, slotIdForIndex, growable: false);

  static String _saveKeyForSlot(String id) => 'save_$id';

  static Future<SharedPreferences?> _prefsSafe() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('SaveGameService: failed to initialize prefs: $e');
      return null;
    }
  }

  static Future<List<SaveGameData>> listSaves() async {
    final slots = await listSlots();
    return slots
        .where((s) => s.data != null)
        .map((s) => s.data!)
        .toList(growable: false);
  }

  static Future<List<SaveSlotEntry>> listSlots() async {
    final prefs = await _prefsSafe();
    if (prefs == null) {
      return allSlotIds()
          .map(
            (id) => SaveSlotEntry(
              slotId: id,
              slotLabel: slotLabelFromId(id),
              data: null,
            ),
          )
          .toList(growable: false);
    }

    final entries = <SaveSlotEntry>[];
    for (final id in allSlotIds()) {
      final data = await loadById(id);
      entries.add(
        SaveSlotEntry(slotId: id, slotLabel: slotLabelFromId(id), data: data),
      );
    }
    return entries;
  }

  static Future<SaveGameData?> loadById(String id) async {
    final prefs = await _prefsSafe();
    if (prefs == null) {
      return null;
    }

    final raw = prefs.getString(_saveKeyForSlot(id));
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return SaveGameData.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> saveToSlot(VoidRelayGame game, String slotId) async {
    _lastSaveError = null;

    if (!allSlotIds().contains(slotId)) {
      _lastSaveError = 'invalid slot id: $slotId';
      debugPrint('SaveGameService: $_lastSaveError');
      return false;
    }

    final world = game.gameWorld;
    if (world == null) {
      _lastSaveError = 'game world is not ready';
      debugPrint('SaveGameService: $_lastSaveError');
      return false;
    }

    final prefs = await _prefsSafe();
    if (prefs == null) {
      _lastSaveError = 'storage is unavailable';
      debugPrint('SaveGameService: $_lastSaveError');
      return false;
    }

    try {
      final player = world.player;
      final now = DateTime.now().toUtc();

      String? thumbnailBase64;
      try {
        final imageBytes = await game.captureGameplayThumbnailPng();
        thumbnailBase64 = imageBytes == null ? null : base64Encode(imageBytes);
      } catch (thumbError) {
        // Thumbnail is optional: never fail save if screenshot capture fails.
        debugPrint('SaveGameService: thumbnail capture skipped: $thumbError');
        thumbnailBase64 = null;
      }

      final save = SaveGameData(
        slotId: slotId,
        levelId: 'room_${game.currentRoomIndex + 1}',
        playerX: player.position.x,
        playerY: player.position.y,
        playerHp: player.health.round(),
        currentWeapon: player.currentWeapon.name,
        playerFacingDirection: player.facingDirection,
        playerIsGrounded: player.isOnGround,
        savedAtIso: now.toIso8601String(),
        thumbnailBase64: thumbnailBase64,
        playerMaxHp: player.maxHealth.round(),
        playerMaxHealthBonus: game.playerMaxHealthBonus,
        score: game.score,
        worldState: world.captureSaveState(),
        hazardState: game.hazardSystem?.captureSaveState(),
      );

      if (kDebugMode) {
        debugPrint('[SAVE] score=${game.score}');
        debugPrint('[SAVE] level=${game.currentLevel}');
      }

      final stored = await prefs.setString(
        _saveKeyForSlot(slotId),
        jsonEncode(save.toJson()),
      );
      if (!stored) {
        _lastSaveError = 'storage refused to write save data';
        debugPrint('SaveGameService: $_lastSaveError');
      }
      return stored;
    } catch (e) {
      _lastSaveError = e.toString();
      debugPrint('SaveGameService: saveToSlot failed: $e');
      return false;
    }
  }

  static Future<bool> saveFromGame(VoidRelayGame game) {
    return saveToSlot(game, defaultQuickSaveSlotId);
  }

  static Future<void> deleteSlot(String slotId) async {
    final prefs = await _prefsSafe();
    if (prefs == null) {
      return;
    }

    try {
      await prefs.remove(_saveKeyForSlot(slotId));
    } catch (e) {
      debugPrint('SaveGameService: deleteSlot failed: $e');
    }
  }

  static WeaponType weaponTypeFromName(String value) {
    switch (value) {
      case 'sniperGun':
        return WeaponType.sniperGun;
      case 'autoGun':
      default:
        return WeaponType.autoGun;
    }
  }
}
