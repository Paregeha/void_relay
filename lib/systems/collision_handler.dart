import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

import '../config/game_config.dart';
import '../enemies/base_enemy.dart';
import '../enemies/enemy_projectile_component.dart';
import '../enemies/sentry_turret/sentry_turret.dart';
import '../player/player_component.dart';
import '../world/platform/platform_component.dart';

class CollisionHandler {
  static const bool debugPlatformCollision = false;
  static const double _maxPhysicsDt = 1 / 30;
  static const bool _debugPhysicsLogs = false;
  static const bool _enableEmergencyPlatformRecovery = false;
  static const double _maxUpwardSnapCorrection = 20.0;
  static const double _minWorldY = 0.0;

  final PlayerComponent player;
  final List<PlatformComponent> platforms;
  final List<BaseEnemy> enemies;
  final List<EnemyProjectileComponent> enemyProjectiles;
  PlatformComponent? _currentGroundPlatform;
  final List<PlatformComponent> _platformScratch = <PlatformComponent>[];
  bool _didLogVisualIsolation = false;
  int _lastFallThroughWarningMs = 0;

  CollisionHandler({
    required this.player,
    required this.platforms,
    this.enemies = const [],
    this.enemyProjectiles = const [],
  });

  void update(double dt) {
    if (dt <= 0) return;
    final shouldClampForFall = player.velocity.y >= 0;
    final safeDt = dt > _maxPhysicsDt && shouldClampForFall
        ? _maxPhysicsDt
        : dt;

    if (dt > _maxPhysicsDt &&
        shouldClampForFall &&
        _debugPhysicsLogs &&
        kDebugMode) {
      debugPrint(
        '[PLAYER_PHYSICS] large dt clamped old=${dt.toStringAsFixed(4)} '
        'new=${_maxPhysicsDt.toStringAsFixed(4)}',
      );
    }

    _resolvePlatformCollisions(safeDt, dt);
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

  void _resolvePlatformCollisions(double dt, double frameDt) {
    final groundedBefore = player.isOnGround;
    final previousGroundPlatform = _currentGroundPlatform;
    final velocityYBefore = player.velocity.y;

    // Grounded-стан керується тільки тут: починаємо кадр з "у повітрі".
    player.isOnGround = false;

    final snapTolerance = GameConfig.platformSnapTolerance;
    final horizontalTolerance = GameConfig.horizontalCollisionTolerance;
    final maxFallbackPenetration =
        (player.size.y + GameConfig.platformCollisionTolerance).toDouble();
    final maxSideFallbackPenetration =
        GameConfig.platformCollisionTolerance * 4;
    const sideSeparationEpsilon = 0.1;
    const worldTopEpsilon = 0.01;

    if (groundedBefore && previousGroundPlatform != null) {
      final previousPlatformRect = previousGroundPlatform.previousWorldRect;
      final currentPlatformRect = previousGroundPlatform.toRect();
      final platformDelta = Offset(
        currentPlatformRect.left - previousPlatformRect.left,
        currentPlatformRect.top - previousPlatformRect.top,
      );
      if (platformDelta.dx.abs() > 0.0001 || platformDelta.dy.abs() > 0.0001) {
        player.position.add(Vector2(platformDelta.dx, platformDelta.dy));
        if (_debugPhysicsLogs && kDebugMode) {
          debugPrint(
            '[PLAYER_COLLISION] carried by moving platform '
            'delta=(${platformDelta.dx.toStringAsFixed(2)},${platformDelta.dy.toStringAsFixed(2)})',
          );
        }
      }
    }

    final nextRect = player.toRect();
    var prevRect = player.previousWorldRect;
    // Fallback for tests/special flows where previous rect wasn't advanced yet.
    if ((prevRect.left - nextRect.left).abs() < 0.0001 &&
        (prevRect.top - nextRect.top).abs() < 0.0001) {
      prevRect = nextRect.shift(
        Offset(-player.velocity.x * frameDt, -player.velocity.y * frameDt),
      );
    }
    final sweptPlayerRect = _sweptRect(prevRect, nextRect);
    final candidatePlatforms = _collectCandidatePlatforms(sweptPlayerRect);
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
    double? landingCrossDistance;
    if (player.velocity.y >= 0) {
      for (final platform in candidatePlatforms) {
        final currentPlatformRect = platform.toRect();
        final previousPlatformRect = platform.previousWorldRect;
        if (!_isLandingSurface(currentPlatformRect)) continue;

        final sweptPlatformRect = _sweptRect(
          previousPlatformRect,
          currentPlatformRect,
        );
        final overlapsX =
            sweptPlayerRect.right >
                sweptPlatformRect.left + horizontalTolerance &&
            sweptPlayerRect.left <
                sweptPlatformRect.right - horizontalTolerance;
        final overlapsXCurrent =
            nextRect.right > currentPlatformRect.left + horizontalTolerance &&
            nextRect.left < currentPlatformRect.right - horizontalTolerance;
        final wasAbove =
            prevRect.bottom <= previousPlatformRect.top + snapTolerance;
        final crossedDown = nextRect.bottom >= currentPlatformRect.top;
        final crossedThisStep =
            prevRect.bottom <= previousPlatformRect.top + snapTolerance &&
            nextRect.bottom >= currentPlatformRect.top;
        final topPenetration = nextRect.bottom - currentPlatformRect.top;
        final embeddedFromAbove =
            nextRect.overlaps(currentPlatformRect) &&
            nextRect.center.dy <= currentPlatformRect.center.dy &&
            topPenetration >= 0 &&
            topPenetration <= maxFallbackPenetration &&
            prevRect.top < previousPlatformRect.top &&
            (player.velocity.y > 0 || player.velocity.x.abs() < 1);
        final intersectsSwept =
            sweptPlayerRect.overlaps(currentPlatformRect) ||
            sweptPlayerRect.overlaps(sweptPlatformRect);
        final platformBelowInFallDirection =
            currentPlatformRect.top >= prevRect.bottom - snapTolerance;
        final touchesWorldTop = currentPlatformRect.top <= worldTopEpsilon;

        if (!overlapsX || !overlapsXCurrent || !intersectsSwept) {
          continue;
        }

        final validCrossing =
            player.velocity.y > 0 &&
            crossedThisStep &&
            platformBelowInFallDirection &&
            !touchesWorldTop;
        final validEmbeddedRecovery =
            embeddedFromAbove && !touchesWorldTop && player.velocity.y >= 0;

        if (!validCrossing && !validEmbeddedRecovery) {
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
          'platformTop=${currentPlatformRect.top.toStringAsFixed(2)} '
          'platformLeft=${currentPlatformRect.left.toStringAsFixed(2)} '
          'platformRight=${currentPlatformRect.right.toStringAsFixed(2)} '
          'platformRect=$currentPlatformRect '
          'horizontalOverlap=$overlapsX '
          'wasAbove=$wasAbove '
          'crossedDown=$crossedDown '
          'intersectsSwept=$intersectsSwept '
          'resolved=false',
        );

        final crossDistance = currentPlatformRect.top - prevRect.bottom < 0
            ? 0.0
            : currentPlatformRect.top - prevRect.bottom;
        if (landingCrossDistance == null ||
            crossDistance < landingCrossDistance) {
          landingCrossDistance = crossDistance;
          landingTop = currentPlatformRect.top;
          landedPlatform = platform;
        }
      }
    }

    if (landingTop != null && landedPlatform != null) {
      final applied = _tryApplyVerticalSnap(
        targetPlatform: landedPlatform,
        targetPlatformTop: landingTop,
        previousPlayerRect: prevRect,
        currentPlayerRect: nextRect,
        reason: 'LANDING',
        allowLargeUpwardCorrection: true,
      );
      if (applied) {
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
      if (_debugPhysicsLogs && kDebugMode && dt >= 0.05) {
        debugPrint(
          '[PLAYER_COLLISION] swept landing platform=${landedPlatform.toRect()}',
        );
        final moved =
            landedPlatform.previousWorldRect != landedPlatform.toRect();
        if (moved) {
          debugPrint('[PLAYER_COLLISION] landed on moving platform');
        }
        debugPrint('[PLAYER_COLLISION] previousPlayerRect=$prevRect');
        debugPrint('[PLAYER_COLLISION] currentPlayerRect=$nextRect');
        debugPrint('[PLAYER_COLLISION] sweptPlayerRect=$sweptPlayerRect');
      }
    }

    // 2) Standing snap: утримує grounded=true без мікро-провалювання під час idle/run.
    var currentRect = player.toRect();
    if (!player.isOnGround && player.velocity.y >= 0) {
      for (final platform in candidatePlatforms) {
        final platformRect = platform.toRect();
        if (!_isLandingSurface(platformRect)) continue;
        if (platformRect.top <= worldTopEpsilon) continue;

        final overlapsX =
            currentRect.right > platformRect.left + horizontalTolerance &&
            currentRect.left < platformRect.right - horizontalTolerance;
        final diff = (currentRect.bottom - platformRect.top).abs();
        if (!overlapsX || diff > snapTolerance) continue;

        final applied = _tryApplyVerticalSnap(
          targetPlatform: platform,
          targetPlatformTop: platformRect.top,
          previousPlayerRect: prevRect,
          currentPlayerRect: currentRect,
          reason: 'STANDING_SNAP',
        );
        if (applied) {
          didSnapToPlatform = true;
          currentRect = player.toRect();
          _logPlatformCollision(
            'SNAP_TO_PLATFORM diff=${diff.toStringAsFixed(2)} '
            'resolvedY=${player.position.y.toStringAsFixed(2)}',
          );
          if (_debugPhysicsLogs && kDebugMode) {
            debugPrint(
              '[PLAYER_COLLISION] snap to platform top=${platformRect.top.toStringAsFixed(2)}',
            );
          }
          break;
        }
      }
    }

    // 2.5) Emergency recovery: if player keeps falling through a platform,
    // force a vertical snap back to the nearest top surface.
    currentRect = player.toRect();
    if (_enableEmergencyPlatformRecovery &&
        !player.isOnGround &&
        player.velocity.y > 150) {
      PlatformComponent? recoveryPlatform;
      double? recoveryTop;
      double? recoveryDistance;
      for (final platform in candidatePlatforms) {
        final platformRect = platform.toRect();
        if (!_isLandingSurface(platformRect)) continue;
        if (platformRect.top <= worldTopEpsilon) continue;

        final overlapWidth =
            (currentRect.right < platformRect.right
                ? currentRect.right
                : platformRect.right) -
            (currentRect.left > platformRect.left
                ? currentRect.left
                : platformRect.left);
        final strongHorizontalOverlap = overlapWidth >= player.size.x * 0.8;
        if (!strongHorizontalOverlap) continue;

        final isBelowOrCrossedTop =
            currentRect.bottom >= platformRect.top &&
            prevRect.bottom >= platformRect.top - snapTolerance;
        if (!isBelowOrCrossedTop) continue;

        final distanceToTop = (currentRect.bottom - platformRect.top).abs();
        if (recoveryDistance == null || distanceToTop < recoveryDistance) {
          recoveryDistance = distanceToTop;
          recoveryTop = platformRect.top;
          recoveryPlatform = platform;
        }
      }

      if (recoveryTop != null && recoveryPlatform != null) {
        final applied = _tryApplyVerticalSnap(
          targetPlatform: recoveryPlatform,
          targetPlatformTop: recoveryTop,
          previousPlayerRect: prevRect,
          currentPlayerRect: currentRect,
          reason: 'EMERGENCY_PLATFORM_RECOVERY',
        );
        if (applied) {
          didSnapToPlatform = true;
          currentRect = player.toRect();
          _warnPlatformCollision(
            'EMERGENCY_PLATFORM_RECOVERY '
            'resolvedY=${player.position.y.toStringAsFixed(2)} '
            'platformTop=${recoveryTop.toStringAsFixed(2)}',
          );
          if (_debugPhysicsLogs && kDebugMode) {
            debugPrint('[PLAYER_COLLISION] prevented fall-through');
          }
        }
      }
    }

    // 2.6) Hard fail-safe for lag spikes: if we are falling and ended up below
    // any walkable platform with strong X overlap, force-snap to platform top.
    currentRect = player.toRect();
    if (!player.isOnGround && player.velocity.y > 120) {
      PlatformComponent? fallbackPlatform;
      double? fallbackTop;
      double? fallbackCrossDistance;
      for (final platform in candidatePlatforms) {
        final currentPlatformRect = platform.toRect();
        final previousPlatformRect = platform.previousWorldRect;
        if (!_isLandingSurface(currentPlatformRect)) continue;
        if (currentPlatformRect.top <= worldTopEpsilon) continue;

        final sweptPlatformRect = _sweptRect(
          previousPlatformRect,
          currentPlatformRect,
        );

        final overlapWidth =
            (currentRect.right < sweptPlatformRect.right
                ? currentRect.right
                : sweptPlatformRect.right) -
            (currentRect.left > sweptPlatformRect.left
                ? currentRect.left
                : sweptPlatformRect.left);
        if (overlapWidth < player.size.x * 0.6) continue;

        final crossedTopThisStep =
            prevRect.bottom <= previousPlatformRect.top + snapTolerance &&
            currentRect.bottom >= currentPlatformRect.top;
        if (!crossedTopThisStep) continue;

        final intersectsSwept =
            sweptPlayerRect.overlaps(currentPlatformRect) ||
            sweptPlayerRect.overlaps(sweptPlatformRect);
        if (!intersectsSwept) continue;

        final belowTop =
            currentRect.bottom >
            currentPlatformRect.top + GameConfig.platformSnapTolerance;
        final wasAboveOrNearTop =
            prevRect.bottom <=
            previousPlatformRect.top + maxFallbackPenetration;
        if (!wasAboveOrNearTop) continue;
        if (!belowTop) continue;

        final crossDistance = currentPlatformRect.top - prevRect.bottom < 0
            ? 0.0
            : currentPlatformRect.top - prevRect.bottom;
        if (fallbackCrossDistance == null ||
            crossDistance < fallbackCrossDistance) {
          fallbackCrossDistance = crossDistance;
          fallbackTop = currentPlatformRect.top;
          fallbackPlatform = platform;
        }
      }

      if (fallbackTop != null && fallbackPlatform != null) {
        final applied = _tryApplyVerticalSnap(
          targetPlatform: fallbackPlatform,
          targetPlatformTop: fallbackTop,
          previousPlayerRect: prevRect,
          currentPlayerRect: currentRect,
          reason: 'FALLBACK_RECOVERY',
          allowLargeUpwardCorrection: true,
        );
        if (applied) {
          didSnapToPlatform = true;
          currentRect = player.toRect();
          if (_debugPhysicsLogs && kDebugMode) {
            debugPrint('[PLAYER_COLLISION] previousPlayerRect=$prevRect');
            debugPrint('[PLAYER_COLLISION] currentPlayerRect=$currentRect');
            debugPrint('[PLAYER_COLLISION] sweptPlayerRect=$sweptPlayerRect');
            debugPrint(
              '[PLAYER_COLLISION] platform previousRect=${fallbackPlatform.previousWorldRect}',
            );
            debugPrint(
              '[PLAYER_COLLISION] platform currentRect=${fallbackPlatform.toRect()}',
            );
            debugPrint('[PLAYER_COLLISION] prevented fall-through');
          }
        }
      }
    }

    // 3) Ceiling block (swept from below).
    currentRect = player.toRect();
    if (player.velocity.y < 0) {
      for (final platform in candidatePlatforms) {
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
    for (final platform in candidatePlatforms) {
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
      for (final platform in candidatePlatforms) {
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

    _enforceGroundInvariant(groundedBefore: groundedBefore, dt: dt);

    _logPotentialFallThroughIfNeeded(
      dt: dt,
      didVerticalResolve: didResolveLanding || didSnapToPlatform,
      resolvedRect: resolvedRect,
      previousRect: prevRect,
    );
  }

  void _logPlatformCollision(String message) {
    if (!debugPlatformCollision) return;
    // Keep verbose per-frame tracing disabled to avoid console spam.
  }

  void _warnPlatformCollision(String message) {
    if (!debugPlatformCollision) return;
    debugPrint('[PlatformCollision][WARNING] $message');
  }

  void _logPotentialFallThroughIfNeeded({
    required double dt,
    required bool didVerticalResolve,
    required Rect resolvedRect,
    required Rect previousRect,
  }) {
    if (!debugPlatformCollision) return;
    if (didVerticalResolve) return;
    if (player.velocity.y < 120) return;

    Rect? nearestPlatformRect;
    var nearestDistance = double.infinity;
    for (final platform in _collectCandidatePlatforms(resolvedRect)) {
      final rect = platform.toRect();
      if (!_isLandingSurface(rect)) continue;
      final overlapsX =
          resolvedRect.right > rect.left && resolvedRect.left < rect.right;
      if (!overlapsX) continue;

      final distance = (resolvedRect.bottom - rect.top).abs();
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestPlatformRect = rect;
      }
    }

    final nearest = nearestPlatformRect;
    if (nearest == null) return;
    final crossedTop =
        previousRect.bottom <= nearest.top &&
        resolvedRect.bottom >= nearest.top;
    final suspicious =
        crossedTop ||
        resolvedRect.bottom > nearest.top + GameConfig.platformSnapTolerance;
    if (!suspicious) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastFallThroughWarningMs < 450) return;
    _lastFallThroughWarningMs = nowMs;

    _warnPlatformCollision(
      'POTENTIAL_FALL_THROUGH '
      'dt=${dt.toStringAsFixed(4)} '
      'playerPos=(${player.position.x.toStringAsFixed(2)},${player.position.y.toStringAsFixed(2)}) '
      'velocity=(${player.velocity.x.toStringAsFixed(2)},${player.velocity.y.toStringAsFixed(2)}) '
      'grounded=${player.isOnGround} '
      'platformCount=${platforms.length} '
      'playerRect=$resolvedRect '
      'nearestPlatform=$nearest '
      'verticalResolved=$didVerticalResolve '
      'crossedTop=$crossedTop',
    );
  }

  bool _isVerticalCollisionSurface(Rect rect) {
    // Side walls мають висоту значно більшу за ширину — їх ігноруємо
    // у вертикальній (підлога/стеля) колізії.
    return rect.width >= rect.height;
  }

  bool _isLandingSurface(Rect rect) {
    if (!_isVerticalCollisionSurface(rect)) return false;
    // Ignore hidden ceiling boundary strip for downward landing logic.
    final isVeryWide = rect.width >= GameConfig.defaultWorldWidth * 0.6;
    final isCeilingBoundary = isVeryWide && rect.top <= 4.0;
    return !isCeilingBoundary;
  }

  void _enforceGroundInvariant({
    required bool groundedBefore,
    required double dt,
  }) {
    final ground = _currentGroundPlatform;
    if (ground == null) return;

    // If player was grounded or is grounded now, enforce exact resting pose.
    if (!groundedBefore && !player.isOnGround) return;

    final platformRect = ground.toRect();
    if (!_isLandingSurface(platformRect)) {
      _warnPlatformCollision(
        '[PLAYER_COLLISION][REJECTED_BAD_GROUNDED_PLATFORM] '
        'platformId=${_platformDebugId(ground)} '
        'platformRect=$platformRect',
      );
      player.isOnGround = false;
      _currentGroundPlatform = null;
      return;
    }

    final expectedBottom = platformRect.top;
    final currentRect = player.toRect();
    final currentBottom = currentRect.bottom;
    final diff = currentBottom - expectedBottom;

    if (diff.abs() > 1.0) {
      final applied = _tryApplyVerticalSnap(
        targetPlatform: ground,
        targetPlatformTop: expectedBottom,
        previousPlayerRect: player.previousWorldRect,
        currentPlayerRect: currentRect,
        reason: 'GROUND_INVARIANT',
      );
      if (!applied) {
        player.isOnGround = false;
        _currentGroundPlatform = null;
        return;
      }
      if (_debugPhysicsLogs && kDebugMode) {
        debugPrint('[PLAYER_COLLISION] prevented fall-through');
      }
    }

    final finalBottom = player.toRect().bottom;
    final finalDiff = (finalBottom - expectedBottom).abs();
    if (_debugPhysicsLogs && kDebugMode && finalDiff > 1.5) {
      debugPrint(
        '[PLAYER_COLLISION][BROKEN_INVARIANT] '
        'playerY=${player.position.y.toStringAsFixed(2)} '
        'playerHitbox=${player.toRect()} '
        'platformTop=${expectedBottom.toStringAsFixed(2)} '
        'platformRect=$platformRect '
        'velocity=(${player.velocity.x.toStringAsFixed(2)},${player.velocity.y.toStringAsFixed(2)}) '
        'dt=${dt.toStringAsFixed(4)} '
        'grounded=${player.isOnGround} '
        'currentGroundPlatform=$ground',
      );
    }
  }

  Rect _sweptRect(Rect previousRect, Rect currentRect) {
    final left = previousRect.left < currentRect.left
        ? previousRect.left
        : currentRect.left;
    final top = previousRect.top < currentRect.top
        ? previousRect.top
        : currentRect.top;
    final right = previousRect.right > currentRect.right
        ? previousRect.right
        : currentRect.right;
    final bottom = previousRect.bottom > currentRect.bottom
        ? previousRect.bottom
        : currentRect.bottom;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  bool _tryApplyVerticalSnap({
    required PlatformComponent targetPlatform,
    required double targetPlatformTop,
    required Rect previousPlayerRect,
    required Rect currentPlayerRect,
    required String reason,
    bool allowLargeUpwardCorrection = false,
  }) {
    final platformRect = targetPlatform.toRect();
    final oldY = player.position.y;
    final resolvedY = targetPlatformTop - player.size.y / 2;
    final delta = resolvedY - oldY;
    final resolvedTop = resolvedY - player.size.y / 2;

    if (!allowLargeUpwardCorrection && delta < -_maxUpwardSnapCorrection) {
      _warnPlatformCollision(
        '[PLAYER_COLLISION][REJECTED_BAD_SNAP] '
        'reason=$reason correctionY=${delta.toStringAsFixed(2)} '
        'platformTop=${targetPlatformTop.toStringAsFixed(2)} '
        'platformId=${_platformDebugId(targetPlatform)}',
      );
      _warnPlatformCollision(
        '[PLAYER_COLLISION][REJECTED_UPWARD_TELEPORT] '
        'oldY=${oldY.toStringAsFixed(2)} '
        'resolvedY=${resolvedY.toStringAsFixed(2)} '
        'delta=${delta.toStringAsFixed(2)} '
        'platformTop=${targetPlatformTop.toStringAsFixed(2)} '
        'platformId=${_platformDebugId(targetPlatform)} '
        'playerPreviousRect=$previousPlayerRect '
        'playerCurrentRect=$currentPlayerRect '
        'platformRect=$platformRect',
      );
      return false;
    }

    if (resolvedY < _minWorldY + player.size.y / 2 ||
        resolvedTop < _minWorldY) {
      _warnPlatformCollision(
        '[PLAYER_COLLISION][REJECTED_OUT_OF_BOUNDS_SNAP] '
        'reason=$reason oldY=${oldY.toStringAsFixed(2)} '
        'resolvedY=${resolvedY.toStringAsFixed(2)} '
        'resolvedTop=${resolvedTop.toStringAsFixed(2)} '
        'platformTop=${targetPlatformTop.toStringAsFixed(2)} '
        'platformId=${_platformDebugId(targetPlatform)} '
        'playerPreviousRect=$previousPlayerRect '
        'playerCurrentRect=$currentPlayerRect '
        'platformRect=$platformRect',
      );
      return false;
    }

    player.position.y = resolvedY;
    player.velocity.y = 0;
    player.land();
    _currentGroundPlatform = targetPlatform;
    return true;
  }

  String _platformDebugId(PlatformComponent platform) {
    return 'platform#${platform.hashCode}';
  }

  List<PlatformComponent> _collectCandidatePlatforms(Rect referenceRect) {
    _platformScratch.clear();
    final minX = referenceRect.left - player.size.x * 3;
    final maxX = referenceRect.right + player.size.x * 3;
    for (final platform in platforms) {
      final rect = platform.toRect();
      if (rect.right < minX || rect.left > maxX) continue;
      _platformScratch.add(platform);
    }
    if (_platformScratch.isEmpty) {
      _platformScratch.addAll(platforms);
    }
    return _platformScratch;
  }

  void _handleEnemyContacts() {
    if (player.isInvulnerable) return;
    if (enemies.isEmpty) return;
    final playerRect = player.toRect();
    final playerCenter = player.absolutePosition;
    final playerHalfW = player.size.x * 0.5;
    final playerHalfH = player.size.y * 0.5;
    for (var enemy in enemies) {
      if (!enemy.isMounted) continue;
      if (!enemy.canDealContactDamage) continue;
      // Cheap broad-phase before AABB overlap.
      final enemyCenter = enemy.absolutePosition;
      final dx = (enemyCenter.x - playerCenter.x).abs();
      final dy = (enemyCenter.y - playerCenter.y).abs();
      final maxDx = playerHalfW + enemy.size.x * 0.5 + 64.0;
      final maxDy = playerHalfH + enemy.size.y * 0.5 + 64.0;
      if (dx > maxDx || dy > maxDy) continue;
      final enemyRect = enemy is SentryTurret
          ? enemy.worldHitboxRect
          : enemy.toRect();
      if (playerRect.overlaps(enemyRect)) {
        player.takeDamage(enemy.contactDamage);
        enemy.onContactDamageApplied();
        break; // Один удар за кадр
      }
    }
  }

  void _handleEnemyProjectiles() {
    if (enemyProjectiles.isEmpty) return;
    final playerRect = player.worldHitboxRect;
    final playerCenter = player.absolutePosition;
    final playerHalfW = player.size.x * 0.5;
    final playerHalfH = player.size.y * 0.5;
    for (var projectile in enemyProjectiles) {
      if (!projectile.isMounted || !projectile.isAlive) continue;
      final bulletCenter = projectile.absolutePosition;
      final dx = (bulletCenter.x - playerCenter.x).abs();
      final dy = (bulletCenter.y - playerCenter.y).abs();
      final maxDx = playerHalfW + projectile.size.x * 0.5 + 24.0;
      final maxDy = playerHalfH + projectile.size.y * 0.5 + 24.0;
      if (dx > maxDx || dy > maxDy) continue;
      final bulletRect = projectile.worldRect;
      if (playerRect.overlaps(bulletRect)) {
        player.takeDamage(projectile.damage);
        projectile.onHit();
      }
    }
  }
}
