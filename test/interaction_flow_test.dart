import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:void_relay/config/game_config.dart';
import 'package:void_relay/systems/interaction_system.dart';
import 'package:void_relay/world/interactive/repair_terminal.dart';

void main() {
  group('MVP interaction flow', () {
    test('repair terminal succeeds under valid conditions', () {
      var completionCount = 0;
      final terminal = RepairTerminal(
        position: Vector2.zero(),
        onRepairCompleted: () => completionCount++,
      );

      expect(terminal.canStartRepair, isTrue);

      terminal.startRepair();
      expect(terminal.isRepairing, isTrue);

      terminal.update(GameConfig.doorRepairDuration + 0.01);

      expect(terminal.isRepairing, isFalse);
      expect(terminal.isRepaired, isTrue);
      expect(completionCount, 1);
    });

    test('repair terminal ignores invalid repeated start while repairing', () {
      var completionCount = 0;
      final terminal = RepairTerminal(
        position: Vector2.zero(),
        onRepairCompleted: () => completionCount++,
      );

      terminal.startRepair();
      terminal.update(GameConfig.doorRepairDuration * 0.6);

      // Invalid interaction: start again while already repairing.
      terminal.startRepair();
      terminal.update(GameConfig.doorRepairDuration * 0.41);

      expect(completionCount, 1);
      expect(terminal.isRepairing, isFalse);
      expect(terminal.isRepaired, isTrue);
    });

    test('blocked interaction binding stays disabled', () {
      final blockedBinding = InteractionBinding(
        component: PositionComponent(position: Vector2.zero()),
        interactionRange: 64,
        onInteract: (_) {},
        isEnabled: () => false,
      );

      final allowedBinding = InteractionBinding(
        component: PositionComponent(position: Vector2.zero()),
        interactionRange: 64,
        onInteract: (_) {},
        isEnabled: () => true,
      );

      expect(blockedBinding.enabled, isFalse);
      expect(allowedBinding.enabled, isTrue);
    });
  });
}
