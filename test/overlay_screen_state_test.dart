import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:void_relay/flame_game.dart';
import 'package:void_relay/ui/screens/game_over_screen.dart';
import 'package:void_relay/ui/screens/pause_screen.dart';
import 'package:void_relay/ui/screens/sector_transition_screen.dart';
import 'package:void_relay/ui/ui_manager.dart';

Widget _buildHarness(VoidRelayGame game) {
  return MaterialApp(
    home: GameWidget<VoidRelayGame>(
      game: game,
      overlayBuilderMap: {
        UiManager.mainMenuOverlay: (_, __) => const SizedBox.shrink(),
        UiManager.hudOverlay: (_, __) => const SizedBox.shrink(),
        UiManager.rewardOverlay: (_, __) => const SizedBox.shrink(),
        UiManager.pauseOverlay: (_, game) => PauseScreen(
          onResume: game.resumeFromPause,
          onExit: game.resumeFromPause,
        ),
        UiManager.gameOverOverlay: (_, game) =>
            GameOverScreen(onRestart: game.resetAfterGameOver),
        UiManager.transitionOverlay: (_, game) => SectorTransitionScreen(
          onContinue: game.completeSectorTransition,
          currentSectorNumber: game.currentRoomIndex + 1,
          nextSectorNumber: game.currentRoomIndex + 2,
          transitionReason: game.transitionReason,
        ),
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

      expect(find.byType(PauseScreen), findsOneWidget);
    });

    testWidgets('game over screen opens in game over state', (tester) async {
      final game = VoidRelayGame();
      await tester.pumpWidget(_buildHarness(game));
      await tester.pump(const Duration(milliseconds: 250));

      game.triggerGameOver();
      await tester.pump();

      expect(game.isGameOverOpen, isTrue);
      expect(find.byType(GameOverScreen), findsOneWidget);
    });

    testWidgets('transition screen opens in transition state', (tester) async {
      final game = VoidRelayGame();
      await tester.pumpWidget(_buildHarness(game));
      await tester.pump(const Duration(milliseconds: 250));

      game.triggerSectorTransition('Room cleared');
      await tester.pump();

      expect(game.isTransitionOpen, isTrue);
      expect(find.byType(SectorTransitionScreen), findsOneWidget);
    });
  });
}
