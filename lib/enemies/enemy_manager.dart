import 'package:flame/components.dart';

import 'base_enemy.dart';
import 'enemy_projectile_component.dart';

class EnemyManager extends Component {
  final int enemyRenderPriority;
  final int projectileRenderPriority;

  List<BaseEnemy> enemies = [];
  List<EnemyProjectileComponent> projectiles = [];

  EnemyManager({
    this.enemyRenderPriority = 0,
    this.projectileRenderPriority = 200,
  });

  @override
  void update(double dt) {
    super.update(dt);
    // Remove only detached components. Pending-mount entries keep parent != null.
    for (var i = enemies.length - 1; i >= 0; i--) {
      final enemy = enemies[i];
      if (!enemy.isMounted && enemy.parent == null) {
        enemies.removeAt(i);
      }
    }
    for (var i = projectiles.length - 1; i >= 0; i--) {
      final projectile = projectiles[i];
      if (!projectile.isMounted && projectile.parent == null) {
        projectiles.removeAt(i);
      }
    }
  }

  void addEnemy(BaseEnemy enemy) {
    if (enemies.contains(enemy)) {
      return;
    }
    enemy.priority = enemyRenderPriority;
    enemies.add(enemy);
    if (enemy.isMounted || enemy.parent != null) {
      return;
    }
    add(enemy);
  }

  void removeEnemy(BaseEnemy enemy) {
    enemies.remove(enemy);
    remove(enemy);
  }

  void addProjectile(EnemyProjectileComponent projectile) {
    projectile.priority = projectileRenderPriority;
    projectiles.add(projectile);

    final host = parent;
    if (host != null) {
      host.add(projectile);
      return;
    }
    add(projectile);
  }

  void removeProjectile(EnemyProjectileComponent projectile) {
    projectiles.remove(projectile);
    if (projectile.isMounted) {
      projectile.removeFromParent();
      return;
    }
    remove(projectile);
  }

  void clearEnemies() {
    for (var enemy in enemies) {
      remove(enemy);
    }
    enemies.clear();

    for (var projectile in projectiles) {
      if (projectile.isMounted) {
        projectile.removeFromParent();
      }
    }
    projectiles.clear();
  }
}
