import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:void_relay/config/game_config.dart';
import 'package:void_relay/enemies/base_enemy.dart';
import 'package:void_relay/enemies/hover_drone/hover_drone_ai.dart';
import 'package:void_relay/player/player_component.dart';

void main() {
  group('HoverDroneAI directional-shot behavior', () {
    test('canShoot stays true when player is in detection range', () {
      final ai = HoverDroneAI();
      final enemy = BaseEnemy()..position = Vector2(100, 100);
      final player = PlayerComponent()..position = Vector2(220, 110);

      ai.update(enemy, player, 0.016);

      expect(ai.distanceToPlayer <= GameConfig.droneDetectionRange, isTrue);
      expect(ai.facingRight, isTrue);
      expect(ai.canShoot, isTrue);
    });

    test('still allows shooting when vertical difference is large', () {
      final ai = HoverDroneAI();
      final enemy = BaseEnemy()..position = Vector2(100, 100);
      final player = PlayerComponent()
        ..position = Vector2(
          220,
          100 + GameConfig.droneShootVerticalTolerance + 80,
        );

      ai.update(enemy, player, 0.016);

      expect(ai.canShoot, isTrue);
    });

    test('does not retreat when player is very close', () {
      final ai = HoverDroneAI();
      final enemy = BaseEnemy()..position = Vector2(200, 100);
      final player = PlayerComponent()..position = Vector2(210, 100);

      ai.update(enemy, player, 0.016);

      expect(ai.facingRight, isTrue);
      expect(ai.movementState, HoverDroneAiState.holdDistance);
    });
  });
}
