import 'dart:ui';

import '../config/game_config.dart';
import '../enemies/base_enemy.dart';
import '../enemies/enemy_projectile_component.dart';
import '../player/player_component.dart';
import '../world/platform/platform_component.dart';

class CollisionHandler {
  final PlayerComponent player;
  final List<PlatformComponent> platforms;
  final List<BaseEnemy> enemies;
  final List<EnemyProjectileComponent> enemyProjectiles;

  CollisionHandler({
    required this.player,
    required this.platforms,
    this.enemies = const [],
    this.enemyProjectiles = const [],
  });

  void update(double dt) {
    _resolvePlatformCollisions(dt);
    _handleEnemyContacts();
    _handleEnemyProjectiles();
  }

  void _resolvePlatformCollisions(double dt) {
    // Grounded-стан керується тільки тут: спочатку вважаємо, що гравець у повітрі.
    player.isOnGround = false;

    final playerRect = player.toRect();
    final prevBottom = playerRect.bottom - player.velocity.y * dt;
    final prevTop = playerRect.top - player.velocity.y * dt;
    final prevLeft = playerRect.left - player.velocity.x * dt;
    final prevRight = playerRect.right - player.velocity.x * dt;
    final maxFallbackPenetration = GameConfig.platformCollisionTolerance * 2;
    final maxSideFallbackPenetration =
        GameConfig.platformCollisionTolerance * 4;
    final minVerticalSupportWidth = GameConfig.platformCollisionTolerance * 2;
    const sideSeparationEpsilon = 0.1;
    for (var platform in platforms) {
      final platformRect = platform.toRect();
      if (!_isVerticalCollisionSurface(platformRect)) {
        continue;
      }
      final topPenetration = playerRect.bottom - platformRect.top;
      final bottomPenetration = platformRect.bottom - playerRect.top;
      // Перевірка: гравець зверху, рухається вниз, і торкається платформи
      final bool verticalCheck =
          player.velocity.y >= 0 &&
          playerRect.bottom >= platformRect.top &&
          prevBottom <=
              platformRect.top + GameConfig.platformCollisionTolerance;
      // Fallback для випадків, коли гравець уже трохи всередині платформи
      // (наприклад, через spawn або великий dt), але знаходиться над її центром.
      final bool embeddedFromAbove =
          playerRect.overlaps(platformRect) &&
          playerRect.center.dy <= platformRect.center.dy &&
          topPenetration >= 0 &&
          topPenetration <= maxFallbackPenetration &&
          prevBottom <= platformRect.top + maxFallbackPenetration &&
          (player.velocity.y > 0 || player.velocity.x.abs() < 1);
      final bool horizontalCheck =
          playerRect.right >
              platformRect.left + GameConfig.platformCollisionTolerance &&
          playerRect.left <
              platformRect.right - GameConfig.platformCollisionTolerance;
      final overlapWidth =
          (playerRect.right < platformRect.right
              ? playerRect.right
              : platformRect.right) -
          (playerRect.left > platformRect.left
              ? playerRect.left
              : platformRect.left);
      final hasStableVerticalSupport = overlapWidth >= minVerticalSupportWidth;

      // Side collision has priority near platform edges to prevent vertical pop.
      final verticalOverlap =
          playerRect.bottom >
              platformRect.top + GameConfig.platformCollisionTolerance &&
          playerRect.top <
              platformRect.bottom - GameConfig.platformCollisionTolerance;
      final hitLeftSide =
          player.velocity.x > 0 &&
          prevRight <=
              platformRect.left + GameConfig.platformCollisionTolerance &&
          playerRect.right >= platformRect.left;
      final hitRightSide =
          player.velocity.x < 0 &&
          prevLeft >=
              platformRect.right - GameConfig.platformCollisionTolerance &&
          playerRect.left <= platformRect.right;
      final leftPenetration = playerRect.right - platformRect.left;
      final rightPenetration = platformRect.right - playerRect.left;
      final embeddedFromLeftSide =
          player.velocity.x > 0 &&
          playerRect.overlaps(platformRect) &&
          leftPenetration >= 0 &&
          leftPenetration <= maxSideFallbackPenetration &&
          playerRect.center.dx <= platformRect.center.dx;
      final embeddedFromRightSide =
          player.velocity.x < 0 &&
          playerRect.overlaps(platformRect) &&
          rightPenetration >= 0 &&
          rightPenetration <= maxSideFallbackPenetration &&
          playerRect.center.dx >= platformRect.center.dx;
      if (verticalOverlap &&
          (hitLeftSide ||
              hitRightSide ||
              embeddedFromLeftSide ||
              embeddedFromRightSide)) {
        if (hitLeftSide || embeddedFromLeftSide) {
          player.position.x =
              platformRect.left - player.size.x / 2 - sideSeparationEpsilon;
        } else {
          player.position.x =
              platformRect.right + player.size.x / 2 + sideSeparationEpsilon;
        }
        player.velocity.x = 0.0;
        break;
      }

      if ((verticalCheck || embeddedFromAbove) &&
          horizontalCheck &&
          hasStableVerticalSupport) {
        player.position.y = platformRect.top - player.size.y / 2;
        player.velocity.y = 0.0;
        player.land();
        break;
      }

      // Head collision: блокує рух вгору, щоб не заходити в стелю.
      final bool hitFromBelow =
          player.velocity.y < 0 &&
          playerRect.top <= platformRect.bottom &&
          prevTop >=
              platformRect.bottom - GameConfig.platformCollisionTolerance;
      final bool embeddedFromBelow =
          playerRect.overlaps(platformRect) &&
          playerRect.center.dy >= platformRect.center.dy &&
          bottomPenetration >= 0 &&
          bottomPenetration <= maxFallbackPenetration &&
          prevTop >= platformRect.bottom - maxFallbackPenetration &&
          (player.velocity.y < 0 || player.velocity.x.abs() < 1);
      if ((hitFromBelow || embeddedFromBelow) &&
          horizontalCheck &&
          hasStableVerticalSupport) {
        player.position.y = platformRect.bottom + player.size.y / 2;
        player.velocity.y = 0.0;
        break;
      }
    }
  }

  bool _isVerticalCollisionSurface(Rect rect) {
    // Side walls мають висоту значно більшу за ширину — їх ігноруємо
    // у вертикальній (підлога/стеля) колізії.
    return rect.width >= rect.height;
  }

  void _handleEnemyContacts() {
    if (player.isInvulnerable) return;
    final playerRect = player.toRect();
    for (var enemy in enemies) {
      if (!enemy.isMounted) continue;
      if (!enemy.canDealContactDamage) continue;
      if (playerRect.overlaps(enemy.toRect())) {
        player.takeDamage(enemy.contactDamage);
        enemy.onContactDamageApplied();
        break; // Один удар за кадр
      }
    }
  }

  void _handleEnemyProjectiles() {
    final playerRect = player.toRect();
    for (var projectile in enemyProjectiles) {
      if (!projectile.isMounted || !projectile.isAlive) continue;
      if (playerRect.overlaps(projectile.toRect())) {
        player.takeDamage(projectile.damage);
        projectile.onHit();
      }
    }
  }
}
