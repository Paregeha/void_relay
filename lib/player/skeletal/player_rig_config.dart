import 'package:flame/components.dart';

/// Immutable specification of one body-part bone.
class PlayerPartSpec {
  const PlayerPartSpec({
    required this.id,
    required this.assetPath,
    required this.localPosition,
    required this.renderSize,
    required this.pivot,
    required this.priority,
    this.baseAngle = 0.0,
    this.scale = 1.0,
    this.parentId,
  });

  final String id;

  /// Relative path from the Flutter assets root (matches pubspec registration).
  final String assetPath;

  /// Position of THIS part's anchor point in the PARENT's post-transform
  /// coordinate space.  In Flame, after a parent applies its own anchor,
  /// child (0,0) coincides with the parent's anchor point.
  final Vector2 localPosition;

  /// On-screen rendered size in logical pixels (not the raw PNG size).
  final Vector2 renderSize;

  /// Rotation pivot expressed as a Flame Anchor.
  ///   topCenter    → joint at top of bone (limb hangs down / rotates from top)
  ///   bottomCenter → joint at base (segment leans from its bottom)
  ///   center       → free rotation around centre
  final Anchor pivot;

  /// Flame render priority – lower = rendered first (further back).
  final int priority;

  final double baseAngle;
  final double scale;
  final String? parentId;
}

// =============================================================================
class PlayerRigConfig {
  PlayerRigConfig._();

  // ── Asset root ──────────────────────────────────────────────────────────────
  // IMPORTANT: must match the actual on-disk path registered in pubspec.yaml.
  static const String _r = 'assets/sprites/player/Game World';

  // ── Debug toggle ────────────────────────────────────────────────────────────
  /// true  → draw red pivot dots + yellow bone lines (useful for tuning)
  /// false → clean final rendering (default for release)
  static const bool debugJoints = false;
  static const bool debugBounds = false;

  // Layering helpers keep draw-order readable and easy to tweak.
  static const int layerBack = 5;
  static const int layerBackLimbs = 10;
  static const int layerBody = 20;
  static const int layerFrontLimbs = 30;
  static const int layerHead = 40;

  // ── Coordinate space ────────────────────────────────────────────────────────
  // SkeletalPlayer is added as a child of PlayerComponent (32×64 hitbox,
  // Anchor.center). Parts are mounted under an internal rig-root at (16,32),
  // so these localPosition values are authored around character center.
  //
  // Vertical layout (y grows DOWN, Flame default):
  //   y = -32   top of character / top of head
  //   y = -18   neck (head base / torso top)    [headH = 14]
  //   y =   0   torso base / pelvis top          [torsoH = 18, adjusted]
  //   y =  +8   pelvis base                      [pelvisH = 8]
  //   y = +17   knee                             [thighH = 9]
  //   y = +31   foot                             [shinH = 14]
  //
  // Horizontal centre: x = 0
  //   left shoulder  ≈ x = -8   right shoulder  ≈ x = +8
  //   left hip       ≈ x = -4   right hip       ≈ x = +4

