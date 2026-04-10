import 'package:flutter_test/flutter_test.dart';
import 'package:void_relay/config/game_config.dart';
import 'package:void_relay/player/player_component.dart';

void main() {
  group('Player double jump', () {
    test('allows one extra jump in air and blocks third jump', () async {
      final player = PlayerComponent();
      await player.onLoad();

      player.isOnGround = true;
      player.jump();
      expect(player.velocity.y, GameConfig.playerJumpForce);
      expect(player.isOnGround, isFalse);

      // Simulate falling before second jump.
      player.velocity.y = 120.0;
      player.jump();
      expect(player.velocity.y, GameConfig.playerJumpForce);

      // Third jump in the same air phase must be blocked.
      player.velocity.y = 180.0;
      player.jump();
      expect(player.velocity.y, 180.0);
    });

    test('landing resets jump budget', () async {
      final player = PlayerComponent();
      await player.onLoad();

      player.isOnGround = true;
      player.jump();
      player.velocity.y = 90.0;
      player.jump();

      // Simulate landing and ensure jump is available again.
      player.land();
      player.velocity.y = 40.0;
      player.jump();
      expect(player.velocity.y, GameConfig.playerJumpForce);
    });
  });
}
