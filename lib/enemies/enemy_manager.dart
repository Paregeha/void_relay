import 'package:flame/components.dart';

import 'base_enemy.dart';
import 'enemy_projectile_component.dart';

class EnemyManager extends Component {
  List<BaseEnemy> enemies = [];
  List<EnemyProjectileComponent> projectiles = [];

  void addEnemy(BaseEnemy enemy) {
    enemies.add(enemy);
    add(enemy);
  }

  void removeEnemy(BaseEnemy enemy) {
    enemies.remove(enemy);
    remove(enemy);
  }

  void addProjectile(EnemyProjectileComponent projectile) {
    projectiles.add(projectile);
    add(projectile);
  }

  void removeProjectile(EnemyProjectileComponent projectile) {
    projectiles.remove(projectile);
    remove(projectile);
  }

  void clearEnemies() {
    for (var enemy in enemies) {
      remove(enemy);
    }
    enemies.clear();

    for (var projectile in projectiles) {
      remove(projectile);
    }
    projectiles.clear();
  }
}
