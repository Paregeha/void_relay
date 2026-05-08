import 'package:flutter_test/flutter_test.dart';
import 'package:void_relay/systems/difficulty_director.dart';

void main() {
  group('DifficultyDirector', () {
    const director = DifficultyDirector();

    test('level 1 profile has baseline-friendly values', () {
      final profile = director.generateProfile(currentLevel: 1);

      expect(profile.level, 1);
      expect(profile.enemyCount, 5);
      expect(profile.enemySpeedMultiplier, 1.0);
      expect(profile.enemyHpMultiplier, 1.0);
      expect(profile.coolingPickupChance, closeTo(0.85, 0.0001));
      expect(profile.healthPickupChance, closeTo(0.35, 0.0001));
    });

    test('difficulty increases with level and stays clamped', () {
      final level2 = director.generateProfile(currentLevel: 2);
      final level10 = director.generateProfile(currentLevel: 10);
      final level100 = director.generateProfile(currentLevel: 100);

      expect(level10.enemyCount, greaterThan(level2.enemyCount));
      expect(
        level10.enemySpeedMultiplier,
        greaterThan(level2.enemySpeedMultiplier),
      );
      expect(level10.enemyHpMultiplier, greaterThan(level2.enemyHpMultiplier));

      expect(level100.coolingPickupChance, greaterThanOrEqualTo(0.20));
      expect(level100.healthPickupChance, greaterThanOrEqualTo(0.10));
      expect(level100.enemyCount, lessThanOrEqualTo(20));
      expect(level100.enemySpeedMultiplier, lessThanOrEqualTo(1.9));
      expect(level100.enemyHpMultiplier, lessThanOrEqualTo(3.2));
    });
  });
}
