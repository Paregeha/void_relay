import 'player_state.dart';

class DashingState implements PlayerState {
  @override
  void enter(dynamic player) {
    final int dashDir = player.inputDirection != 0
        ? player.inputDirection
        : (player.velocity.x >= 0 ? 1 : -1);
    player.velocity.x += player.dashForce * dashDir;
    player.canDash = false;
    player.changeToJumping();
  }

  @override
  void update(dynamic player, double dt) {}

  @override
  void exit(dynamic player) {}
}
