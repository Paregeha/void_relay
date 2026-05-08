import 'package:flutter/foundation.dart';

import '../../config/game_config.dart';

class Enemy3Config {
  static const double maxHp = GameConfig.enemy3TargetHp;

  static const double moveSpeed = 70;
  static const double detectionRange = 560;
  static const double preferredDistance = 70;
  static const double stopDistance = 58;
  static const double shootDistance = 320;
  static const double facingDirectionThreshold = 10;
  static const double shootVerticalTolerance = 42;

  static const double fireCooldown = 0.8;
  static const double bulletSpeed = 380;
  static const double bulletRange = 650;
  static const double bulletDamage = 8;
  static const double targetOffsetY = -38;
  static const double bulletAngleOffset = 0;

  static const double bulletSpawnOffsetX = 50;
  static const double bulletSpawnOffsetY = -104;

  static const double visualWidth = 56;
  static const double visualHeight = 64;
  static const double visualOffsetX = 20;
  static const double visualOffsetY = 0;

  static const double hitboxWidth = 34;
  static const double hitboxHeight = 56;
  static const double hitboxOffsetX = 0;
  // Negative value moves hitbox up from feet baseline.
  static const double hitboxOffsetY = -64;
  static const double baselineOffsetY = 0;
  static const double feetVisualOffsetY = 65;
  static const double gravity = 900;
  static const double maxFallSpeed = 900;
  static const double groundSnapTolerance = 8;

  static const int idleFrameCount = 21;
  static const int runFrameCount = 25;
  static const double idleStepTime = 0.12;
  // Slightly faster run frame cadence so legs align better with movement speed.
  static const double runStepTime = 0.06;

  // Temporary debug controls for Enemy3 animation verification.
  static const bool debugManualAnimationMode = false;
  static const bool debugShowFrameRect = false;
  static const bool debugRenderBounds = false;
  static const bool debugContours = false;
  static const bool debugLogs = false;
  static const bool debugHitbox = true;
  static const bool limitFramesForDebug = false;
  static const int debugFrameLimit = 2;
  static const int priority = 20;
  static const int enemyPriority = priority;
  static const int bulletPriority = 25;

  static const String idlePath = 'assets/sprites/enemies/enemy_idle.png';
  static const String idleAtlasPath =
      'assets/sprites/enemies/enemy_idle_atlas.json';
  static const String runPath = 'assets/sprites/enemies/enemy_run.png';
  static const String runAtlasPath =
      'assets/sprites/enemies/enemy_run_atlas.json';
  static const String bulletPath = 'assets/sprites/enemies/enemy_bullet.png';

  static const double sheetFrameWidth = 768;
  static const double sheetFrameHeight = 448;
  static const bool atlasUsesGridCellOffsets = true;

  // Fallbacks in case assets were added under a different root.
  static const List<String> idlePathCandidates = [
    idlePath,
    'assets/enemies/enemy_idle.png',
    'assets/enemy/enemy_idle.png',
  ];

  static const List<String> idleAtlasPathCandidates = [
    idleAtlasPath,
    'assets/enemies/enemy_idle_atlas.json',
    'assets/enemy/enemy_idle_atlas.json',
  ];

  static const List<String> runPathCandidates = [
    runPath,
    'assets/enemies/enemy_run.png',
    'assets/enemy/enemy_run.png',
  ];

  static const List<String> runAtlasPathCandidates = [
    runAtlasPath,
    'assets/enemies/enemy_run_atlas.json',
    'assets/enemy/enemy_run_atlas.json',
  ];

  static const List<String> bulletPathCandidates = [
    bulletPath,
    'assets/enemies/enemy_bullet.png',
    'assets/enemy/enemy_bullet.png',
  ];
}

void enemy3Log(String message) {
  if (!Enemy3Config.debugLogs) return;
  debugPrint('[Enemy3] $message');
}

// Backward-compatible alias for code still using EnemyConfig.
class EnemyConfig extends Enemy3Config {}
