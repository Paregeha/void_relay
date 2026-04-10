import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:void_relay/flame_game.dart';
import 'package:void_relay/ui/ui_manager.dart';
import 'package:void_relay/world/room/room_types.dart';

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
  group('Room flow + transition reason integration', () {
    testWidgets('does not auto-open transition on fresh room load', (
      tester,
    ) async {
      final game = VoidRelayGame();
      await tester.pumpWidget(_buildHarness(game));
      await tester.pump(const Duration(milliseconds: 400));

      expect(game.isTransitionOpen, isFalse);
      expect(game.currentRoomIndex, 0);
    });

    testWidgets('room types are preserved across sector flow', (tester) async {
      final game = VoidRelayGame();
      await tester.pumpWidget(_buildHarness(game));
      await tester.pump(const Duration(milliseconds: 300));

      // Sector 0 room types
      expect(game.currentRoomIndex, 0);
      expect(game.gameWorld, isNotNull);
      expect(game.gameWorld!.hasRoomType(RoomType.cooling), isTrue);
      expect(game.gameWorld!.hasRoomType(RoomType.hazard), isFalse);

      // Transition reason/state
      game.triggerSectorTransition('Relay reached');
      await tester.pump();
      expect(game.isTransitionOpen, isTrue);
      expect(
        const {'Relay reached', 'Room cleared'}.contains(game.transitionReason),
        isTrue,
      );

      // Complete transition and verify next room type profile
      game.completeSectorTransition();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(game.currentRoomIndex, 1);
      expect(game.gameWorld, isNotNull);
      expect(game.gameWorld!.hasRoomType(RoomType.hazard), isTrue);
      expect(game.gameWorld!.hasRoomType(RoomType.cooling), isFalse);
    });
  });
}
