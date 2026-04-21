import 'dart:ui';

import 'package:flame/components.dart';

import 'player_animation_state.dart';
import 'player_part_component.dart';
import 'player_rig_config.dart';
import 'skeletal_player_animator.dart';

/// Root visual component of the player puppet.
///
/// Coordinate space
/// ─────────────────
///   Added inside PlayerComponent (32×64, Anchor.center) at
///   position = size/2 = (16,32), also with Anchor.center.
///   Internal bones are attached to a dedicated rig-root at (16,32), so
///   part local positions are always authored around character center (0,0).
///   y = -32 = top of head   y = +32 = feet.
///
/// This component owns ONLY rendering.  All gameplay logic (physics, health,
/// input, collision) remains in PlayerComponent.
class SkeletalPlayer extends PositionComponent {
  late final SkeletalPlayerAnimator _animator;
  late final PositionComponent _rigRoot;
  final Map<String, PlayerPartComponent> _parts = {};
  final Vector2 _velocity = Vector2.zero();
  SkeletalPlayerAnimationState _state = SkeletalPlayerAnimationState.idle;
  bool _onGround = true;

  @override
  Future<void> onLoad() async {
    size = Vector2(32, 64);
    anchor = Anchor.center;

    // Keep a dedicated center-origin node for all bone coordinates.
    _rigRoot = PositionComponent(position: size / 2);
    add(_rigRoot);

    _buildRig();
    _animator = SkeletalPlayerAnimator(
      partOf: part,
      resetToBasePose: resetToBasePose,
    );
    resetToBasePose();
  }

  /// Called by PlayerComponent every frame to synchronise game state.
  void applyGameplayState({
    required SkeletalPlayerAnimationState animationState,
    required Vector2 velocity,
    required bool isOnGround,
    required int facingDirection,
  }) {
    _state = animationState;
    _velocity.setFrom(velocity);
    _onGround = isOnGround;
    // Horizontal flip via root scale keeps the full bone hierarchy intact.
    scale = Vector2(facingDirection < 0 ? -1.0 : 1.0, 1.0);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _animator.update(
      dt,
      animationState: _state,
      velocity: _velocity,
      isOnGround: _onGround,
    );
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (PlayerRigConfig.debugJoints) {
      _drawBoneLines(canvas);
    }
  }

  /// Returns the part with [id]; throws [StateError] if not found.
  PlayerPartComponent part(String id) {
    final v = _parts[id];
    if (v == null) throw StateError('SkeletalPlayer: missing part "$id"');
    return v;
  }

  /// Resets every part to its neutral base-pose from [PlayerRigConfig].
  void resetToBasePose() {
    for (final spec in PlayerRigConfig.parts) {
      final p = _parts[spec.id];
      if (p == null) continue;
      p.position.setFrom(spec.localPosition);
      p.angle = spec.baseAngle;
      p.scale.setValues(spec.scale, spec.scale);
    }
  }

  // ── Private ────────────────────────────────────────────────────────────────

  void _buildRig() {
    // Pass 1 – create all parts.
    for (final spec in PlayerRigConfig.parts) {
      _parts[spec.id] = PlayerPartComponent(spec: spec);
    }
    // Pass 2 – attach to parent (or to centered rig root if root).
    for (final spec in PlayerRigConfig.parts) {
      final p = _parts[spec.id]!;
      final pid = spec.parentId;
      if (pid == null) {
        _rigRoot.add(p);
      } else {
        _parts[pid]!.add(p);
      }
    }
  }

  void _drawBoneLines(Canvas canvas) {
    final paint = Paint()
      ..color = const Color(0xAAFFFF00)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;

    final myPos = absolutePosition;
    for (final spec in PlayerRigConfig.parts) {
      if (spec.parentId == null) continue;
      final child = _parts[spec.id];
      final parent = _parts[spec.parentId!];
      if (child == null || parent == null) continue;

      final c = child.absolutePosition - myPos;
      final p = parent.absolutePosition - myPos;
      canvas.drawLine(Offset(p.x, p.y), Offset(c.x, c.y), paint);
    }
  }
}
