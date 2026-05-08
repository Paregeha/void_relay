import 'package:flutter/material.dart';

class HealthBar extends StatelessWidget {
  final double current;
  final double max;

  const HealthBar({super.key, required this.current, required this.max});

  @override
  Widget build(BuildContext context) {
    final safeMax = max <= 0 ? 1.0 : max;
    final ratio = (current / safeMax).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'HP ${current.toStringAsFixed(0)}/${safeMax.toStringAsFixed(0)}',
          style: const TextStyle(
            fontFamily: 'Orbitron',
            color: Colors.white,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: const Color(0xFF00D9FF).withValues(alpha: 0.8),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E6BFF).withValues(alpha: 0.24),
                blurRadius: 10,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: const Color(0x33213A5A),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF35D8FF),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
