import 'dart:async';

import 'package:flutter/material.dart';

import '../config/game_config.dart';
import '../flame_game.dart';
import 'ui_manager.dart';
import 'widgets/blackout_spotlight_overlay.dart';
import 'widgets/door_failure_alarm_overlay.dart';
import 'widgets/health_bar.dart';
import 'widgets/heat_bar.dart';
import 'widgets/toxic_gas_overlay.dart';

class GameHud extends StatefulWidget {
  final VoidRelayGame game;

  const GameHud({super.key, required this.game});

  @override
  State<GameHud> createState() => _GameHudState();
}

class _GameHudState extends State<GameHud> {
  final UiManager _ui = const UiManager();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Просте періодичне оновлення для показників із Flame-компонентів.
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const neonCyan = Color(0xFF00D9FF);
    const neonBlue = Color(0xFF1E6BFF);
    final health = _ui.readHealth(widget.game);
    final maxHealth = _ui.readMaxHealth(widget.game);
    final heat = _ui.readHeat(widget.game);
    final maxHeat = _ui.readMaxHeat();
    final activeWeaponName = _ui.readActiveWeaponName(widget.game);
    final activeWeaponSlot = _ui.readActiveWeaponSlot(widget.game);
    final objectivePrompt = _ui.readObjectivePrompt(widget.game);
    final score = widget.game.score;
    final exitBlockedMessage = widget.game.exitBlockedMessage;
    final isBlackoutActive = widget.game.isBlackoutActive;
    final isToxicGasActive = widget.game.isToxicGasActive;
    final isDoorFailureActive = widget.game.isDoorFailureActive;
    final isSystemBreakdownActive = widget.game.isSystemBreakdownActive;
    final hazardSystem = widget.game.hazardSystem;
    final hazardProgress = hazardSystem?.currentEventProgress ?? 0.0;
    final isDeathSequenceActive = widget.game.isDeathSequenceActive;
    final isPauseOpen = widget.game.isPauseOpen;

    return Stack(
      children: [
        IgnorePointer(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xCC03111F),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: neonCyan.withValues(alpha: 0.8),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: neonBlue.withValues(alpha: 0.28),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HealthBar(current: health, max: maxHealth),
                        const SizedBox(height: 10),
                        if (GameConfig.enableCoreHeating) ...[
                          HeatBar(current: heat, max: maxHeat),
                          const SizedBox(height: 10),
                        ],
                        Container(
                          width: 220,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x331A3350),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: neonCyan.withValues(alpha: 0.7),
                            ),
                          ),
                          child: Text(
                            'Weapon [$activeWeaponSlot]: $activeWeaponName',
                            style: const TextStyle(
                              fontFamily: 'Orbitron',
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 220,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x331A3350),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: neonCyan.withValues(alpha: 0.7),
                            ),
                          ),
                          child: Text(
                            'Score: $score',
                            style: const TextStyle(
                              fontFamily: 'Orbitron',
                              color: Color(0xFFBDF4FF),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x331A3350),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: neonCyan.withValues(alpha: 0.7),
                            ),
                          ),
                          child: Text(
                            objectivePrompt,
                            style: const TextStyle(
                              fontFamily: 'Orbitron',
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 12, right: 12),
              child: Material(
                color: const Color(0xCC03111F),
                borderRadius: BorderRadius.circular(10),
                shadowColor: neonBlue.withValues(alpha: 0.35),
                elevation: 8,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    widget.game.playButtonClickSound();
                    if (widget.game.isPauseOpen) {
                      widget.game.resumeFromPause();
                    } else {
                      widget.game.triggerPause();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPauseOpen ? Icons.play_arrow : Icons.pause,
                          color: const Color(0xFF7DF9FF),
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isPauseOpen ? 'Resume' : 'Pause',
                          style: const TextStyle(
                            fontFamily: 'Orbitron',
                            color: Color(0xFFBDF4FF),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (isBlackoutActive)
          BlackoutSpotlightOverlay(
            game: widget.game,
            opacity: GameConfig.blackoutOpacity,
          ),
        DoorFailureAlarmOverlay(isActive: isDoorFailureActive),
        ClipRect(
          child: ToxicGasOverlay(
            isActive: isToxicGasActive,
            progress: hazardProgress,
            opacity: GameConfig.toxicGasOpacity,
          ),
        ),
        if (exitBlockedMessage != null)
          IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: SafeArea(
                child: Container(
                  margin: const EdgeInsets.only(top: 68),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xCC170512),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFFF5A87).withValues(alpha: 0.95),
                    ),
                    boxShadow: [
                      BoxShadow(color: const Color(0xAAFF2E63), blurRadius: 18),
                    ],
                  ),
                  child: Text(
                    exitBlockedMessage,
                    style: const TextStyle(
                      fontFamily: 'Orbitron',
                      color: Color(0xFFFFD4E2),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (isSystemBreakdownActive)
          IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: SafeArea(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xCC03111F),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: neonCyan.withValues(alpha: 0.8)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'SYSTEM BREAKDOWN',
                        style: TextStyle(
                          fontFamily: 'Orbitron',
                          color: Color(0xFF7DF9FF),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Activate switch console to restore systems',
                        style: TextStyle(
                          fontFamily: 'Orbitron',
                          color: Color(0xFFA7DDF4),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 180,
                        child: LinearProgressIndicator(
                          value: hazardProgress,
                          minHeight: 5,
                          backgroundColor: Colors.white.withValues(alpha: 0.18),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            neonCyan,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (isDeathSequenceActive)
          IgnorePointer(
            child: Container(
              color: Colors.red.withValues(
                alpha: GameConfig.playerDeathOverlayOpacity,
              ),
              child: const Center(
                child: Text(
                  'YOU DIE',
                  style: TextStyle(
                    fontFamily: 'Orbitron',
                    color: Colors.white,
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    shadows: [Shadow(color: Colors.black87, blurRadius: 12)],
                  ),
                ),
              ),
            ),
          ),
        // Drone debug controls moved to keyboard hotkeys.
      ],
    );
  }
}
