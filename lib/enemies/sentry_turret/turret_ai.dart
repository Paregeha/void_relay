import '../base_enemy.dart';
import '../../player/player_component.dart';

class TurretAI {
  static const double detectionRange = 150.0;

  void update(BaseEnemy enemy, PlayerComponent player, double dt) {
    double distance = (player.position - enemy.position).length;
    if (distance < detectionRange) {
      enemy.onPlayerDetected();
    }
  }
}
