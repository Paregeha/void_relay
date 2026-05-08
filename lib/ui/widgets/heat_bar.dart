import 'package:flutter/material.dart';

class HeatBar extends StatefulWidget {
  final double current;
  final double max;

  const HeatBar({super.key, required this.current, required this.max});

  @override
  State<HeatBar> createState() => _HeatBarState();
}

class _HeatBarState extends State<HeatBar> with SingleTickerProviderStateMixin {
  late final AnimationController _coolingController;
  Animation<double>? _coolingAnimation;
  double _displayRatio = 0.0;

  @override
  void initState() {
    super.initState();
    _coolingController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 280),
        )..addListener(() {
          final anim = _coolingAnimation;
          if (anim == null) return;
          setState(() {
            _displayRatio = anim.value;
          });
        });
    _displayRatio = _targetRatio(widget.current, widget.max);
  }

  @override
  void didUpdateWidget(covariant HeatBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = _targetRatio(widget.current, widget.max);

    // Cooling should feel responsive but readable: animate only decreases.
    if (target < _displayRatio) {
      _coolingAnimation = Tween<double>(begin: _displayRatio, end: target)
          .animate(
            CurvedAnimation(
              parent: _coolingController,
              curve: Curves.easeOutCubic,
            ),
          );
      _coolingController
        ..reset()
        ..forward();
      return;
    }

    _coolingController.stop();
    _coolingAnimation = null;
    _displayRatio = target;
  }

  @override
  void dispose() {
    _coolingController.dispose();
    super.dispose();
  }

  double _targetRatio(double current, double max) {
    final safeMax = max <= 0 ? 1.0 : max;
    return (current / safeMax).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final safeMax = widget.max <= 0 ? 1.0 : widget.max;
    final ratio = _displayRatio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'HEAT ${widget.current.toStringAsFixed(0)}/${safeMax.toStringAsFixed(0)}',
          style: const TextStyle(
            fontFamily: 'Orbitron',
            color: Color(0xFFFFD7A8),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: const Color(0xFFFF9E4A).withValues(alpha: 0.85),
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x55FF6A00), blurRadius: 10),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: const Color(0x332A1A0C),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFFF7A1A),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
