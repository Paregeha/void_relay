import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/services.dart';

import 'player_rig_config.dart';

/// One bone / body-part in the skeletal player rig.
///
/// RENDERING CONTRACT
/// ──────────────────
/// The inner SpriteComponent gets the SAME anchor as [spec.pivot].  Because
/// Flame translates by −anchor×size before rendering, both this component's
/// origin and the sprite's origin sit at the pivot point.  Child components
/// placed at (0,0) therefore land exactly on the parent's joint.
///
/// If the PNG cannot be loaded a coloured placeholder fills the same rect so
/// layout is still visible while assets are being developed.
class PlayerPartComponent extends PositionComponent {
  PlayerPartComponent({required this.spec});

  final PlayerPartSpec spec;

  SpriteComponent? _sprite;
  bool _missingAsset = false;

  Rect get _localBounds {
    final ox = spec.pivot.x * size.x;
    final oy = spec.pivot.y * size.y;
    return Rect.fromLTWH(-ox, -oy, size.x, size.y);
  }

  @override
  Future<void> onLoad() async {
    // size, anchor, angle and priority are all set here.
    // position is set (and reset each frame) by SkeletalPlayer.resetToBasePose.
    size = spec.renderSize.clone();
    anchor = spec.pivot;
    angle = spec.baseAngle;
    scale.setValues(spec.scale, spec.scale);
    priority = spec.priority;

    try {
      // Load directly from Flutter asset bundle using the full asset path.
      // Flame's Sprite.load() prepends 'assets/images/' which breaks paths
      // like 'assets/sprites/player/Game World/...'. We bypass Flame's
      // image cache here to load from the correct Flutter asset path.
      final data = await rootBundle.load(spec.assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final image = frame.image;
      codec.dispose();
      _sprite = SpriteComponent(
        sprite: Sprite(image),
        size: size,
        anchor: spec.pivot,
        position: Vector2.zero(),
        // Important: keep the visual sprite on the same layer as its bone.
        // Otherwise child limbs (with non-zero priority) always render above it.
        priority: spec.priority,
      );
      add(_sprite!);
    } catch (e) {
      _missingAsset = true;
      // ignore: avoid_print
      print('[SkeletalPlayer] FAILED to load ${spec.assetPath}: $e');
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (_missingAsset) {
      _renderPlaceholder(canvas);
    }

    if (PlayerRigConfig.debugJoints) {
      // Red dot at the pivot/joint origin.
      canvas.drawCircle(
        Offset.zero,
        1.6,
        Paint()..color = const Color(0xFFFF2020),
      );
    }

    if (PlayerRigConfig.debugBounds) {
      canvas.drawRect(
        _localBounds,
        Paint()
          ..color = const Color(0xAA00E5FF)
          ..strokeWidth = 0.45
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _renderPlaceholder(Canvas canvas) {
    // Render canvas (0,0) = component top-left (position - anchor*size).
    // Sprite is placed at SpriteComponent(position:zero, anchor:pivot) so
    // it draws from -pivot*size to (1-pivot)*size in this canvas.
    // Placeholder must match that exact rect.
    final rect = _localBounds;

    canvas.drawRect(
      rect,
      Paint()
        ..color = _partColor()
        ..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0x99FFFFFF)
        ..strokeWidth = 0.4
        ..style = PaintingStyle.stroke,
    );
  }

  Color _partColor() {
    switch (spec.id) {
      case 'pelvis':
        return const Color(0xFF884422);
      case 'torso':
        return const Color(0xFF2266AA);
      case 'head':
        return const Color(0xFFBB8844);
      case 'backpack':
        return const Color(0xFF446633);
      case 'left_upper_arm':
      case 'left_lower_arm':
      case 'left_hand':
        return const Color(0xFF338855);
      case 'right_upper_arm':
      case 'right_lower_arm':
      case 'right_hand':
        return const Color(0xFF335588);
      case 'left_thigh':
      case 'left_leg_full':
        return const Color(0xFF664488);
      case 'right_thigh':
      case 'right_leg_full':
        return const Color(0xFF886644);
      default:
        return const Color(0xFF555555);
    }
  }
}
