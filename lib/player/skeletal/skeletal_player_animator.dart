import 'dart:math' as math;

import 'package:flame/components.dart';

import '../../config/game_config.dart';
import 'player_animation_state.dart';
import 'player_part_component.dart';
import 'player_rig_config.dart';

/// Drives all procedural poses.  Receives part lookup + reset callbacks from
/// [SkeletalPlayer] to avoid a cyclic import dependency.
class SkeletalPlayerAnimator {
  SkeletalPlayerAnimator({
    required PlayerPartComponent Function(String) partOf,
    required void Function() resetToBasePose,
  })  : _p    = partOf,
        _reset = resetToBasePose;

  final PlayerPartComponent Function(String) _p;
  final void Function() _reset;
  double _t = 0;

  void update(
    double dt, {
    required SkeletalPlayerAnimationState animationState,
    required Vector2 velocity,
    required bool isOnGround,
  }) {
    _t += dt;
    _reset();

    switch (animationState) {
      case SkeletalPlayerAnimationState.idle:   _idle();
      case SkeletalPlayerAnimationState.run:    _run(velocity.x.abs());
      case SkeletalPlayerAnimationState.jump:   _jump();
      case SkeletalPlayerAnimationState.fall:   _fall();
      case SkeletalPlayerAnimationState.dash:   _dash();
      case SkeletalPlayerAnimationState.attack: _attack();
      case SkeletalPlayerAnimationState.death:  _death();
    }

    if (!isOnGround && animationState == SkeletalPlayerAnimationState.attack) {
      _p('left_thigh').angle  += -0.14;
      _p('right_thigh').angle += -0.14;
    }
  }

  // ── Idle ──────────────────────────────────────────────────────────────────
  void _idle() {
    final b = math.sin(_t * PlayerRigConfig.idleBreathSpeed) *
        PlayerRigConfig.idleBreathOffset;
    _p('torso').position.y           += b;
    _p('head').position.y            += b * 0.55;
    _p('left_upper_arm').angle       +=  b * 0.012;
    _p('right_upper_arm').angle      += -b * 0.012;
  }

  // ── Run ───────────────────────────────────────────────────────────────────
  void _run(double speed) {
    final norm = (speed / GameConfig.playerSpeed).clamp(0.4, 1.4).toDouble();
    final c   = _t * PlayerRigConfig.runCycleSpeed * norm;
    final sw  = math.sin(c);
    final asw = math.sin(c + math.pi);
    final bob = math.sin(c * 2).abs() * PlayerRigConfig.runBodyBob;

    _p('pelvis').position.y += bob;
    _p('torso').position.y  += bob * 0.3;

    _p('left_thigh').angle    += sw  * PlayerRigConfig.runLegSwing;
    _p('right_thigh').angle   += asw * PlayerRigConfig.runLegSwing;
    _p('left_leg_full').angle  += math.max(0, -sw)  * PlayerRigConfig.runKneeBend;
    _p('right_leg_full').angle += math.max(0, -asw) * PlayerRigConfig.runKneeBend;

    _p('left_upper_arm').angle  += asw * PlayerRigConfig.runArmSwing;
    _p('right_upper_arm').angle += sw  * PlayerRigConfig.runArmSwing;
    _p('left_lower_arm').angle  += asw * 0.18;
    _p('right_lower_arm').angle += sw  * 0.18;
  }

  // ── Jump ──────────────────────────────────────────────────────────────────
  void _jump() {
    _p('torso').angle           += PlayerRigConfig.jumpTorsoLean;
    _p('head').angle            += PlayerRigConfig.jumpTorsoLean * 0.2;
    _p('left_thigh').angle      += PlayerRigConfig.jumpLegTuck;
    _p('right_thigh').angle     += PlayerRigConfig.jumpLegTuck;
    _p('left_leg_full').angle   += 0.30;
    _p('right_leg_full').angle  += 0.30;
    _p('left_upper_arm').angle  += -0.20;
    _p('right_upper_arm').angle += -0.20;
  }

  // ── Fall ──────────────────────────────────────────────────────────────────
  void _fall() {
    _p('torso').angle           += PlayerRigConfig.fallTorsoLean;
    _p('head').angle            += PlayerRigConfig.fallTorsoLean * 0.2;
    _p('left_thigh').angle      += PlayerRigConfig.fallLegDrop;
    _p('right_thigh').angle     += PlayerRigConfig.fallLegDrop;
    _p('left_leg_full').angle   += -0.15;
    _p('right_leg_full').angle  += -0.15;
    _p('left_upper_arm').angle  += 0.18;
    _p('right_upper_arm').angle += 0.18;
  }

  // ── Dash ──────────────────────────────────────────────────────────────────
  void _dash() {
    _p('torso').angle           += PlayerRigConfig.dashTorsoLean;
    _p('head').position.x       += 1.1;
    _p('left_upper_arm').angle  += PlayerRigConfig.dashArmBack;
    _p('right_upper_arm').angle += PlayerRigConfig.dashArmBack * 0.4;
    _p('left_thigh').angle      += -PlayerRigConfig.dashLegPush;
    _p('right_thigh').angle     +=  PlayerRigConfig.dashLegPush;
  }

  // ── Attack ────────────────────────────────────────────────────────────────
  void _attack() {
    final pulse = math.sin(_t * 26).abs();
    _p('right_upper_arm').angle +=
        PlayerRigConfig.attackArmKick * (0.55 + pulse * 0.45);
    _p('right_lower_arm').angle  += -0.20;
    _p('left_upper_arm').angle   += PlayerRigConfig.attackOffArmRecoil;
    _p('torso').angle            += -0.07;
  }

  // ── Death ─────────────────────────────────────────────────────────────────
  void _death() {
    _p('torso').angle           += PlayerRigConfig.deathLean;
    _p('head').angle            += 0.28;
    _p('left_upper_arm').angle  += 1.0;
    _p('right_upper_arm').angle += 0.88;
    _p('left_thigh').angle      += -0.72;
    _p('right_thigh').angle     += -0.42;
    _p('left_leg_full').angle   +=  0.42;
    _p('right_leg_full').angle  +=  0.32;
  }
}
