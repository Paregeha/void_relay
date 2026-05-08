import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Animated toxic gas overlay rendered purely with Flutter drawing APIs.
class ToxicGasOverlay extends StatefulWidget {
  const ToxicGasOverlay({
    super.key,
    required this.isActive,
    required this.progress,
    required this.opacity,
    this.dissipateDuration = const Duration(milliseconds: 2200),
  });

  final bool isActive;
  final double progress;
  final double opacity;
  final Duration dissipateDuration;

  @override
  State<ToxicGasOverlay> createState() => _ToxicGasOverlayState();
}

class _ToxicGasOverlayState extends State<ToxicGasOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _dissipateController;
  static const int _visualCycleDurationMs = 3200;
  bool _renderOverlay = false;
  bool _isDissipating = false;
  double _lastActiveProgress = 0.0;
  bool _didLogClippedToViewport = false;

  @override
  void initState() {
    super.initState();
    _renderOverlay = widget.isActive;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _visualCycleDurationMs),
    );
    _dissipateController =
        AnimationController(vsync: this, duration: widget.dissipateDuration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed && mounted) {
              setState(() {
                _isDissipating = false;
                _renderOverlay = false;
              });
            }
          });

    if (widget.isActive) {
      _controller.repeat();
      _lastActiveProgress = widget.progress.clamp(0.0, 1.0);
    }
  }

  @override
  void didUpdateWidget(covariant ToxicGasOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isActive) {
      _lastActiveProgress = widget.progress.clamp(0.0, 1.0);
      if (!_renderOverlay || _isDissipating) {
        setState(() {
          _renderOverlay = true;
          _isDissipating = false;
        });
      }
      _dissipateController.stop();
      _dissipateController.value = 0;
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
      return;
    }

    if (_renderOverlay && !_isDissipating) {
      setState(() {
        _isDissipating = true;
      });
      _dissipateController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _dissipateController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_renderOverlay && !widget.isActive) {
      return const SizedBox.shrink();
    }

    final progress = widget.progress.clamp(0.0, 1.0);
    final opacity = widget.opacity.clamp(0.0, 1.0);
    if (widget.isActive) {
      _lastActiveProgress = progress;
    }

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([_controller, _dissipateController]),
        builder: (context, _) {
          final dissipate = _isDissipating
              ? Curves.easeOut.transform(_dissipateController.value)
              : 0.0;
          final effectiveOpacity = opacity * (1.0 - dissipate);
          final effectiveProgress = widget.isActive
              ? progress
              : _lastActiveProgress;

          if (effectiveOpacity <= 0.001) {
            if (kDebugMode) {
              debugPrint('[TOXIC_GAS] skipped render outside camera');
            }
            return const SizedBox.shrink();
          }

          if (!_didLogClippedToViewport && kDebugMode) {
            _didLogClippedToViewport = true;
            debugPrint('[TOXIC_GAS] clipped to viewport');
          }

          return CustomPaint(
            size: Size.infinite,
            painter: _ToxicGasPainter(
              time: _controller.value,
              progress: effectiveProgress,
              opacity: effectiveOpacity,
              dissipate: dissipate,
            ),
          );
        },
      ),
    );
  }
}

class _ToxicGasPainter extends CustomPainter {
  const _ToxicGasPainter({
    required this.time,
    required this.progress,
    required this.opacity,
    required this.dissipate,
  });

