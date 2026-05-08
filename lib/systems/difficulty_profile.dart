class DifficultyProfile {
  const DifficultyProfile({
    required this.level,
    required this.difficultyScore,
    required this.enemyCount,
    required this.enemySpeedMultiplier,
    required this.enemyHpMultiplier,
    required this.enemyDamageMultiplier,
    required this.turretChance,
    required this.droneChance,
    required this.enemy3Chance,
    required this.coolingPickupChance,
    required this.healthPickupChance,
    required this.hazardChance,
    required this.platformGapMultiplier,
  });

  final int level;
  final double difficultyScore;
  final int enemyCount;
  final double enemySpeedMultiplier;
  final double enemyHpMultiplier;
  final double enemyDamageMultiplier;
  final double turretChance;
  final double droneChance;
  final double enemy3Chance;
  final double coolingPickupChance;
  final double healthPickupChance;
  final double hazardChance;
  final double platformGapMultiplier;

  static const DifficultyProfile baseline = DifficultyProfile(
    level: 1,
    difficultyScore: 1.0,
    enemyCount: 5,
    enemySpeedMultiplier: 1.0,
    enemyHpMultiplier: 1.0,
    enemyDamageMultiplier: 1.0,
    turretChance: 0.22,
    droneChance: 0.34,
    enemy3Chance: 0.44,
    coolingPickupChance: 0.85,
    healthPickupChance: 0.35,
    hazardChance: 0.25,
    platformGapMultiplier: 1.0,
  );
}
