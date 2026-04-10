import 'dart:async';

import 'package:flutter/material.dart';

import '../config/game_config.dart';
import '../flame_game.dart';
import 'ui_manager.dart';
import 'widgets/health_bar.dart';
import 'widgets/heat_bar.dart';
import 'widgets/weapon_slot.dart';

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
    final health = _ui.readHealth(widget.game);
    final maxHealth = _ui.readMaxHealth(widget.game);
    final heat = _ui.readHeat(widget.game);
    final maxHeat = _ui.readMaxHeat();
    final activeWeaponName = _ui.readActiveWeaponName(widget.game);
    final activeWeaponSlot = _ui.readActiveWeaponSlot(widget.game);
    final secondaryWeaponName = _ui.readSecondaryWeaponName(widget.game);
    final secondaryWeaponSlot = _ui.readSecondaryWeaponSlot(widget.game);
    final objectivePrompt = _ui.readObjectivePrompt(widget.game);
    final isBlackoutActive = widget.game.isBlackoutActive;
    final isToxicGasActive = widget.game.isToxicGasActive;
    final isSystemBreakdownActive = widget.game.isSystemBreakdownActive;
    final hazardSystem = widget.game.hazardSystem;
    final hazardProgress = hazardSystem?.currentEventProgress ?? 0.0;
    final isDeathSequenceActive = widget.game.isDeathSequenceActive;

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
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HealthBar(current: health, max: maxHealth),
                        const SizedBox(height: 10),
                        HeatBar(current: heat, max: maxHeat),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            objectivePrompt,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: WeaponSlot(
                      activeWeaponName: activeWeaponName,
                      activeWeaponSlot: activeWeaponSlot,
                      secondaryWeaponName: secondaryWeaponName,
                      secondaryWeaponSlot: secondaryWeaponSlot,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Blackout effect
        if (isBlackoutActive)
          IgnorePointer(
            child: Container(
              color: Colors.black.withValues(alpha: GameConfig.blackoutOpacity),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'BLACKOUT',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Systems offline',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Progress indicator for blackout duration
                    SizedBox(
                      width: 200,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: hazardProgress,
                          minHeight: 6,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation(
                            Colors.red.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // Toxic gas effect
        if (isToxicGasActive)
          IgnorePointer(
            child: Container(
              color: Colors.green.withValues(alpha: GameConfig.toxicGasOpacity),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'TOXIC GAS',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Taking damage - Find shelter!',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Progress indicator for toxic gas
                    SizedBox(
                      width: 200,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: hazardProgress,
                          minHeight: 6,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation(
                            Colors.green.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ),
                  ],
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
                    color: Colors.orange.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orangeAccent),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'SYSTEM BREAKDOWN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Activate switch console to restore systems',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 180,
                        child: LinearProgressIndicator(
                          value: hazardProgress,
                          minHeight: 5,
                          backgroundColor: Colors.white.withValues(alpha: 0.18),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.orangeAccent,
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
      ],
    );
  }
}
