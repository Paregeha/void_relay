import 'dart:math';

import '../../player/player_component.dart';
import '../base_enemy.dart';

class HoverDroneAI {
  static const double chaseRange = 220.0;
  static const double disengageRange = 300.0;

  String currentState = 'idle';
  int patrolDirection = 1;
  double time = 0;

  void update(BaseEnemy enemy, PlayerComponent player, double dt) {
    time += dt;
    double distance = (player.position - enemy.position).length;
    if (distance < chaseRange) {
      currentState = 'chase';
    } else if (currentState == 'idle') {
      currentState = 'patrol';
    } else if (currentState == 'patrol' && distance > disengageRange) {
      currentState = 'idle';
    }

    switch (currentState) {
      case 'idle':
        enemy.velocity.x = 0;
        enemy.velocity.y = 0;
        break;
      case 'patrol':
        enemy.velocity.x = patrolDirection * 40.0;
        enemy.velocity.y = sin(time * 2) * 20; // slight up down
        if (enemy.position.x < 50) patrolDirection = 1;
        if (enemy.position.x > 590) patrolDirection = -1;
        break;
      case 'chase':
        double dx = player.position.x - enemy.position.x;
        double dy = player.position.y - enemy.position.y;
        double dist = distance;
        if (dist > 0) {
          enemy.velocity.x = (dx / dist) * 80.0;
          enemy.velocity.y = (dy / dist) * 80.0;
        }
        break;
    }
  }
}
