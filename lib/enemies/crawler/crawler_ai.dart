import '../../player/player_component.dart';
import '../base_enemy.dart';

class CrawlerAI {
  String currentState = 'idle';
  int patrolDirection = 1;

  void update(BaseEnemy enemy, PlayerComponent player, double dt) {
    final horizontalDistance = (player.position.x - enemy.position.x).abs();
    final visualWidth = enemy.size.x;
    final crawlerHitboxWidth = enemy.toRect().width;
    final playerHitboxWidth = player.size.x;
    final attackRange = visualWidth * 0.55;
    final stopDistance = playerHitboxWidth / 2 + crawlerHitboxWidth / 2 + 4.0;
    final loseInterestDistance = attackRange * 1.75;

    if (horizontalDistance <= attackRange) {
      currentState = 'chase';
    } else if (currentState == 'idle') {
      currentState = 'patrol';
    } else if (currentState == 'patrol' && horizontalDistance > 200) {
      currentState = 'idle';
    } else if (currentState == 'chase' &&
        horizontalDistance > loseInterestDistance) {
      currentState = 'patrol';
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
        final dir = player.position.x > enemy.position.x ? 1 : -1;
        if (horizontalDistance <= stopDistance) {
          enemy.velocity.x = 0;
        } else {
          enemy.velocity.x = dir * 60.0;
        }
        break;
    }
  }
}
