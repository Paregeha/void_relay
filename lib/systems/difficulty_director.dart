import 'package:flutter/foundation.dart';

import 'difficulty_profile.dart';

class DifficultyDirector {
  const DifficultyDirector();

  DifficultyProfile generateProfile({required int currentLevel}) {
    final level = currentLevel < 1 ? 1 : currentLevel;
    final growth = (level - 1).toDouble();

    final profile = DifficultyProfile(
      level: level,
      difficultyScore: _clampDouble(1.0 + growth * 0.24, 1.0, 4.2),
      enemyCount: _clampInt(5 + (growth * 0.9).floor(), 5, 20),
      enemySpeedMultiplier: _clampDouble(1.0 + growth * 0.05, 1.0, 1.9),
      enemyHpMultiplier: _clampDouble(1.0 + growth * 0.1, 1.0, 3.2),
      enemyDamageMultiplier: _clampDouble(1.0 + growth * 0.08, 1.0, 2.6),
      turretChance: _clampDouble(0.22 + growth * 0.025, 0.22, 0.58),
      droneChance: _clampDouble(0.34 + growth * 0.02, 0.34, 0.62),
      enemy3Chance: _clampDouble(0.44 - growth * 0.02, 0.18, 0.44),
      coolingPickupChance: _clampDouble(0.85 - growth * 0.055, 0.20, 0.85),
      healthPickupChance: _clampDouble(0.35 - growth * 0.022, 0.10, 0.35),
      hazardChance: _clampDouble(0.25 + growth * 0.045, 0.25, 0.92),
      platformGapMultiplier: _clampDouble(1.0 + growth * 0.05, 1.0, 1.45),
    );

    debugPrint('[DIFFICULTY] level=${profile.level}');
    debugPrint('[DIFFICULTY] enemyCount=${profile.enemyCount}');
    debugPrint(
      '[DIFFICULTY] hpMultiplier=${profile.enemyHpMultiplier.toStringAsFixed(2)}',
    );
    debugPrint(
      '[DIFFICULTY] speedMultiplier=${profile.enemySpeedMultiplier.toStringAsFixed(2)}',
    );
    debugPrint(
      '[DIFFICULTY] turretChance=${profile.turretChance.toStringAsFixed(2)}',
    );
    debugPrint(
      '[DIFFICULTY] droneChance=${profile.droneChance.toStringAsFixed(2)}',
    );
    debugPrint(
      '[DIFFICULTY] coolingPickupChance=${profile.coolingPickupChance.toStringAsFixed(2)}',
    );
    debugPrint(
      '[DIFFICULTY] healthPickupChance=${profile.healthPickupChance.toStringAsFixed(2)}',
    );

    return profile;
  }

  static int _clampInt(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  static double _clampDouble(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}
