import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

class ParticleSystem extends Component {
  static const int _maxParticles = 120;
  static const int _maxPulses = 10;

  final List<_VfxParticle> _particles = [];
  final List<_WarningPulse> _pulses = [];
  final math.Random _random = math.Random();

  int _lastHitSparkAtMs = 0;
  int _lastDashTrailAtMs = 0;
  int _lastWarningPulseAtMs = 0;

  void spawnHitSpark(Vector2 center) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastHitSparkAtMs < 45) return;
    _lastHitSparkAtMs = now;

    for (var i = 0; i < 6; i++) {
      final angle = _random.nextDouble() * math.pi * 2;
      final speed = 70 + _random.nextDouble() * 90;
      _addParticle(
        _VfxParticle(
          position: center.clone(),
          velocity: Vector2(math.cos(angle) * speed, math.sin(angle) * speed),
          life: 0.14 + _random.nextDouble() * 0.08,
          size: 1.6 + _random.nextDouble() * 1.6,
          color: const Color(0xFFFFD36B),
        ),
      );
    }
  }

  void spawnDashTrail(Vector2 center, {int direction = 1}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastDashTrailAtMs < 28) return;
    _lastDashTrailAtMs = now;

    final jitterY = (_random.nextDouble() * 2 - 1) * 5;
    final vx = -direction * (30 + _random.nextDouble() * 20);
    _addParticle(
      _VfxParticle(
        position: center + Vector2(-direction * 8, jitterY),
        velocity: Vector2(vx, 0),
        life: 0.10 + _random.nextDouble() * 0.07,
        size: 2.0 + _random.nextDouble() * 2.0,
        color: const Color(0x99BDE8FF),
      ),
    );
  }

  void spawnWarningPulse(
    Vector2 center, {
    Color color = const Color(0xFFFF8C66),
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastWarningPulseAtMs < 260) return;
    _lastWarningPulseAtMs = now;

    if (_pulses.length >= _maxPulses) {
      _pulses.removeAt(0);
    }

    _pulses.add(
      _WarningPulse(
        center: center.clone(),
        life: 0.55,
        startRadius: 10,
        endRadius: 54,
        color: color,
      ),
    );
  }

  void _addParticle(_VfxParticle p) {
    if (_particles.length >= _maxParticles) {
      _particles.removeAt(0);
    }
    _particles.add(p);
  }

  @override
  void update(double dt) {
    super.update(dt);

    for (final p in _particles) {
      p.life -= dt;
      p.position += p.velocity * dt;
    }
    _particles.removeWhere((p) => p.life <= 0);

    for (final pulse in _pulses) {
      pulse.life -= dt;
    }
    _pulses.removeWhere((p) => p.life <= 0);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    for (final pulse in _pulses) {
      final t = (1 - (pulse.life / pulse.maxLife)).clamp(0.0, 1.0);
      final radius =
          pulse.startRadius + (pulse.endRadius - pulse.startRadius) * t;
      final alpha = (1 - t) * 0.7;
      final color = pulse.color.withValues(alpha: alpha);

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2;

      canvas.drawCircle(Offset(pulse.center.x, pulse.center.y), radius, paint);
    }

    for (final p in _particles) {
      final alpha = (p.life / p.maxLife).clamp(0.0, 1.0);
      final paint = Paint()..color = p.color.withValues(alpha: alpha);
      canvas.drawCircle(Offset(p.position.x, p.position.y), p.size, paint);
    }
  }
}

class _VfxParticle {
  Vector2 position;
  final Vector2 velocity;
  final double maxLife;
  double life;
  final double size;
  final Color color;

  _VfxParticle({
    required this.position,
    required this.velocity,
    required this.life,
    required this.size,
    required this.color,
  }) : maxLife = life;
}

class _WarningPulse {
  final Vector2 center;
  final double maxLife;
  double life;
  final double startRadius;
  final double endRadius;
  final Color color;

  _WarningPulse({
    required this.center,
    required this.life,
    required this.startRadius,
    required this.endRadius,
    required this.color,
  }) : maxLife = life;
}
