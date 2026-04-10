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
        UiManager.hudOverlay: (_, __) => const SizedBox.shrink(),
        UiManager.pauseOverlay: (_, __) => const SizedBox.shrink(),
        UiManager.gameOverOverlay: (_, __) => const SizedBox.shrink(),
        UiManager.transitionOverlay: (_, __) => const SizedBox.shrink(),
      },
      initialActiveOverlays: const [UiManager.hudOverlay],
    ),
  );
}

void main() {
  group('Sector transition smoke', () {
    testWidgets('transition starts and blocks gameplay input', (tester) async {
      final game = VoidRelayGame();
      await tester.pumpWidget(_buildHarness(game));

      game.triggerSectorTransition('Relay reached');
      await tester.pump();

      expect(game.isTransitionOpen, isTrue);
      expect(game.isGameplayInputBlocked, isTrue);
    });

    testWidgets('pause is ignored while transition is open', (tester) async {
      final game = VoidRelayGame();
      await tester.pumpWidget(_buildHarness(game));

      game.triggerSectorTransition();
      game.triggerPause();
      await tester.pump();

      expect(game.isTransitionOpen, isTrue);
      expect(game.overlays.isActive(UiManager.pauseOverlay), isFalse);
      expect(game.isGameplayInputBlocked, isTrue);
    });

    testWidgets('complete transition restores control state', (tester) async {
      final game = VoidRelayGame();
      await tester.pumpWidget(_buildHarness(game));

      expect(game.currentRoomIndex, 0);

      game.triggerSectorTransition('Room cleared');
      await tester.pump();
      game.completeSectorTransition();
      await tester.pump();

      expect(game.isTransitionOpen, isFalse);
      expect(game.isGameplayInputBlocked, isFalse);
      expect(game.currentRoomIndex, 1);
    });
  });
}