  final double time;
  final double progress;
  final double opacity;
  final double dissipate;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || opacity <= 0) return;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final clampedProgress = progress.clamp(0.0, 1.0);
    final baseOpacity = (0.25 + clampedProgress * 0.75) * opacity;
    final fillFraction = ui.lerpDouble(0.18, 0.95, clampedProgress) ?? 0.18;
    final dissipateLift = size.height * 0.12 * dissipate;
    final topY = size.height * (1.0 - fillFraction) - dissipateLift;

    final fogRect = Rect.fromLTWH(0, topY, size.width, size.height - topY);

    final basePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width * 0.5, topY),
        Offset(size.width * 0.5, size.height),
        [
          const Color(0x00000000),
          const Color(0x6618D75A).withValues(alpha: baseOpacity * 0.75),
          const Color(0xFF0C7A2C).withValues(alpha: baseOpacity),
        ],
        const [0.0, 0.55, 1.0],
      );
    canvas.drawRect(fogRect, basePaint);

    _drawFlowBands(
      canvas,
      size,
      intensity: clampedProgress,
      dissipate: dissipate,
    );
    _drawMidFloatingHaze(
      canvas,
      size,
      intensity: clampedProgress,
      dissipate: dissipate,
    );

    _drawEmitterCloud(
      canvas,
      size,
      fromLeft: true,
      intensity: clampedProgress,
      dissipate: dissipate,
    );
    _drawEmitterCloud(
      canvas,
      size,
      fromLeft: false,
      intensity: clampedProgress,
      dissipate: dissipate,
    );
    _drawMicroParticles(
      canvas,
      size,
      intensity: clampedProgress,
      dissipate: dissipate,
    );
    canvas.restore();
  }

  void _drawFlowBands(
    Canvas canvas,
    Size size, {
    required double intensity,
    required double dissipate,
  }) {
    final bandTop = size.height * (1.0 - (0.24 + intensity * 0.62));
    for (var i = 0; i < 3; i++) {
      final phase = (time + i * 0.23) % 1.0;
      final shift = math.sin((phase * math.pi * 2.0) + i) * size.width * 0.06;
      final rect = Rect.fromLTWH(
        -size.width * 0.12 + shift,
        bandTop + i * size.height * 0.05 - size.height * 0.08 * dissipate,
        size.width * 1.24,
        size.height * (0.20 + intensity * 0.10) * (1.0 + dissipate * 0.25),
      );
      final paint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(rect.left, rect.top),
          Offset(rect.right, rect.bottom),
          [
            const Color(0x00000000),
            const Color(
              0xFF6DFF7A,
            ).withValues(alpha: (0.05 + intensity * 0.08) * opacity),
            const Color(0x00000000),
          ],
          const [0.0, 0.5, 1.0],
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 14 + 6 * dissipate);
      canvas.drawOval(rect, paint);
    }
  }

  void _drawMidFloatingHaze(
    Canvas canvas,
    Size size, {
    required double intensity,
    required double dissipate,
  }) {
    final count = 10 + (intensity * 8).round();
    for (var i = 0; i < count; i++) {
      final seed = i * 0.61;
      final loop = (time * (0.16 + (i % 5) * 0.05) + seed) % 1.0;
      final x =
          size.width * (0.15 + 0.7 * ((i % 9) / 8.0)) +
          math.sin((time * math.pi * 2.0) + seed * 4.0) * size.width * 0.03;
      final y =
          size.height * (0.35 + 0.55 * (1.0 - loop)) -
          size.height * 0.10 * dissipate;
      final radius =
          ui.lerpDouble(24.0, 72.0, ((i % 7) / 6.0))! *
          (0.55 + intensity * 0.55) *
          (1.0 + dissipate * 0.35);
      final alpha =
          (0.03 + intensity * 0.10) *
          (1.0 - loop * 0.65) *
          opacity *
          (1.0 - dissipate * 0.55);

      final paint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(x, y),
          radius,
          [
            const Color(0xFF9EFF9B).withValues(alpha: alpha),
            const Color(0xFF2FAE3F).withValues(alpha: alpha * 0.55),
            const Color(0x00000000),
          ],
          const [0.0, 0.6, 1.0],
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 + 5 * dissipate);

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  void _drawEmitterCloud(
    Canvas canvas,
    Size size, {
    required bool fromLeft,
    required double intensity,
    required double dissipate,
  }) {
    final particleCount = 30 + (intensity * 30).round();
    final baseX = fromLeft ? size.width * 0.08 : size.width * 0.92;
    final sideSign = fromLeft ? 1.0 : -1.0;

    for (var i = 0; i < particleCount; i++) {
      final seed = i * 0.37 + (fromLeft ? 0.12 : 1.73);
      final loop = (time * (0.45 + (i % 7) * 0.09) + seed) % 1.0;
      final rise = Curves.easeOut.transform(loop);
      final maxRise = size.height * (0.28 + intensity * 0.72);

      final wobble =
          math.sin((time * math.pi * 2.0) + seed * 6.0) *
          (10.0 + (i % 4) * 4.0);
      final spread = (10.0 + (i % 8) * 6.0) * (0.4 + rise);
      final x = baseX + sideSign * (spread + wobble * 0.4);
      final y = size.height - rise * maxRise - size.height * 0.18 * dissipate;

      final radius =
          ui.lerpDouble(14.0, 56.0, ((i % 11) / 10.0))! *
          (0.6 + 0.7 * intensity) *
          (0.7 + 0.5 * (1 - rise)) *
          (1.0 + dissipate * 0.40);
      final alpha =
          (0.08 + 0.26 * intensity) *
          (1.0 - rise * 0.85) *
          opacity *
          (1.0 - dissipate * 0.80);

      final rect = Rect.fromCircle(center: Offset(x, y), radius: radius);
      final particlePaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(x, y),
          radius,
          [
            const Color(0xFF9CFF8A).withValues(alpha: alpha),
            const Color(0xFF47D34D).withValues(alpha: alpha * 0.65),
            const Color(0x00000000),
          ],
          const [0.0, 0.6, 1.0],
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + 6 * dissipate);

      canvas.drawOval(rect, particlePaint);
    }
  }

  void _drawMicroParticles(
    Canvas canvas,
    Size size, {
    required double intensity,
    required double dissipate,
  }) {
    final count = 28 + (intensity * 24).round();
    final paint = Paint()
      ..color = const Color(
        0xFF9BFF7B,
      ).withValues(alpha: (0.02 + intensity * 0.05) * opacity * (1 - dissipate))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 + 2 * dissipate);

    for (var i = 0; i < count; i++) {
      final seed = i * 0.49;
      final loop = (time * (0.35 + (i % 6) * 0.08) + seed) % 1.0;
      final x =
          (size.width * ((i % 13) / 12.0)) +
          math.sin((time * math.pi * 2.0) + seed * 3.0) * 12.0;
      final y =
          size.height -
          loop * (size.height * (0.25 + intensity * 0.55)) -
          size.height * 0.12 * dissipate;
      final r = 1.4 + (i % 3) * 0.7;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ToxicGasPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.progress != progress ||
        oldDelegate.opacity != opacity ||
        oldDelegate.dissipate != dissipate;
  }
}
