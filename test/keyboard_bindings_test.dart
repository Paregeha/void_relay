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
    testWidgets('app-level hotkeys are handled by handleAppInputKey', (
      tester,
    ) async {
      final game = await _pumpGame(tester);

      expect(game.handleAppInputKey(LogicalKeyboardKey.escape), isTrue);
      expect(game.handleAppInputKey(LogicalKeyboardKey.keyP), isTrue);
      expect(game.handleAppInputKey(LogicalKeyboardKey.keyN), isTrue);
      expect(game.handleAppInputKey(LogicalKeyboardKey.keyG), isTrue);
      expect(game.handleAppInputKey(LogicalKeyboardKey.keyB), isTrue);
      expect(game.handleAppInputKey(LogicalKeyboardKey.keyT), isTrue);
      expect(game.handleAppInputKey(LogicalKeyboardKey.keyL), isTrue);
      expect(game.handleAppInputKey(LogicalKeyboardKey.keyY), isTrue);
      expect(game.handleAppInputKey(LogicalKeyboardKey.keyR), isTrue);
      expect(game.handleAppInputKey(LogicalKeyboardKey.keyU), isTrue);
    });

    testWidgets('context keys are handled in valid UI states', (tester) async {
      final game = await _pumpGame(tester);

      game.openMainMenu();
      await tester.pump();
      expect(game.handleAppInputKey(LogicalKeyboardKey.enter), isTrue);

      game.uiManager.showReward(game);
      await tester.pump();
      expect(game.handleAppInputKey(LogicalKeyboardKey.digit1), isTrue);

      game.uiManager.showReward(game);
      await tester.pump();
      expect(game.handleAppInputKey(LogicalKeyboardKey.digit2), isTrue);
    });

    testWidgets('gameplay keys are not consumed by app-level router', (
      tester,
    ) async {
      final game = await _pumpGame(tester);

      // These keys must remain available for gameplay systems:
      // A/D/Left/Right move, Space jump, Shift dash, F fire,
      // E interact, C/X and 1/2 weapon switching.
      expect(game.handleAppInputKey(LogicalKeyboardKey.keyA), isFalse);
      expect(game.handleAppInputKey(LogicalKeyboardKey.keyD), isFalse);
      expect(game.handleAppInputKey(LogicalKeyboardKey.arrowLeft), isFalse);
      expect(game.handleAppInputKey(LogicalKeyboardKey.arrowRight), isFalse);
      expect(game.handleAppInputKey(LogicalKeyboardKey.space), isFalse);
      expect(game.handleAppInputKey(LogicalKeyboardKey.shiftLeft), isFalse);
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
