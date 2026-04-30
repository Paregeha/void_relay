import 'dart:ui';

import '../config/game_config.dart';
import '../enemies/base_enemy.dart';
import '../enemies/enemy_projectile_component.dart';
import '../player/player_component.dart';
import '../world/platform/platform_component.dart';

class CollisionHandler {
  static const bool debugPlatformCollision = true;

  final PlayerComponent player;
  final List<PlatformComponent> platforms;
  final List<BaseEnemy> enemies;
  final List<EnemyProjectileComponent> enemyProjectiles;
  PlatformComponent? _currentGroundPlatform;
  bool _didLogVisualIsolation = false;

  CollisionHandler({
    required this.player,
    required this.platforms,
    this.enemies = const [],
    this.enemyProjectiles = const [],
  });

  void update(double dt) {
    _resolvePlatformCollisions(dt);
    _clampPlayerToLeftWorldBoundary();
    _handleEnemyContacts();
    _handleEnemyProjectiles();
  }

  void _clampPlayerToLeftWorldBoundary() {
    const boundarySeparationEpsilon = 0.1;
    var minCenterX = player.size.x / 2;

    // If a left wall exists (gray border), use its inner edge as the limit.
    for (final platform in platforms) {
      final rect = platform.toRect();
      final isWall = !_isVerticalCollisionSurface(rect);
      if (!isWall) continue;
      if (rect.left > GameConfig.platformCollisionTolerance) continue;

      final wallMinCenterX =
          rect.right + player.size.x / 2 + boundarySeparationEpsilon;
      if (wallMinCenterX > minCenterX) {
        minCenterX = wallMinCenterX;
      }
    }

    if (player.position.x < minCenterX) {
      player.position.x = minCenterX;
      if (player.velocity.x < 0) {
        player.velocity.x = 0;
      }
    }
  }

