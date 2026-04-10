import 'package:flutter_test/flutter_test.dart';
import 'package:void_relay/player/player_component.dart';

void main() {
  group('Player sprite sheet mapping', () {
    test('uses exact rows and columns per animation', () {
      final clips = PlayerComponent.spriteClips;

      expect(clips.length, 5);
      expect(clips.containsKey(PlayerAnimState.idle), isTrue);
      expect(clips.containsKey(PlayerAnimState.jump), isTrue);
      expect(clips.containsKey(PlayerAnimState.run), isTrue);
      expect(clips.containsKey(PlayerAnimState.gun), isTrue);
      expect(clips.containsKey(PlayerAnimState.death), isTrue);

      expect(clips[PlayerAnimState.idle]!.row, 0);
      expect(clips[PlayerAnimState.idle]!.columns, [0, 1, 2, 3]);

      expect(clips[PlayerAnimState.jump]!.row, 1);
      expect(clips[PlayerAnimState.jump]!.columns, [0, 1, 2]);

      expect(clips[PlayerAnimState.run]!.row, 2);
      expect(clips[PlayerAnimState.run]!.columns, [0, 1, 2, 3, 4, 5, 6]);

      expect(clips[PlayerAnimState.gun]!.row, 3);
      expect(clips[PlayerAnimState.gun]!.columns, [0, 1, 2]);

      expect(clips[PlayerAnimState.death]!.row, 4);
      expect(clips[PlayerAnimState.death]!.columns, [0, 1, 2]);
    });

    test('does not assume all rows use all 7 columns', () {
      final clips = PlayerComponent.spriteClips;

      expect(clips[PlayerAnimState.idle]!.columns.length, 4);
      expect(clips[PlayerAnimState.jump]!.columns.length, 3);
      expect(clips[PlayerAnimState.run]!.columns.length, 7);
      expect(clips[PlayerAnimState.gun]!.columns.length, 3);
      expect(clips[PlayerAnimState.death]!.columns.length, 3);
    });
  });
}
