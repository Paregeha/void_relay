import 'package:flutter/material.dart';

class HeatBar extends StatelessWidget {
  final double current;
  final double max;

  const HeatBar({super.key, required this.current, required this.max});

  @override
  Widget build(BuildContext context) {
    final safeMax = max <= 0 ? 1.0 : max;
    final ratio = (current / safeMax).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'HEAT ${current.toStringAsFixed(0)}/${safeMax.toStringAsFixed(0)}',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 180,
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 10,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(
              Colors.orangeAccent,
            ),
          ),
        ),
      ],
    );
  }
}
