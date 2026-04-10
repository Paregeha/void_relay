import '../config/game_config.dart';
import '../flame_game.dart';

class UiManager {
  const UiManager();

  static const String mainMenuOverlay = 'MAIN_MENU';
  static const String hudOverlay = 'HUD';
  static const String rewardOverlay = 'REWARD';
  static const String pauseOverlay = 'PAUSE';
  static const String gameOverOverlay = 'GAME_OVER';
  static const String transitionOverlay = 'SECTOR_TRANSITION';
  static const String blackoutOverlay = 'BLACKOUT';

  static const String objectiveReachRelay = 'Reach relay';
  static const String objectiveCoolingRecommended = 'Cooling recommended';
  static const String objectiveClearHostiles = 'Clear hostiles';
  static const String objectiveRepairRequired = 'Repair required';

  double readHealth(VoidRelayGame game) => game.gameWorld?.player.health ?? 0.0;

  double readMaxHealth(VoidRelayGame game) =>
      game.gameWorld?.player.maxHealth ?? 100.0;

  double readHeat(VoidRelayGame game) =>
      game.heatBloc?.state.currentHeat ?? 0.0;

  double readMaxHeat() => GameConfig.maxHeat;

  String readWeaponName(VoidRelayGame game) {
    final manager = game.gameWorld?.player.weaponManager;
    if (manager == null) return 'Unknown';
    if (manager.loadoutSize <= 1) return manager.currentWeaponName;
    return 'S${manager.currentWeaponSlot}: ${manager.currentWeaponName}';
  }

  String readActiveWeaponName(VoidRelayGame game) {
    return game.gameWorld?.player.weaponManager.currentWeaponName ?? 'Unknown';
  }

  int readActiveWeaponSlot(VoidRelayGame game) {
    return game.gameWorld?.player.weaponManager.currentWeaponSlot ?? 1;
  }

  String readSecondaryWeaponName(VoidRelayGame game) {
    return game.gameWorld?.player.weaponManager.secondaryWeaponName ?? '-';
  }

  int? readSecondaryWeaponSlot(VoidRelayGame game) {
    return game.gameWorld?.player.weaponManager.secondaryWeaponSlot;
  }

  void showMainMenu(VoidRelayGame game) {
    if (!game.overlays.isActive(mainMenuOverlay)) {
      game.overlays.add(mainMenuOverlay);
    }
    game.pauseEngine();
  }

  void hideMainMenu(VoidRelayGame game) {
    game.overlays.remove(mainMenuOverlay);
  }

  void showHud(VoidRelayGame game) {
    if (!game.overlays.isActive(hudOverlay)) {
      game.overlays.add(hudOverlay);
    }
  }

  void showReward(VoidRelayGame game) {
    if (!game.overlays.isActive(rewardOverlay)) {
      game.overlays.add(rewardOverlay);
    }
    game.pauseEngine();
  }

  void hideReward(VoidRelayGame game) {
    game.overlays.remove(rewardOverlay);
  }

  void hideHud(VoidRelayGame game) {
    game.overlays.remove(hudOverlay);
  }

  void showPause(VoidRelayGame game) {
    game.pauseEngine();
    game.overlays.add(pauseOverlay);
  }

  void hidePause(VoidRelayGame game) {
    game.overlays.remove(pauseOverlay);
    game.resumeEngine();
  }

  void togglePause(VoidRelayGame game) {
    if (game.overlays.isActive(pauseOverlay)) {
      hidePause(game);
    } else {
      showPause(game);
    }
  }

  void showGameOver(VoidRelayGame game) {
    game.pauseEngine();
    game.overlays.add(gameOverOverlay);
  }

  void hideGameOver(VoidRelayGame game) {
    game.overlays.remove(gameOverOverlay);
  }

  void showTransition(VoidRelayGame game) {
    game.pauseEngine();
    game.overlays.add(transitionOverlay);
  }

  void hideTransition(VoidRelayGame game) {
    game.overlays.remove(transitionOverlay);
    game.resumeEngine();
  }

  void closeTransientScreens(VoidRelayGame game) {
    game.overlays.remove(mainMenuOverlay);
    game.overlays.remove(rewardOverlay);
    game.overlays.remove(pauseOverlay);
    game.overlays.remove(gameOverOverlay);
    game.overlays.remove(transitionOverlay);
  }

  String readObjectivePrompt(VoidRelayGame game) {
    final maxHeat = readMaxHeat();
    final heatRatio = maxHeat <= 0 ? 0.0 : readHeat(game) / maxHeat;

    final maxHealth = game.maxHealthValue <= 0 ? 1.0 : game.maxHealthValue;
    final healthRatio = game.currentHealthValue / maxHealth;

    // Priority: blocking failures > critical health > high heat > combat > navigation.
    if (game.isDoorFailureActive || game.isSystemBreakdownActive) {
      return objectiveRepairRequired;
    }
    if (healthRatio <= 0.35) {
      return objectiveRepairRequired;
    }
    if (heatRatio >= 0.7) {
      return objectiveCoolingRecommended;
    }
    if (game.hasAliveHostiles) {
      return objectiveClearHostiles;
    }
    return objectiveReachRelay;
  }
}
