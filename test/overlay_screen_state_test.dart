import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:void_relay/flame_game.dart';
import 'package:void_relay/ui/ui_manager.dart';

Widget _buildHarness(VoidRelayGame game) {
  return MaterialApp(
    home: GameWidget<VoidRelayGame>(
      game: game,
      overlayBuilderMap: {
        UiManager.mainMenuOverlay: (_, __) => const SizedBox.shrink(),
        UiManager.hudOverlay: (_, __) => const SizedBox.shrink(),
        UiManager.rewardOverlay: (_, __) => const SizedBox.shrink(),
        UiManager.pauseOverlay: (_, __) => const SizedBox.shrink(),
        UiManager.gameOverOverlay: (_, __) => const SizedBox.shrink(),
        UiManager.transitionOverlay: (_, __) => const SizedBox.shrink(),
      },
      initialActiveOverlays: const [UiManager.hudOverlay],
    ),
  );
}

void main() {
  group('Overlay screen states', () {
    testWidgets('pause screen opens in pause state', (tester) async {
      final game = VoidRelayGame();
      await tester.pumpWidget(_buildHarness(game));
      await tester.pump(const Duration(milliseconds: 250));

      game.uiManager.showPause(game);
      await tester.pump();

      expect(game.isPauseOpen, isTrue);
      expect(game.overlays.isActive(UiManager.pauseOverlay), isTrue);
    });

    testWidgets('game over screen opens in game over state', (tester) async {
      final game = VoidRelayGame();
      await tester.pumpWidget(_buildHarness(game));
      await tester.pump(const Duration(milliseconds: 250));

      game.triggerGameOver();
      await tester.pump();

      expect(game.isGameOverOpen, isTrue);
      expect(game.overlays.isActive(UiManager.gameOverOverlay), isTrue);
    });

    testWidgets('transition screen opens in transition state', (tester) async {
      final game = VoidRelayGame();
      await tester.pumpWidget(_buildHarness(game));
      await tester.pump(const Duration(milliseconds: 250));

      game.triggerSectorTransition('Room cleared');
      await tester.pump();

      expect(game.isTransitionOpen, isTrue);
      expect(game.overlays.isActive(UiManager.transitionOverlay), isTrue);
    });
  });
}
