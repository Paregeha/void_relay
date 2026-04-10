import '../base_enemy.dart';
import '../../player/player_component.dart';

class CrawlerAI {
  String currentState = 'idle';
  int patrolDirection = 1;

  void update(BaseEnemy enemy, PlayerComponent player, double dt) {
    double distance = (player.position - enemy.position).length;
    if (distance < 100) {
      currentState = 'chase';
    } else if (currentState == 'idle') {
      currentState = 'patrol';
    } else if (currentState == 'patrol' && distance > 200) {
      currentState = 'idle';
    }

    switch (currentState) {
      case 'idle':
        enemy.velocity.x = 0;
        break;
      case 'patrol':
        enemy.velocity.x = patrolDirection * 50.0;
        if (enemy.position.x < 50) patrolDirection = 1;
        if (enemy.position.x > 590) patrolDirection = -1;
        break;
      case 'chase':
        int dir = player.position.x > enemy.position.x ? 1 : -1;
        enemy.velocity.x = dir * 60.0;
        break;
    }
  }
}
