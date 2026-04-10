import 'package:flutter/material.dart';

class MainMenuScreen extends StatelessWidget {
  final VoidCallback onStart;
  final VoidCallback? onExit;

  const MainMenuScreen({super.key, required this.onStart, this.onExit});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B1016),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'VOID RELAY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'MVP Build',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Press Enter to start',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onStart,
                    child: const Text('Start Game'),
                  ),
                ),
                if (onExit != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onExit,
                      child: const Text('Exit'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
