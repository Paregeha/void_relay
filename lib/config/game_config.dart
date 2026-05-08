class GameConfig {
  // --- Feature toggles (temporary cleanup mode) ---
  static const bool enableEnemies = true;
  static const bool enableCoreHeating = true;

  // --- Camera / viewport ---
  static const double logicalWidth = 960.0;
  static const double logicalHeight = 540.0;
  static const double defaultWorldWidth = 3840.0;
  static const double defaultWorldHeight = 540.0;
  // 1.0 = hard follow (no lag), <1 = smooth interpolation.
  static const double cameraFollowSmoothing = 0.18;
  // Positive value keeps player lower on screen (more space ahead/above).
  static const double cameraVerticalOffset = 140.0;

  // --- Player movement ---
  static const double playerSpeed = 200.0;
  static const double playerSprintMultiplier = 1.45;
  static const double playerJumpForce = -400.0;
  static const int playerMaxJumps = 2;
  static const double playerDashForce = 600.0;
  static const double gravity = 800.0;
  static const double maxFallSpeed = 500.0;

  // --- Player health ---
  static const double playerMaxHealth = 100.0;
  static const bool playerGodMode = false;
  static const double playerDeathSequenceDuration = 3.0;
  static const double playerDeathOverlayOpacity = 0.45;

  // --- Combat (MVP tuning) ---
  static const double invulnerabilityDuration = 1.0;
  static const double enemyContactDamage = 8.0;

  // Player projectiles
  static const double playerProjectileLifetime = 2.4;
  static const String playerBulletSpritePath =
      'assets/sprites/player/player_bullet.png';

  // Weapon shooting configs (autoGun / sniperGun)
  static const double autoGunFireCooldown = 0.22;
  static const double autoGunBulletSpeed = 520.0;
  static const double autoGunBulletRange = 380.0;
  static const double autoGunBulletDamage = 1.0;
  static const double autoGunBulletSpawnOffsetX = 44.0;
  static const double autoGunBulletSpawnOffsetY = -10.0;

  static const double sniperGunFireCooldown = 0.85;
  static const double sniperGunBulletSpeed = 900.0;
  static const double sniperGunBulletRange = 850.0;
  static const double sniperGunBulletDamage = 3.0;
  static const double sniperGunBulletSpawnOffsetX = 54.0;
  // Increase this value to move sniper muzzle spawn lower on screen.
  static const double sniperGunBulletSpawnOffsetY = -12.0;

  static const double playerBulletWidth = 22.0;
  static const double playerBulletHeight = 8.0;

  static const double pulseBlasterDamage = 16.0;
  static const double pulseBlasterSpeed = 330.0;
  static const double pulseBlasterFireInterval = 0.16;

  static const double beamCutterDamage = 34.0;
  static const double beamCutterSpeed = 500.0;
  static const double beamCutterFireInterval = 0.45;
  static const double beamCutterLifetime = 2.8;

  // Enemy TTK targets based on the default player bullet damage.
  static const double enemy3HitsToKill = 3.0;
  static const double droneHitsToKill = 5.0;
  static const double turretHitsToKill = 10.0;
  static const double enemy3TargetHp = autoGunBulletDamage * enemy3HitsToKill;
  static const double droneTargetHp = autoGunBulletDamage * droneHitsToKill;
  static const double turretTargetHp = autoGunBulletDamage * turretHitsToKill;

  // Enemy health
  static const bool showEnemyHpBars = true;
  static const double baseEnemyHealth = 100.0;
  static const double crawlerHealth = 55.0;
  static const double hoverDroneHealth = droneTargetHp;
  static const double sentryTurretMaxHealth = turretTargetHp;
  static const double sentryTurretHealth = sentryTurretMaxHealth;

  // Enemy movement/combat
  static const double enemyDefaultSpeedX = -50.0;

  static const double enemyProjectileDamage = 8.0;
  static const double enemyProjectileSpeed = 220.0;
  static const double enemyProjectileLifetime = 2.2;

  static const double hoverDroneProjectileDamage = 12.0;
  static const double hoverDroneProjectileSpeed = 210.0;
  static const double hoverDroneProjectileLifetime = 2.4;
  static const double droneDetectionRange = 460.0;
  static const double droneAttackRange = 460.0;
  static const double dronePreferredDistance = 300.0;
  static const double droneStopTolerance = 35.0;
  static const double droneMoveSpeed = 90.0;
  static const double droneShootCooldown = 1.4;
  static const double dronePatrolRadius = 180.0;
  static const double dronePatrolSpeed = 45.0;
  static const double droneHoverAmplitude = 12.0;
  static const double droneHoverSpeed = 2.0;
  static const double dronePreferredYOffset = 80.0;
  static const double droneVerticalSpeedLimit = 70.0;
  static const double droneDirectionThreshold = 0.1;
  static const double droneShootVerticalTolerance = 26.0;

  static const double hoverDroneFireInterval = droneShootCooldown;

  static const double sentryTurretProjectileDamage = 20.0;
  static const double sentryTurretProjectileSpeed = 250.0;
  static const double sentryTurretProjectileLifetime = 2.0;
  static const double sentryTurretFireInterval = 2.2;
  static const double sentryTurretDetectionRange = 560.0;
  static const double sentryTurretShootingRange = 460.0;
  static const double sentryTurretVerticalTolerance = 110.0;
  static const bool sentryTurretSpriteFacesRight = true;
  static const double sentryTurretGroundYOffset = -12.0;
  static const double sentryTurretMuzzleOffsetY = -16.0;

  // --- Collision ---
  static const double platformCollisionTolerance = 8.0;
  static const double platformSnapTolerance = 4.0;
  static const double horizontalCollisionTolerance = 1.0;

  // --- Heat system ---
  static const bool heatEnabled = enableCoreHeating;
  static const double heatIncreasePerSecond = 6.0;
  static const double coreHeatGainMultiplier = 0.66;
  static const double maxHeat = 100.0;
  static const double overheatThreshold = 100.0;

  // --- Cooling station ---
  static const double coolingStationHeatReduce = 45.0;
  static const double coolingStationRadius = 48.0;

  static const String overheatEventName = 'OVERHEAT';

  // --- Hazard Events ---
  static const bool hazardEventsEnabled = true;
  static const double timeBetweenHazardEvents =
      15.0; // спроба запустити событие кожні 15 сек

  // Deterministic trigger tuning (heat + sector + timer escalation)
  static const double hazardMinInterval = 6.0;
  static const double hazardIntervalReductionPerSector = 1.25;

  static const double blackoutCooldown = 10.0;
  static const double toxicGasCooldown = 12.0;
  static const double systemBreakdownCooldown = 16.0;
  static const double doorFailureCooldown = 18.0;

  static const double blackoutHeatThreshold = 0.40; // normalized heat (0..1)
  static const double toxicGasHeatThreshold = 0.50; // normalized heat (0..1)
  static const double systemBreakdownHeatThreshold =
      0.78; // normalized heat (0..1)
  static const double doorFailureHeatThreshold = 0.72; // normalized heat (0..1)

  static const double blackoutSectorTimeThreshold = 18.0;
  static const double toxicGasSectorTimeThreshold = 14.0;
  static const double systemBreakdownSectorTimeThreshold = 38.0;
  static const double doorFailureSectorTimeThreshold = 24.0;

  static const bool doorFailureOncePerSector = true;
  static const int doorFailureMinSectorIndex = 0;

  // Blackout event
  static const double blackoutDuration = 3.5; // затемнення тривае 3.5 сек
  static const double blackoutOpacity = 0.85; // прозорість темного екрану

  // Toxic gas event
  static const double toxicGasDuration = 6.0; // отруйний газ тривае 6 сек
  static const double toxicGasDamagePerTick = 8.0; // шкода за один тік
  static const double toxicGasDamageInterval =
      0.3; // тік кожні 0.3 сек (~3 тіки в сек)
  static const double toxicGasOpacity = 0.6; // прозорість зеленого overlay

  // System breakdown event
  static const double systemBreakdownDuration =
      9999.0; // manual resolve; значення-запобіжник

  // Door failure event
  static const double doorFailureDuration =
      9999.0; // manual resolve; значення-запобіжник
  static const double doorRepairDuration =
      1.8; // скільки стояти в зоні gate для repair
}
