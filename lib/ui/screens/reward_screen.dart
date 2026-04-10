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
    return Container(
      color: const Color(0xCC0A0F15),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF101924),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Sector Reward',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose one upgrade for the next sector',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onChooseHullPatch,
                  child: const Text('Hull Patch (+10 Max HP)'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: onChooseCoolingPulse,
                  child: const Text(
                    'Cooling Pulse (Heat reset + hazard delay)',
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
