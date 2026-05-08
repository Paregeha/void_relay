import 'package:flutter/material.dart';

class RewardScreen extends StatelessWidget {
  final VoidCallback onChooseHullPatch;
  final VoidCallback onChooseCoolingPulse;

  const RewardScreen({
    super.key,
    required this.onChooseHullPatch,
    required this.onChooseCoolingPulse,
  });

  @override
  Widget build(BuildContext context) {
    const neonCyan = Color(0xFF6EF7FF);
    const neonMagenta = Color(0xFFFF4DA6);

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xEA050A12), Color(0xF5000000)],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xE0121927),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: neonCyan.withValues(alpha: 0.76)),
              boxShadow: [
                BoxShadow(
                  color: neonMagenta.withValues(alpha: 0.26),
                  blurRadius: 24,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'SECTOR REWARD',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Orbitron',
                    color: Color(0xFFDFF3FF),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose one upgrade for the next sector',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Orbitron',
                    color: neonCyan.withValues(alpha: 0.86),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onChooseHullPatch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF13253F),
                    foregroundColor: neonCyan,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: neonCyan.withValues(alpha: 0.85)),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  child: const Text(
                    'HULL PATCH (+10 MAX HP)',
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: onChooseCoolingPulse,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFFC177),
                    side: const BorderSide(
                      color: Color(0xFFFF9A4D),
                      width: 1.1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'COOLING PULSE (HEAT RESET + HAZARD DELAY)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
