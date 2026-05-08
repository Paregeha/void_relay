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
        UiManager.firstTimePromptOverlay: (_, __) => const SizedBox.shrink(),
        UiManager.firstTimeInstructionOverlay: (_, __) =>
            const SizedBox.shrink(),
      },
      initialActiveOverlays: const [
        UiManager.hudOverlay,
        UiManager.mainMenuOverlay,
      ],
    ),
  );
}

void main() {
  group('New game onboarding flow', () {
    testWidgets('shows first-time prompt from main menu', (tester) async {
      final game = VoidRelayGame();
      await tester.pumpWidget(_buildHarness(game));
      await tester.pump(const Duration(milliseconds: 250));

      game.openNewGameFirstTimePrompt();
      await tester.pump();

      expect(game.overlays.isActive(UiManager.firstTimePromptOverlay), isTrue);
      expect(game.isFirstTimePromptOpen, isTrue);
    });

    testWidgets('yes path opens instruction overlay', (tester) async {
      final game = VoidRelayGame();
      await tester.pumpWidget(_buildHarness(game));
      await tester.pump(const Duration(milliseconds: 250));

      game.openNewGameFirstTimePrompt();
      await tester.pump();
      await game.confirmNewGameFirstTimeSelection(isFirstTime: true);
      await tester.pump();

      expect(game.overlays.isActive(UiManager.mainMenuOverlay), isFalse);
      expect(game.overlays.isActive(UiManager.hudOverlay), isTrue);
      expect(
        game.overlays.isActive(UiManager.firstTimeInstructionOverlay),
        isTrue,
      );

      game.closeFirstTimeInstruction();
      await tester.pump();
      expect(
        game.overlays.isActive(UiManager.firstTimeInstructionOverlay),
        isFalse,
      );
    });

    testWidgets('no path starts without instruction overlay', (tester) async {
      final game = VoidRelayGame();
      await tester.pumpWidget(_buildHarness(game));
      await tester.pump(const Duration(milliseconds: 250));

      game.openNewGameFirstTimePrompt();
      await tester.pump();
      await game.confirmNewGameFirstTimeSelection(isFirstTime: false);
      await tester.pump();

      expect(game.overlays.isActive(UiManager.mainMenuOverlay), isFalse);
      expect(game.overlays.isActive(UiManager.hudOverlay), isTrue);
      expect(
        game.overlays.isActive(UiManager.firstTimeInstructionOverlay),
        isFalse,
      );
    });
  });
}
