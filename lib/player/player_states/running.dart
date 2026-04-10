import 'player_state.dart';

class RunningState implements PlayerState {
  @override
  void enter(dynamic player) {}

  @override
  void update(dynamic player, double dt) {
    player.velocity.x = player.inputDirection * player.speed;
    if (player.inputDirection == 0) {
      player.changeToIdle();
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
