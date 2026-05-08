import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.score,
    required this.level,
    required this.savedAtIso,
  });

  final int score;
  final int level;
  final String savedAtIso;

  Map<String, dynamic> toJson() => {
    'score': score,
    'level': level,
    'savedAtIso': savedAtIso,
  };

  static LeaderboardEntry? fromJson(Map<String, dynamic> json) {
    final score = json['score'];
    final level = json['level'];
    final savedAtIso = json['savedAtIso'];
    if (score is! num || level is! num || savedAtIso is! String) {
      return null;
    }
    return LeaderboardEntry(
      score: score.toInt(),
      level: level.toInt(),
      savedAtIso: savedAtIso,
    );
  }
}

class LeaderboardService {
  static const String _storageKey = 'leaderboard_entries_v1';

  static Future<List<LeaderboardEntry>> listEntries({int limit = 20}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      if (kDebugMode) {
        debugPrint('[LEADERBOARD] loaded entries=0');
      }
      return const <LeaderboardEntry>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <LeaderboardEntry>[];
      }
      final entries =
          decoded
              .whereType<Map>()
              .map(
                (e) => LeaderboardEntry.fromJson(Map<String, dynamic>.from(e)),
              )
              .whereType<LeaderboardEntry>()
              .toList(growable: false)
            ..sort((a, b) => b.score.compareTo(a.score));
      final result = entries.take(limit).toList(growable: false);
      if (kDebugMode) {
        debugPrint('[LEADERBOARD] loaded entries=${result.length}');
      }
      return result;
    } catch (_) {
      return const <LeaderboardEntry>[];
    }
  }

  static Future<void> addEntry({required int score, required int level}) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await listEntries(limit: 40);

    final now = DateTime.now().toUtc();
    final newEntry = LeaderboardEntry(
      score: score,
      level: level,
      savedAtIso: now.toIso8601String(),
    );

    // De-dup near-identical consecutive result.
    if (existing.isNotEmpty) {
      final top = existing.first;
      if (top.score == newEntry.score && top.level == newEntry.level) {
        final topTime = DateTime.tryParse(top.savedAtIso);
        if (topTime != null && now.difference(topTime).inSeconds < 30) {
          return;
        }
      }
    }

    final merged = <LeaderboardEntry>[newEntry, ...existing]
      ..sort((a, b) => b.score.compareTo(a.score));
    final trimmed = merged.take(20).toList(growable: false);

    await prefs.setString(
      _storageKey,
      jsonEncode(trimmed.map((e) => e.toJson()).toList(growable: false)),
    );

    if (kDebugMode) {
      debugPrint('[LEADERBOARD] added score=$score at=${newEntry.savedAtIso}');
    }
  }
}
