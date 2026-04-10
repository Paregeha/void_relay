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

    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B1B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRelay
                  ? Colors.greenAccent.withValues(alpha: 0.7)
                  : Colors.cyanAccent.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Іконка + причина переходу
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isRelay ? Icons.wifi_tethering : Icons.check_circle_outline,
                    color: isRelay ? Colors.greenAccent : Colors.cyanAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    transitionReason,
                    style: TextStyle(
                      color: isRelay ? Colors.greenAccent : Colors.cyanAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Sector $currentSectorNumber Cleared',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Entering Sector $nextSectorNumber...',
                style: const TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRelay
                        ? Colors.green[800]
                        : Colors.blueGrey[800],
                  ),
                  onPressed: onContinue,
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