  static final List<PlayerPartSpec> parts = [
    // ── PELVIS (root) ──────────────────────────────────────────────────────────
    // Pivot: topCenter → pelvis hangs down from its top edge.
    // localPosition: top of pelvis placed at y=0 (centre of hitbox).
    PlayerPartSpec(
      id: 'pelvis',
      parentId: null,
      assetPath: '$_r/pelvis.png',
      localPosition: Vector2(0, 0), // TUNE: shift up/down to move whole body
      renderSize: Vector2(19, 8),
      // Pivot at torso/hip centerline keeps torso and legs stable while animating.
      pivot: Anchor.topCenter,
      priority: layerBody,
    ),

    // ── TORSO ──────────────────────────────────────────────────────────────────
    // Pivot: bottomCenter → torso leans from its bottom (pelvis connection).
    // In pelvis-local space, (0,0) = pelvis top-center.
    // Torso bottom placed at pelvis top → localPosition = (0, 0).
    PlayerPartSpec(
      id: 'torso',
      parentId: 'pelvis',
      assetPath: '$_r/torso.png',
      // Slightly lowered to remove a visible seam over the pelvis sprite.
      localPosition: Vector2(11, 18),
      renderSize: Vector2(18, 17),
      pivot: Anchor.bottomCenter,
      priority: layerBody,
    ),

    // ── BACKPACK ───────────────────────────────────────────────────────────────
    // Pivot: topRight → attaches at upper-right of torso back area.
    // In torso-local (0,0) = torso bottom.  Torso top = y = -18.
    // Place backpack's top-right at torso's back-upper area: (-9, -14).
    PlayerPartSpec(
      id: 'backpack',
      parentId: 'torso',
      assetPath: '$_r/backpack.png',
      localPosition: Vector2(0, -13.3),
      renderSize: Vector2(11, 12),
      pivot: Anchor.topRight,
      priority: layerBack,
    ),

    // ── HEAD ───────────────────────────────────────────────────────────────────
    // Pivot: bottomCenter → head pivots at neck.
    // Torso top in torso-local = (0, -18).
    PlayerPartSpec(
      id: 'head',
      parentId: 'torso',
      assetPath: '$_r/head.png',
      // Neck connection uses bottom center of the head sprite.
      localPosition: Vector2(5, 1.0),
      renderSize: Vector2(18, 14),
      pivot: Anchor.bottomCenter,
      priority: layerHead,
    ),

    // ── LEFT UPPER ARM ─────────────────────────────────────────────────────────
    // Pivot: topCenter → rotates from shoulder.
    // Shoulder in torso-local ≈ left edge (x=-9), near top (y=-15).
    PlayerPartSpec(
      id: 'left_upper_arm',
      parentId: 'torso',
      assetPath: '$_r/left_upper_arm.png',
      localPosition: Vector2(-8.0, -14.2),
      renderSize: Vector2(9, 9),
      // Shoulder joint at top-center of upper arm.
      pivot: Anchor.topCenter,
      priority: layerBackLimbs,
      baseAngle: 0.04,
    ),

    // ── LEFT LOWER ARM ─────────────────────────────────────────────────────────
    // Pivot: topCenter → elbow joint.
    // Elbow = bottom of upper arm in upper-arm local → (0, renderSize.y) = (0,9).
    PlayerPartSpec(
      id: 'left_lower_arm',
      parentId: 'left_upper_arm',
      assetPath: '$_r/left_lower_arm.png',
      // Elbow at inner edge of a mostly horizontal forearm sprite.
      localPosition: Vector2(0, 9.0),
      renderSize: Vector2(7, 5),
      pivot: Anchor.centerLeft,
      priority: layerBackLimbs,
      baseAngle: 1.47,
    ),

    // ── LEFT HAND ──────────────────────────────────────────────────────────────
    PlayerPartSpec(
      id: 'left_hand',
      parentId: 'left_lower_arm',
      assetPath: '$_r/left_hand.png',
      // Wrist at forearm tip.
      localPosition: Vector2(6.4, -3.0),
      renderSize: Vector2(7, 8),
      pivot: Anchor.centerLeft,
      priority: layerBackLimbs,
      baseAngle: 0.06,
    ),

    // ── RIGHT UPPER ARM ────────────────────────────────────────────────────────
    PlayerPartSpec(
      id: 'right_upper_arm',
      parentId: 'torso',
      assetPath: '$_r/right_upper_arm.png',
      localPosition: Vector2(8.0, -14.2),
      renderSize: Vector2(9, 9),
      pivot: Anchor.topCenter,
      priority: layerBackLimbs,
      baseAngle: -0.04,
    ),

    // ── RIGHT LOWER ARM ────────────────────────────────────────────────────────
    PlayerPartSpec(
      id: 'right_lower_arm',
      parentId: 'right_upper_arm',
      assetPath: '$_r/right_lower_arm.png',
      localPosition: Vector2(0, 0.0),
      renderSize: Vector2(6, 4),
      pivot: Anchor.centerRight,
      priority: layerBackLimbs,
      baseAngle: -1.47,
    ),

    // ── RIGHT HAND ─────────────────────────────────────────────────────────────
    PlayerPartSpec(
      id: 'right_hand',
      parentId: 'right_lower_arm',
      assetPath: '$_r/right_hand.png',
      localPosition: Vector2(2.4, -3),
      renderSize: Vector2(7, 8),
      pivot: Anchor.centerRight,
      priority: layerBackLimbs,
      baseAngle: -0.06,
    ),

    // ── LEFT THIGH ─────────────────────────────────────────────────────────────
    // Pivot: topCenter → hip joint.
    // In pelvis-local (0,0) = pelvis top.  Bottom of pelvis = y=8.
    // Left hip at x=-4, bottom of pelvis y=8.
    PlayerPartSpec(
      id: 'left_thigh',
      parentId: 'pelvis',
      assetPath: '$_r/left_thigh.png',
      localPosition: Vector2(-3.6, 1.2),
      renderSize: Vector2(7, 9),
      pivot: Anchor.topCenter,
      priority: layerBackLimbs,
      baseAngle: -0.02,
    ),

    // ── LEFT LEG FULL ──────────────────────────────────────────────────────────
    // Pivot: topCenter → knee joint.
    // Knee = bottom of thigh → (0, renderSize.y) = (0,9).
    PlayerPartSpec(
      id: 'left_leg_full',
      parentId: 'left_thigh',
      assetPath: '$_r/left_leg_full.png',
      localPosition: Vector2(0, 9.3),
      renderSize: Vector2(8, 14),
      pivot: Anchor.topCenter,
      priority: layerBackLimbs,
      baseAngle: 0.01,
    ),

    // ── RIGHT THIGH ────────────────────────────────────────────────────────────
    PlayerPartSpec(
      id: 'right_thigh',
      parentId: 'pelvis',
      assetPath: '$_r/right_thigh.png',
      localPosition: Vector2(3.6, 8.2),
      renderSize: Vector2(7, 9),
      pivot: Anchor.topCenter,
      priority: layerFrontLimbs,
      baseAngle: 0.02,
    ),

    // ── RIGHT LEG FULL ─────────────────────────────────────────────────────────
    PlayerPartSpec(
      id: 'right_leg_full',
      parentId: 'right_thigh',
      assetPath: '$_r/right_leg_full.png',
      localPosition: Vector2(0, 9.3),
      renderSize: Vector2(10, 14),
      pivot: Anchor.topCenter,
      priority: layerFrontLimbs,
      baseAngle: -0.01,
    ),
  ];

  // ── Animation constants ──────────────────────────────────────────────────────
  // Tweak these freely without touching animator logic.

  // Idle breathing
  static const double idleBreathSpeed = 1.25; // sin frequency
  static const double idleBreathOffset = 0.22; // pixels of vertical movement

  // Run cycle
  static const double runCycleSpeed = 10.0; // higher = faster gait
  static const double runArmSwing = 0.55; // radians, arm peak angle
  static const double runLegSwing = 0.65; // radians, thigh peak angle
  static const double runKneeBend = 0.35; // extra trailing-leg knee bend
  static const double runBodyBob = 1.0; // px vertical bob

  // Jump / fall
  static const double jumpTorsoLean = -0.14;
  static const double jumpLegTuck = -0.42;
  static const double fallTorsoLean = 0.12;
  static const double fallLegDrop = 0.36;

  // Dash
  static const double dashTorsoLean = -0.20;
  static const double dashArmBack = 0.58;
  static const double dashLegPush = 0.26;

  // Attack
  static const double attackArmKick = -0.82;
  static const double attackOffArmRecoil = 0.28;

  // Death
  static const double deathLean = 0.82;
}
