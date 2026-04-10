import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:void_relay/config/game_config.dart';
import 'package:void_relay/flame_game.dart';
import 'package:void_relay/ui/game_hud.dart';
import 'package:void_relay/ui/screens/game_over_screen.dart';
import 'package:void_relay/ui/ui_manager.dart';

Widget _buildHarness(VoidRelayGame game) {
  return MaterialApp(
    home: GameWidget<VoidRelayGame>(
      game: game,
      overlayBuilderMap: {
        UiManager.mainMenuOverlay: (_, __) => const SizedBox.shrink(),
        UiManager.hudOverlay: (_, g) => GameHud(game: g),
        UiManager.rewardOverlay: (_, __) => const SizedBox.shrink(),
        UiManager.pauseOverlay: (_, __) => const SizedBox.shrink(),
        UiManager.gameOverOverlay: (_, g) =>
            GameOverScreen(onRestart: g.resetAfterGameOver),
        UiManager.transitionOverlay: (_, __) => const SizedBox.shrink(),
      },
      initialActiveOverlays: const [UiManager.hudOverlay],
    ),
  );
}

void main() {
  group('Player death flow', () {
    testWidgets('HP zero starts one-time death sequence then opens game over', (
      tester,
    ) async {
      final game = VoidRelayGame();
      await tester.pumpWidget(_buildHarness(game));
      await tester.pump(const Duration(milliseconds: 300));

      final player = game.gameWorld!.player;
      player.takeDamage(player.maxHealth);
      await tester.pump();

      expect(player.isDying, isTrue);
      expect(game.isDeathSequenceActive, isTrue);
      expect(game.isGameOverOpen, isFalse);
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.text('YOU DIE'), findsOneWidget);

      final deathDurationMs = (GameConfig.playerDeathSequenceDuration * 1000)
          .round();
      const alreadyWaitedMs = 120;
      const safetyFrameMs = 120;
      final beforeGameOverWaitMs =
          deathDurationMs - alreadyWaitedMs - safetyFrameMs;

      // Repeated damage after death trigger must not restart death sequence.
      player.takeDamage(10);
      await tester.pump(Duration(milliseconds: beforeGameOverWaitMs));
      expect(game.isDeathSequenceActive, isTrue);
      expect(game.isGameOverOpen, isFalse);

      var settleMs = 0;
      while (!game.isGameOverOpen && settleMs < 1500) {
        await tester.pump(const Duration(milliseconds: 100));
        settleMs += 100;
      }

      expect(game.isDeathSequenceActive, isFalse);
      expect(game.isGameOverOpen, isTrue);
      expect(player.isDead, isTrue);
      expect(find.text('GAME OVER'), findsOneWidget);
    });
  });
}
