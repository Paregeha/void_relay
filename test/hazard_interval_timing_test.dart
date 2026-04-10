import 'package:flutter_test/flutter_test.dart';
import 'package:void_relay/config/game_config.dart';
import 'package:void_relay/systems/hazard_system.dart';

void main() {
  group('Hazard timing and interval rules', () {
    test('blackout event respects configured duration timing', () {
      final event = BlackoutEvent(duration: 2.0);

      expect(event.isActive, isTrue);

      event.updateTime(1.9);
      expect(event.isActive, isTrue);

      event.updateTime(0.2);
      expect(event.isActive, isFalse);
    });

    test('door failure stays active until resolved (manual flow)', () {
      final event = DoorFailureEvent();

      expect(event.requiresManualResolve, isTrue);
      expect(event.isActive, isTrue);

      event.updateTime(999);
      expect(event.isActive, isTrue);

      event.markResolved();
      expect(event.isActive, isFalse);
    });

    test('system breakdown stays active until resolved (manual flow)', () {
      final event = SystemBreakdownEvent();

      expect(event.requiresManualResolve, isTrue);
      expect(event.isActive, isTrue);

      event.updateTime(120);
      expect(event.isActive, isTrue);

      event.markResolved();
      expect(event.isActive, isFalse);
    });

    test('trigger interval decreases by sector risk and clamps to minimum', () {
      double effectiveInterval(int sectorRiskLevel) {
        final reduced =
            GameConfig.timeBetweenHazardEvents -
            sectorRiskLevel * GameConfig.hazardIntervalReductionPerSector;
        return reduced < GameConfig.hazardMinInterval
            ? GameConfig.hazardMinInterval
            : reduced;
      }

      final sector0 = effectiveInterval(0);
      final sector2 = effectiveInterval(2);
      final sectorHigh = effectiveInterval(99);

      expect(sector0, GameConfig.timeBetweenHazardEvents);
      expect(sector2, lessThan(sector0));
      expect(sectorHigh, GameConfig.hazardMinInterval);
    });
  });
}
