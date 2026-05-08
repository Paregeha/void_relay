import 'package:flutter/material.dart';

class GameOverScreen extends StatelessWidget {
  final VoidCallback onRestart;

  const GameOverScreen({super.key, required this.onRestart});

  @override
  Widget build(BuildContext context) {
    const neonMagenta = Color(0xFFFF4DA6);
    const neonCyan = Color(0xFF6EF7FF);

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xF2080B14), Color(0xF0000000)],
        ),
      ),
      child: Center(
        child: Container(
          width: 360,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          decoration: BoxDecoration(
            color: const Color(0xE0111522),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: neonCyan.withValues(alpha: 0.72)),
            boxShadow: [
              BoxShadow(
                color: neonMagenta.withValues(alpha: 0.30),
                blurRadius: 22,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'GAME OVER',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  color: neonCyan,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  shadows: [Shadow(color: neonMagenta, blurRadius: 16)],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Core meltdown detected\nCrew vitals lost',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  color: Color(0xFFD6E8F8),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onRestart,
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
                    'RESTART SECTOR',
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
