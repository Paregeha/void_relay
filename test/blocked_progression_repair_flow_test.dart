import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:void_relay/config/game_config.dart';
import 'package:void_relay/systems/hazard_system.dart';
import 'package:void_relay/world/interactive/repair_terminal.dart';

void main() {
  group('Blocked progression repair flow (MVP integration-style)', () {
    test('door starts locked, repair resolves lock, door becomes unlocked', () {
      final doorFailure = DoorFailureEvent();

      bool isDoorLocked() => doorFailure.isActive;

      // 1) Door starts locked (blocking progression)
      expect(isDoorLocked(), isTrue);

      final terminal = RepairTerminal(
        position: Vector2.zero(),
        onRepairCompleted: () {
          // Integration point: repair interaction resolves door failure.
          doorFailure.markResolved();
        },
      );

      // 2) Run a simple repair interaction flow
      expect(terminal.canStartRepair, isTrue);
      terminal.startRepair();
      expect(terminal.isRepairing, isTrue);

      terminal.update(GameConfig.doorRepairDuration + 0.01);

      // 3) Door becomes unlocked after repair completion
      expect(terminal.isRepaired, isTrue);
      expect(isDoorLocked(), isFalse);
    });
  });
}
