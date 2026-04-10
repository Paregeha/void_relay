import 'player_state.dart';

class JumpingState implements PlayerState {
  @override
  void enter(dynamic player) {}

  @override
  void update(dynamic player, double dt) {
    // Дозволяємо горизонтальний рух у повітрі
    player.velocity.x = player.inputDirection * player.speed;
  }

  @override
  void exit(dynamic player) {}
}
