import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:void_relay/core/bloc/events/heat_event.dart';
import 'package:void_relay/core/bloc/states/heat_state.dart';
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
  group('Overheat -> game over -> restart regression', () {
    testWidgets('overheat opens game over and restart resets gameplay state', (
      tester,
    ) async {
      final game = VoidRelayGame();
      await tester.pumpWidget(_buildHarness(game));
      await tester.pump(const Duration(milliseconds: 300));

      final worldBeforeRestart = game.gameWorld;
      expect(worldBeforeRestart, isNotNull);
      expect(game.heatBloc?.state, isNot(isA<HeatOverheated>()));

      // Force deterministic overheat.
      game.heatBloc?.add(const HeatOverheatEvent());
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      expect(game.heatBloc?.state, isA<HeatOverheated>());
      game.update(0.016);
      await tester.pump();

      expect(game.isGameOverOpen, isTrue);
      expect(game.isGameplayInputBlocked, isTrue);

      // Ensure restart actually resets room/heat and rebuilds world.
      game.currentRoomIndex = 3;
      game.resetAfterGameOver();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      expect(game.isGameOverOpen, isFalse);
      expect(game.currentRoomIndex, 0);
      expect(game.heatBloc?.state.currentHeat, 0.0);
      expect(game.heatBloc?.state, isNot(isA<HeatOverheated>()));
      expect(game.gameWorld, isNotNull);
      expect(identical(worldBeforeRestart, game.gameWorld), isFalse);
    });
  });
}
