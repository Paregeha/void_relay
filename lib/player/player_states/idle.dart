import 'player_state.dart';

class IdleState implements PlayerState {
  @override
  void enter(dynamic player) {}

  @override
  void update(dynamic player, double dt) {
    player.velocity.x = 0.0;
    if (player.inputDirection != 0) {
      player.changeToRunning();
    }
    if (player.wantJump && player.isOnGround) {
      player.velocity.y = player.jumpForce;
      player.isOnGround = false;
      player.changeToJumping();
    }
    if (player.wantDash && player.canDash) {
      player.changeToDashing();
    }
  }

  @override
  void exit(dynamic player) {}
}
