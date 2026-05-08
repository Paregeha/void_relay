import 'package:flutter/material.dart';

class NewGameFirstTimePromptScreen extends StatelessWidget {
  final VoidCallback onYes;
  final VoidCallback onNo;

  const NewGameFirstTimePromptScreen({
    super.key,
    required this.onYes,
    required this.onNo,
  });

  @override
  Widget build(BuildContext context) {
    const neonCyan = Color(0xFF35D8FF);
    const neonBlue = Color(0xFF1E6BFF);

    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xE60A1324),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: neonCyan.withValues(alpha: 0.9),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: neonBlue.withValues(alpha: 0.34),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'NEW MISSION',
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  color: Color(0xFFCCF4FF),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Is this your first time here?',
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'If yes, we will show a short gameplay briefing before launch.',
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  color: neonCyan.withValues(alpha: 0.9),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onNo,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: neonCyan.withValues(alpha: 0.8),
                          width: 1,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('No, start now'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onYes,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF12365F),
                        foregroundColor: neonCyan,
                        side: const BorderSide(color: neonCyan, width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Yes, show briefing'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
