import 'dart:math';

import 'package:flame/components.dart';

import '../../config/game_config.dart';
import '../../player/player_component.dart';
import '../base_enemy.dart';

enum HoverDroneAiState { patrol, engaged, approach, holdDistance, shoot }

class HoverDroneAI {
  HoverDroneAiState _movementState = HoverDroneAiState.patrol;
  HoverDroneAiState _currentState = HoverDroneAiState.patrol;
  bool _canShoot = false;
  bool _facingRight = false;
  int _preferredStrafeDirection = 1;
  double _distanceToPlayer = double.infinity;
  bool _wasWithinDetection = false;
  Vector2? _patrolCenter;
  int _patrolDirection = 1;

  double time = 0;

  HoverDroneAiState get currentState => _currentState;
  HoverDroneAiState get movementState => _movementState;
  bool get canShoot => _canShoot;
  // Backward-compatible alias for call sites/tests that still use old naming.
  bool get canShootStraight => _canShoot;
  bool get facingRight => _facingRight;
  double get distanceToPlayer => _distanceToPlayer;

  void update(BaseEnemy enemy, PlayerComponent player, double dt) {
    time += dt;
    _patrolCenter ??= enemy.position.clone();

    final toPlayer = player.position - enemy.position;
    final distance = toPlayer.length;
    _distanceToPlayer = distance;

    if (toPlayer.x > GameConfig.droneDirectionThreshold) {
      _preferredStrafeDirection = 1;
      _facingRight = true;
    } else if (toPlayer.x < -GameConfig.droneDirectionThreshold) {
      _preferredStrafeDirection = -1;
      _facingRight = false;
    }

    final withinDetection = distance <= GameConfig.droneDetectionRange;
    if (!withinDetection) {
      _wasWithinDetection = false;
      _canShoot = false;
      _movementState = HoverDroneAiState.patrol;
      _setCurrentState(HoverDroneAiState.patrol);

      final center = _patrolCenter!;
      final leftBound = center.x - GameConfig.dronePatrolRadius;
      final rightBound = center.x + GameConfig.dronePatrolRadius;
      if (enemy.position.x <= leftBound) {
        _patrolDirection = 1;
      } else if (enemy.position.x >= rightBound) {
        _patrolDirection = -1;
      }

      enemy.velocity.x = _patrolDirection * GameConfig.dronePatrolSpeed;

      final hoverY =
          sin(time * GameConfig.droneHoverSpeed) *
          GameConfig.droneHoverAmplitude;
      final targetY = center.y + hoverY;
      final yDiff = targetY - enemy.position.y;
      enemy.velocity.y = yDiff.clamp(
        -GameConfig.droneVerticalSpeedLimit,
        GameConfig.droneVerticalSpeedLimit,
      );
      return;
    }

    var justEngaged = false;
    if (!_wasWithinDetection) {
      _wasWithinDetection = true;
      justEngaged = true;
      _setCurrentState(HoverDroneAiState.engaged);
    }

    final dx = player.position.x - enemy.position.x;
    _canShoot = withinDetection && distance <= GameConfig.droneAttackRange;

    final desiredY = player.position.y;
    final yDiff = desiredY - enemy.position.y;
    final hoverVelocity = sin(time * 2.2) * 3.0;
    final speedMul = enemy.difficultySpeedMultiplier;
    final cappedVerticalSpeed = GameConfig.droneVerticalSpeedLimit * speedMul;
    final cappedMoveSpeed = GameConfig.droneMoveSpeed * speedMul;

    final desiredMaxDistance =
        GameConfig.dronePreferredDistance + GameConfig.droneStopTolerance;
    final shouldApproach = distance > desiredMaxDistance;
    if (shouldApproach) {
      _movementState = HoverDroneAiState.approach;
    } else {
      _movementState = HoverDroneAiState.holdDistance;
    }

    switch (_movementState) {
      case HoverDroneAiState.approach:
        final horizontalDirection =
            dx.abs() <= GameConfig.droneDirectionThreshold
            ? _preferredStrafeDirection.toDouble()
            : (dx > 0 ? 1.0 : -1.0);
        final yVelocity = yDiff.clamp(
          -cappedVerticalSpeed,
          cappedVerticalSpeed,
        );
        enemy.velocity.x = horizontalDirection * cappedMoveSpeed;
        enemy.velocity.y = (yVelocity + hoverVelocity).clamp(
          -cappedMoveSpeed,
          cappedMoveSpeed,
        );
        if (!justEngaged) {
          _setCurrentState(HoverDroneAiState.approach);
        }
        break;

      case HoverDroneAiState.holdDistance:
        final holdYVelocity = yDiff.clamp(
          -cappedVerticalSpeed,
          cappedVerticalSpeed,
        );
        enemy.velocity.x = 0;
        enemy.velocity.y = (holdYVelocity + hoverVelocity).clamp(
          -cappedMoveSpeed,
          cappedMoveSpeed,
        );
        if (!justEngaged) {
          _setCurrentState(
            _canShoot
                ? HoverDroneAiState.shoot
                : HoverDroneAiState.holdDistance,
          );
        }
        break;

      case HoverDroneAiState.patrol:
      case HoverDroneAiState.engaged:
      case HoverDroneAiState.shoot:
        // Not used as movement branches; movement is controlled by approach/holdDistance.
        break;
    }
  }

  void _setCurrentState(HoverDroneAiState next) {
    if (_currentState == next) {
      return;
    }
    _currentState = next;
  }
}
