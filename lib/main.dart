import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config/game_config.dart';
import 'flame_game.dart';
import 'ui/game_hud.dart';
import 'ui/screens/game_over_screen.dart';
import 'ui/screens/leaderboard_screen.dart';
import 'ui/screens/load_game_screen.dart';
import 'ui/screens/main_menu.dart';
import 'ui/screens/new_game_first_time_prompt_screen.dart';
import 'ui/screens/new_game_instruction_screen.dart';
import 'ui/screens/pause_screen.dart';
import 'ui/screens/reward_screen.dart';
import 'ui/screens/sector_transition_screen.dart';
import 'ui/ui_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Disable all debugPrint output globally.
  debugPrint = (String? _, {int? wrapWidth}) {};
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

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final VoidRelayGame _game = VoidRelayGame();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final focused = state == AppLifecycleState.resumed;
    _game.setAppFocus(focused);
  }

  bool get _canExitFromMenu {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.iOS) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Orbitron'),
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: AspectRatio(
            aspectRatio: GameConfig.logicalWidth / GameConfig.logicalHeight,
            child: Focus(
              autofocus: true,
              onFocusChange: (hasFocus) => _game.setAppFocus(hasFocus),
              onKeyEvent: (node, event) {
                if (event is! KeyDownEvent) {
                  return KeyEventResult.ignored;
                }
                _game.notifyGlobalUserGesture();
                final handled = _game.handleAppInputKey(event.logicalKey);
                return handled
                    ? KeyEventResult.handled
                    : KeyEventResult.ignored;
              },
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) => _game.notifyGlobalUserGesture(),
                child: GameWidget<VoidRelayGame>(
                  game: _game,
                  overlayBuilderMap: {
                    UiManager.mainMenuOverlay: (context, game) =>
                        MainMenuScreen(
                          onUserInteraction: game.notifyGlobalUserGesture,
                          onStart: () {
                            game.playButtonClickSound();
                            game.openNewGameFirstTimePrompt();
                          },
                          onLoadGame: () {
                            game.playButtonClickSound();
                            game.openLoadGameFromMainMenu();
                          },
                          onOpenLeaderboard: () {
                            game.playButtonClickSound();
                            game.openLeaderboardFromMainMenu();
                          },
                          onExit: _canExitFromMenu
                              ? () {
                                  game.playButtonClickSound();
                                  SystemNavigator.pop();
                                }
                              : null,
                        ),
                    UiManager.loadGameOverlay: (context, game) =>
                        LoadGameScreen(
                          mode: SaveSlotsMode.load,
                          onUiClick: game.playButtonClickSound,
                          onBack: game.closeLoadGameOverlay,
                          onLoad: game.loadGameBySlotId,
                        ),
                    UiManager.leaderboardOverlay: (context, game) =>
                        LeaderboardScreen(
                          onUiClick: game.playButtonClickSound,
                          onBack: game.closeLeaderboardOverlay,
                        ),
                    UiManager.saveSlotsOverlay: (context, game) =>
                        LoadGameScreen(
                          mode: SaveSlotsMode.save,
                          modal: true,
                          onUiClick: game.playButtonClickSound,
                          onBack: game.closeSaveSlotsOverlay,
                          onSave: game.saveGameToSlot,
                        ),
                    UiManager.hudOverlay: (context, game) =>
                        GameHud(game: game),
                    UiManager.rewardOverlay: (context, game) => RewardScreen(
                      onChooseHullPatch: () {
                        game.playButtonClickSound();
                        game.applyRewardAndAdvance(
                          SectorRewardChoice.hullPatch,
                        );
                      },
                      onChooseCoolingPulse: () {
                        game.playButtonClickSound();
                        game.applyRewardAndAdvance(
                          SectorRewardChoice.coolingPulse,
                        );
                      },
                    ),
                    UiManager.pauseOverlay: (context, game) => PauseScreen(
                      onResume: () {
                        game.playButtonClickSound();
                        game.resumeFromPause();
                      },
                      onSave: () {
                        game.playButtonClickSound();
                        game.openSaveSlotsFromPause();
                      },
                      onMenu: () {
                        game.playButtonClickSound();
                        game.openMainMenuFromPause();
                      },
                      onExit: _canExitFromMenu
                          ? () {
                              game.playButtonClickSound();
                              SystemNavigator.pop();
                            }
                          : () {
                              game.playButtonClickSound();
                              game.openMainMenuFromPause();
                            },
                    ),
                    UiManager.gameOverOverlay: (context, game) =>
                        GameOverScreen(
                          onRestart: () {
                            game.playButtonClickSound();
                            game.resetAfterGameOver();
                          },
                        ),
                    UiManager.transitionOverlay: (context, game) =>
                        SectorTransitionScreen(
                          currentSectorNumber: game.currentRoomIndex + 1,
                          nextSectorNumber: game.currentRoomIndex + 2,
                          transitionReason: game.transitionReason,
                          onContinue: () {
                            game.playButtonClickSound();
                            game.openRewardStepFromTransition();
                          },
                        ),
                    UiManager.firstTimePromptOverlay: (context, game) =>
                        NewGameFirstTimePromptScreen(
                          onNo: () {
                            game.playButtonClickSound();
                            game.confirmNewGameFirstTimeSelection(
                              isFirstTime: false,
                            );
                          },
                          onYes: () {
                            game.playButtonClickSound();
                            game.confirmNewGameFirstTimeSelection(
                              isFirstTime: true,
                            );
                          },
                        ),
                    UiManager.firstTimeInstructionOverlay: (context, game) =>
                        NewGameInstructionScreen(
                          onClose: () {
                            game.playButtonClickSound();
                            game.closeFirstTimeInstruction();
                          },
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
      ),
    );
  }
}
