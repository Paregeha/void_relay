import 'package:flutter_test/flutter_test.dart';
import 'package:void_relay/player/player_component.dart';
import 'package:void_relay/player/skeletal/player_animation_state.dart';

void main() {
  group('Player skeletal animation mapping', () {
    test('player gameplay states include procedural motion states', () {
      expect(PlayerAnimState.values, contains(PlayerAnimState.idle));
      expect(PlayerAnimState.values, contains(PlayerAnimState.run));
      expect(PlayerAnimState.values, contains(PlayerAnimState.jump));
      expect(PlayerAnimState.values, contains(PlayerAnimState.fall));
      expect(PlayerAnimState.values, contains(PlayerAnimState.dash));
      expect(PlayerAnimState.values, contains(PlayerAnimState.attack));
      expect(PlayerAnimState.values, contains(PlayerAnimState.death));
    });

    test('skeletal animation states match player visual requirements', () {
      expect(
        SkeletalPlayerAnimationState.values,
        equals([
          SkeletalPlayerAnimationState.idle,
          SkeletalPlayerAnimationState.run,
          SkeletalPlayerAnimationState.jump,
          SkeletalPlayerAnimationState.fall,
          SkeletalPlayerAnimationState.dash,
          SkeletalPlayerAnimationState.attack,
          SkeletalPlayerAnimationState.death,
        ]),
      );
    });
  });
}
