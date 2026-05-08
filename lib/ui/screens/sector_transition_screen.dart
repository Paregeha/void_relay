import 'package:flutter/material.dart';

class SectorTransitionScreen extends StatelessWidget {
  final int currentSectorNumber;
  final int nextSectorNumber;
  final VoidCallback onContinue;
  final String transitionReason;

  const SectorTransitionScreen({
    super.key,
    this.currentSectorNumber = 1,
    this.nextSectorNumber = 2,
    required this.onContinue,
    this.transitionReason = 'Room cleared',
  });

  @override
  Widget build(BuildContext context) {
    final bool isRelay = transitionReason == 'Relay reached';
    final accent = isRelay ? const Color(0xFF6BFFB3) : const Color(0xFF6EF7FF);
    final accentGlow = isRelay
        ? const Color(0xFF00B96A)
        : const Color(0xFF3C6BFF);

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xEA050A12), Color(0xF5000000)],
        ),
      ),
      child: Center(
        child: Container(
          width: 360,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          decoration: BoxDecoration(
            color: const Color(0xE0121927),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.76)),
            boxShadow: [
              BoxShadow(
                color: accentGlow.withValues(alpha: 0.28),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isRelay ? Icons.wifi_tethering : Icons.check_circle_outline,
                    color: accent,
                    size: 18,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    transitionReason,
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      color: accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'SECTOR $currentSectorNumber CLEARED',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Orbitron',
                  color: Color(0xFFDFF3FF),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Preparing jump to sector $nextSectorNumber',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  color: accent.withValues(alpha: 0.85),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF13253F),
                    foregroundColor: accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: accent.withValues(alpha: 0.85)),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  onPressed: onContinue,
                  child: const Text(
                    'CONTINUE',
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
