import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

Future<VoidRelayGame> _pumpGame(WidgetTester tester) async {
  final game = VoidRelayGame();
  await tester.pumpWidget(_buildHarness(game));
  await tester.pump(const Duration(milliseconds: 300));
  return game;
}

void main() {
  group('Keyboard bindings smoke', () {
    testWidgets('app-level hotkeys are disabled', (tester) async {
      final game = await _pumpGame(tester);

      expect(game.handleAppInputKey(LogicalKeyboardKey.escape), isFalse);
      expect(game.handleAppInputKey(LogicalKeyboardKey.keyP), isFalse);
      expect(game.handleAppInputKey(LogicalKeyboardKey.keyN), isFalse);
      expect(game.handleAppInputKey(LogicalKeyboardKey.keyG), isFalse);
      expect(game.handleAppInputKey(LogicalKeyboardKey.keyB), isFalse);
      expect(game.handleAppInputKey(LogicalKeyboardKey.keyT), isFalse);
      expect(game.handleAppInputKey(LogicalKeyboardKey.keyL), isFalse);
      expect(game.handleAppInputKey(LogicalKeyboardKey.keyY), isFalse);
      expect(game.handleAppInputKey(LogicalKeyboardKey.keyR), isFalse);
      expect(game.handleAppInputKey(LogicalKeyboardKey.keyU), isFalse);
    });

    testWidgets('context UI keys are disabled in app-level router', (
      tester,
    ) async {
      final game = await _pumpGame(tester);

      game.openMainMenu();
      await tester.pump();
      expect(game.handleAppInputKey(LogicalKeyboardKey.enter), isFalse);

      game.uiManager.showReward(game);
      await tester.pump();
      expect(game.handleAppInputKey(LogicalKeyboardKey.digit1), isFalse);

      game.uiManager.showReward(game);
      await tester.pump();
      expect(game.handleAppInputKey(LogicalKeyboardKey.digit2), isFalse);
    });

    testWidgets('gameplay keys are not consumed by app-level router', (
      tester,
    ) async {
      final game = await _pumpGame(tester);

      // These keys must remain available for gameplay systems:
      // A/D/Left/Right move, Space jump, F fire,
      // E interact, C/X and 1/2 weapon switching.
      expect(game.handleAppInputKey(LogicalKeyboardKey.keyA), isFalse);
      expect(game.handleAppInputKey(LogicalKeyboardKey.keyD), isFalse);
      expect(game.handleAppInputKey(LogicalKeyboardKey.arrowLeft), isFalse);
      expect(game.handleAppInputKey(LogicalKeyboardKey.arrowRight), isFalse);
      expect(game.handleAppInputKey(LogicalKeyboardKey.space), isFalse);
      expect(game.handleAppInputKey(LogicalKeyboardKey.keyF), isFalse);
      expect(game.handleAppInputKey(LogicalKeyboardKey.keyE), isFalse);
      expect(game.handleAppInputKey(LogicalKeyboardKey.keyC), isFalse);
      expect(game.handleAppInputKey(LogicalKeyboardKey.keyX), isFalse);

      // In normal gameplay, app-level layer does not consume 1/2.
      expect(game.handleAppInputKey(LogicalKeyboardKey.digit1), isFalse);
      expect(game.handleAppInputKey(LogicalKeyboardKey.digit2), isFalse);
    });
  });
}
