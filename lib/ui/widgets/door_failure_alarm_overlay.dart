import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Fullscreen red alarm overlay for DOOR_FAILURE event.
class DoorFailureAlarmOverlay extends StatefulWidget {
  const DoorFailureAlarmOverlay({
    super.key,
    required this.isActive,
    this.fadeOutDuration = const Duration(milliseconds: 900),
  });

  final bool isActive;
  final Duration fadeOutDuration;

  @override
  State<DoorFailureAlarmOverlay> createState() =>
      _DoorFailureAlarmOverlayState();
}

class _DoorFailureAlarmOverlayState extends State<DoorFailureAlarmOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _blinkController;
  late final AnimationController _fadeOutController;

  bool _renderOverlay = false;
  bool _isDissipating = false;
  final Stopwatch _activeStopwatch = Stopwatch();

  static const int _blinkCycleMs = 2400;
  static const double _startBlendDurationSec = 0.8;

  @override
  void initState() {
    super.initState();
    _renderOverlay = widget.isActive;
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _blinkCycleMs),
    );
    _fadeOutController =
        AnimationController(vsync: this, duration: widget.fadeOutDuration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed && mounted) {
              setState(() {
                _isDissipating = false;
                _renderOverlay = false;
              });
            }
          });

    if (widget.isActive) {
      _blinkController.repeat();
      _activeStopwatch
        ..reset()
        ..start();
    }
  }

  @override
  void didUpdateWidget(covariant DoorFailureAlarmOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isActive) {
      if (!_renderOverlay || _isDissipating) {
        setState(() {
          _renderOverlay = true;
          _isDissipating = false;
        });
        _activeStopwatch
          ..reset()
          ..start();
      }
      _fadeOutController.stop();
      _fadeOutController.value = 0;
      if (!_blinkController.isAnimating) {
        _blinkController.repeat();
      }
      return;
    }

    if (_renderOverlay && !_isDissipating) {
      setState(() {
        _isDissipating = true;
      });
      _activeStopwatch.stop();
      _fadeOutController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _fadeOutController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_renderOverlay && !widget.isActive) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([_blinkController, _fadeOutController]),
        builder: (context, _) {
          final activeElapsed = _activeStopwatch.elapsedMilliseconds / 1000.0;

          final fadeMul = _isDissipating
              ? 1.0 - Curves.easeOut.transform(_fadeOutController.value)
              : 1.0;

          final alpha = (_computeAlarmAlpha(activeElapsed) * fadeMul).clamp(
            0.0,
            0.35,
          );

          if (alpha <= 0.001) {
            return const SizedBox.shrink();
          }

          return ColoredBox(
            color: const Color(0xFFFF1E1E).withValues(alpha: alpha),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }

  double _computeAlarmAlpha(double elapsedSec) {
    final phase = (_blinkController.value * math.pi * 2 * 1.3);
    final pulse = (math.sin(phase) + 1.0) * 0.5;
    final baseAlpha = 0.10 + pulse * 0.14;
    final startBlend = Curves.easeOutCubic.transform(
      (elapsedSec / _startBlendDurationSec).clamp(0.0, 1.0),
    );
    return baseAlpha * startBlend;
  }
}
