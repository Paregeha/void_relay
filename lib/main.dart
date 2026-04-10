import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config/game_config.dart';
import 'flame_game.dart';
import 'ui/game_hud.dart';
import 'ui/screens/game_over_screen.dart';
import 'ui/screens/main_menu.dart';
import 'ui/screens/pause_screen.dart';
import 'ui/screens/reward_screen.dart';
import 'ui/screens/sector_transition_screen.dart';
import 'ui/ui_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Keep gameplay horizontal on mobile platforms.
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final VoidRelayGame _game = VoidRelayGame();

  bool get _canExitFromMenu {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.iOS) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: AspectRatio(
            aspectRatio: GameConfig.logicalWidth / GameConfig.logicalHeight,
            child: Focus(
              autofocus: true,
              onKeyEvent: (node, event) {
                if (event is! KeyDownEvent) {
                  return KeyEventResult.ignored;
                }
                final handled = _game.handleAppInputKey(event.logicalKey);
                return handled
                    ? KeyEventResult.handled
                    : KeyEventResult.ignored;
              },
              child: GameWidget<VoidRelayGame>(
                game: _game,
                overlayBuilderMap: {
                  UiManager.mainMenuOverlay: (context, game) => MainMenuScreen(
                    onStart: game.startFromMainMenu,
                    onExit: _canExitFromMenu
                        ? () {
                            SystemNavigator.pop();
                          }
                        : null,
                  ),
                  UiManager.hudOverlay: (context, game) => GameHud(game: game),
                  UiManager.rewardOverlay: (context, game) => RewardScreen(
                    onChooseHullPatch: () => game.applyRewardAndAdvance(
                      SectorRewardChoice.hullPatch,
                    ),
                    onChooseCoolingPulse: () => game.applyRewardAndAdvance(
                      SectorRewardChoice.coolingPulse,
                    ),
                  ),
                  UiManager.pauseOverlay: (context, game) => PauseScreen(
                    onResume: game.resumeFromPause,
                    onExit: () {
                      game.resumeFromPause();
                    },
                  ),
                  UiManager.gameOverOverlay: (context, game) =>
                      GameOverScreen(onRestart: game.resetAfterGameOver),
                  UiManager.transitionOverlay: (context, game) =>
                      SectorTransitionScreen(
                        currentSectorNumber: game.currentRoomIndex + 1,
                        nextSectorNumber: game.currentRoomIndex + 2,
                        transitionReason: game.transitionReason,
                        onContinue: game.openRewardStepFromTransition,
                      ),
                },
                initialActiveOverlays: const [
                  UiManager.hudOverlay,
                  UiManager.mainMenuOverlay,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