  void _resolvePlatformCollisions(double dt) {
    final groundedBefore = player.isOnGround;
    final velocityYBefore = player.velocity.y;

    // Grounded-стан керується тільки тут: починаємо кадр з "у повітрі".
    player.isOnGround = false;

    final snapTolerance = GameConfig.platformSnapTolerance;
    final horizontalTolerance = GameConfig.horizontalCollisionTolerance;
    final maxFallbackPenetration = GameConfig.platformCollisionTolerance * 2;
    final maxSideFallbackPenetration =
        GameConfig.platformCollisionTolerance * 4;
    const sideSeparationEpsilon = 0.1;

    final nextRect = player.toRect();
    final prevRect = nextRect.shift(
      Offset(-player.velocity.x * dt, -player.velocity.y * dt),
    );
    final previousY = prevRect.top;
    final nextY = nextRect.top;
    var didResolveLanding = false;
    var didSnapToPlatform = false;

    if (debugPlatformCollision && !_didLogVisualIsolation) {
      _didLogVisualIsolation = true;
      _logPlatformCollision('visual renderer does not modify physics position');
    }

    // 1) Swept landing pass (prev -> next), щоб не пропускати платформу між кадрами.
    PlatformComponent? landedPlatform;
    double? landingTop;
    if (player.velocity.y >= 0) {
      for (final platform in platforms) {
        final platformRect = platform.toRect();
        if (!_isVerticalCollisionSurface(platformRect)) continue;

        final overlapsX =
            nextRect.right > platformRect.left + horizontalTolerance &&
            nextRect.left < platformRect.right - horizontalTolerance;
        final wasAbove = prevRect.bottom <= platformRect.top + snapTolerance;
        final crossedDown = nextRect.bottom >= platformRect.top;
        final topPenetration = nextRect.bottom - platformRect.top;
        final embeddedFromAbove =
            nextRect.overlaps(platformRect) &&
            nextRect.center.dy <= platformRect.center.dy &&
            topPenetration >= 0 &&
            topPenetration <= maxFallbackPenetration &&
            prevRect.bottom <= platformRect.top + maxFallbackPenetration &&
            (player.velocity.y > 0 || player.velocity.x.abs() < 1);

        if (!overlapsX || (!(wasAbove && crossedDown) && !embeddedFromAbove)) {
          continue;
        }

        _logPlatformCollision(
          'playerPos=(${player.position.x.toStringAsFixed(2)},${player.position.y.toStringAsFixed(2)}) '
          'playerSize=(${player.size.x.toStringAsFixed(2)},${player.size.y.toStringAsFixed(2)}) '
          'previousBottom=${prevRect.bottom.toStringAsFixed(2)} '
          'nextBottom=${nextRect.bottom.toStringAsFixed(2)} '
          'currentBottom=${nextRect.bottom.toStringAsFixed(2)} '
          'velocityY=${player.velocity.y.toStringAsFixed(2)} '
          'grounded=${player.isOnGround} '
          'platformTop=${platformRect.top.toStringAsFixed(2)} '
          'platformLeft=${platformRect.left.toStringAsFixed(2)} '
          'platformRight=${platformRect.right.toStringAsFixed(2)} '
          'platformRect=$platformRect '
          'horizontalOverlap=$overlapsX '
          'wasAbove=$wasAbove '
          'crossedDown=$crossedDown '
          'resolved=false',
        );

        if (landingTop == null || platformRect.top < landingTop) {
          landingTop = platformRect.top;
          landedPlatform = platform;
        }
      }
    }

    if (landingTop != null && landedPlatform != null) {
      player.position.y = landingTop - player.size.y / 2;
      player.velocity.y = 0;
      player.land();
      _currentGroundPlatform = landedPlatform;
      didResolveLanding = true;
      _logPlatformCollision(
        'RESOLVED_LANDING '
        'resolved=true '
        'resolvedY=${player.position.y.toStringAsFixed(2)} '
        'platformTop=${landingTop.toStringAsFixed(2)} '
        'playerBottom=${player.toRect().bottom.toStringAsFixed(2)} '
        'grounded=${player.isOnGround}',
      );
    }

    // 2) Standing snap: утримує grounded=true без мікро-провалювання під час idle/run.
    var currentRect = player.toRect();
    if (!player.isOnGround && player.velocity.y >= 0) {
      for (final platform in platforms) {
        final platformRect = platform.toRect();
        if (!_isVerticalCollisionSurface(platformRect)) continue;

        final overlapsX =
            currentRect.right > platformRect.left + horizontalTolerance &&
            currentRect.left < platformRect.right - horizontalTolerance;
        final diff = (currentRect.bottom - platformRect.top).abs();
        if (!overlapsX || diff > snapTolerance) continue;

        player.position.y = platformRect.top - player.size.y / 2;
        player.velocity.y = 0;
        player.land();
        _currentGroundPlatform = platform;
        didSnapToPlatform = true;
        currentRect = player.toRect();
        _logPlatformCollision(
          'SNAP_TO_PLATFORM diff=${diff.toStringAsFixed(2)} '
          'resolvedY=${player.position.y.toStringAsFixed(2)}',
        );
        break;
      }
    }

    // 3) Ceiling block (swept from below).
    currentRect = player.toRect();
    if (player.velocity.y < 0) {
      for (final platform in platforms) {
        final platformRect = platform.toRect();
        if (!_isVerticalCollisionSurface(platformRect)) continue;

        final overlapsX =
            currentRect.right > platformRect.left + horizontalTolerance &&
            currentRect.left < platformRect.right - horizontalTolerance;
        final hitFromBelow =
            prevRect.top >= platformRect.bottom - snapTolerance &&
            currentRect.top <= platformRect.bottom;
        if (!overlapsX || !hitFromBelow) continue;

        player.position.y = platformRect.bottom + player.size.y / 2;
        player.velocity.y = 0;
        currentRect = player.toRect();
        break;
      }
    }

    // 4) Side collision to block passing through vertical faces/walls.
    currentRect = player.toRect();
    for (final platform in platforms) {
      final platformRect = platform.toRect();
      final verticalOverlap =
          currentRect.bottom > platformRect.top + snapTolerance &&
          currentRect.top < platformRect.bottom - snapTolerance;
      if (!verticalOverlap) continue;

      final hitLeftSide =
          player.velocity.x > 0 &&
          prevRect.right <= platformRect.left + snapTolerance &&
          currentRect.right >= platformRect.left;
      final hitRightSide =
          player.velocity.x < 0 &&
          prevRect.left >= platformRect.right - snapTolerance &&
          currentRect.left <= platformRect.right;
      final leftPenetration = currentRect.right - platformRect.left;
      final rightPenetration = platformRect.right - currentRect.left;
      final embeddedFromLeftSide =
          player.velocity.x > 0 &&
          currentRect.overlaps(platformRect) &&
          leftPenetration >= 0 &&
          leftPenetration <= maxSideFallbackPenetration &&
          currentRect.center.dx <= platformRect.center.dx;
      final embeddedFromRightSide =
          player.velocity.x < 0 &&
          currentRect.overlaps(platformRect) &&
          rightPenetration >= 0 &&
          rightPenetration <= maxSideFallbackPenetration &&
          currentRect.center.dx >= platformRect.center.dx;
      if (!hitLeftSide &&
          !hitRightSide &&
          !embeddedFromLeftSide &&
          !embeddedFromRightSide) {
        continue;
      }

      if (hitLeftSide || embeddedFromLeftSide) {
        player.position.x =
            platformRect.left - player.size.x / 2 - sideSeparationEpsilon;
      } else {
        player.position.x =
            platformRect.right + player.size.x / 2 + sideSeparationEpsilon;
      }
      player.velocity.x = 0;
      break;
    }

    final resolvedRect = player.toRect();
    final groundedAfter = player.isOnGround;
    final velocityYAfter = player.velocity.y;

    if (groundedAfter && velocityYAfter > 0) {
      _warnPlatformCollision(
        'GROUNDED_BUT_FALLING '
        'velocityY=${velocityYAfter.toStringAsFixed(2)} '
        'playerBottom=${resolvedRect.bottom.toStringAsFixed(2)} '
        'platformTop=${_currentGroundPlatform?.toRect().top.toStringAsFixed(2) ?? 'n/a'}',
      );
    }

    if (_currentGroundPlatform != null) {
      final platformRect = _currentGroundPlatform!.toRect();
      final overlap =
          resolvedRect.right > platformRect.left + horizontalTolerance &&
          resolvedRect.left < platformRect.right - horizontalTolerance;
      final diff = resolvedRect.bottom - platformRect.top;
      if (overlap &&
          resolvedRect.bottom > platformRect.top + 1.0 &&
          velocityYAfter >= 0) {
        _warnPlatformCollision(
          'PLAYER_BELOW_PLATFORM '
          'playerBottom=${resolvedRect.bottom.toStringAsFixed(2)} '
          'platformTop=${platformRect.top.toStringAsFixed(2)} '
          'diff=${diff.toStringAsFixed(2)} '
          'velocityY=${velocityYAfter.toStringAsFixed(2)} '
          'grounded=$groundedAfter '
          'playerPos=${player.position} '
          'platformRect=$platformRect',
        );
      }
    }

    if (groundedBefore && !groundedAfter) {
      final prevPlatformRect = _currentGroundPlatform?.toRect();
      var overlap = false;
      String reason = 'unknown';
      String diffText = 'n/a';
      var shouldWarnLostGround = false;
      if (prevPlatformRect != null) {
        overlap =
            resolvedRect.right > prevPlatformRect.left + horizontalTolerance &&
            resolvedRect.left < prevPlatformRect.right - horizontalTolerance;
        final diff = (resolvedRect.bottom - prevPlatformRect.top).abs();
        diffText = diff.toStringAsFixed(2);
        if (!overlap) {
          reason = 'walked_off_edge';
        } else if (velocityYAfter < 0) {
          reason = 'jumped';
        } else if (diff <= snapTolerance + 1.0) {
          reason = 'collision_missed';
          shouldWarnLostGround = true;
        }
      }
      if (shouldWarnLostGround) {
        _warnPlatformCollision(
          'GROUNDED_LOST_WHILE_ON_PLATFORM '
          'previousGrounded=true newGrounded=false '
          'playerBottom=${resolvedRect.bottom.toStringAsFixed(2)} '
          'platformTop=${prevPlatformRect?.top.toStringAsFixed(2) ?? 'n/a'} '
          'diff=$diffText '
          'horizontalOverlap=$overlap',
        );
      }
      _logPlatformCollision(
        'LOST_GROUND reason=$reason '
        'previousPlatformRect=$prevPlatformRect '
        'playerBottom=${resolvedRect.bottom.toStringAsFixed(2)} '
        'platformTop=${prevPlatformRect?.top.toStringAsFixed(2) ?? 'n/a'} '
        'horizontalOverlap=$overlap '
        'velocityY=${velocityYAfter.toStringAsFixed(2)}',
      );
      _currentGroundPlatform = null;
    }

    final stepChanged =
        groundedBefore != groundedAfter ||
        (velocityYBefore - velocityYAfter).abs() > 0.001 ||
        didResolveLanding ||
        didSnapToPlatform;
    if (stepChanged) {
      _logPlatformCollision(
        'STEP '
        'previousY=${previousY.toStringAsFixed(2)} '
        'nextY=${nextY.toStringAsFixed(2)} '
        'finalY=${player.position.y.toStringAsFixed(2)} '
        'velocityYBefore=${velocityYBefore.toStringAsFixed(2)} '
        'velocityYAfter=${velocityYAfter.toStringAsFixed(2)} '
        'groundedBefore=$groundedBefore '
        'groundedAfter=$groundedAfter',
      );
    }

    if (groundedAfter && _currentGroundPlatform == null) {
      for (final platform in platforms) {
        final rect = platform.toRect();
        final overlapsX =
            resolvedRect.right > rect.left + horizontalTolerance &&
            resolvedRect.left < rect.right - horizontalTolerance;
        final nearTop = (resolvedRect.bottom - rect.top).abs() <= snapTolerance;
        if (_isVerticalCollisionSurface(rect) && overlapsX && nearTop) {
          _currentGroundPlatform = platform;
          break;
        }
      }
    }
  }

  void _logPlatformCollision(String message) {
    if (!debugPlatformCollision) return;
    print('[PlatformCollision] $message');
  }

  void _warnPlatformCollision(String message) {
    if (!debugPlatformCollision) return;
    print('[PlatformCollision][WARNING] $message');
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
