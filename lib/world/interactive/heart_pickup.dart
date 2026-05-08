import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

import '../../core/utils/safe_asset_loader.dart';
import '../../flame_game.dart';
import '../../player/player_component.dart';

class HeartPickup extends PositionComponent {
  static const String heartImagePath = 'assets/images/pickups/heart_neon.png';
  static const double _width = 34.0;
  static const double _height = 34.0;
  static const double _healAmount = 30.0;

  final PlayerComponent player;
  final String saveId;
  final void Function(String id)? onCollected;

  bool isCollected = false;
  Image? _heartImage;
  double _animTime = 0.0;

  HeartPickup({
    required Vector2 position,
    required this.player,
    required this.saveId,
    this.onCollected,
  }) : super(
         position: position,
         size: Vector2(_width, _height),
         anchor: Anchor.bottomCenter,
       );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _heartImage = await loadUiImageSafe(heartImagePath);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isCollected) return;

    _animTime += dt;

    if (toRect().overlaps(player.worldHitboxRect)) {
      collect();
    }
  }

  @override
  void render(Canvas canvas) {
    if (isCollected) return;

    final pulse = 1.0 + math.sin(_animTime * 4.0) * 0.08;
    final floatY = math.sin(_animTime * 2.2) * 3.0;
    final drawW = size.x * pulse;
    final drawH = size.y * pulse;
    final drawRect = Rect.fromLTWH(
      (size.x - drawW) / 2,
      (size.y - drawH) / 2,
      drawW,
      drawH,
    );

    canvas.save();
    canvas.translate(0, floatY);

    final image = _heartImage;
    if (image != null) {
      final srcRect = Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      );
      canvas.drawImageRect(image, srcRect, drawRect, Paint());
    } else {
      _renderFallbackHeart(canvas, drawRect);
    }

    canvas.restore();
  }

  void collect() {
    if (isCollected) return;

    final healed = player.heal(_healAmount);
    if (healed <= 0) {
      // Keep pickup available when HP is already full.
      return;
    }

    isCollected = true;
    onCollected?.call(saveId);

    final game = findGame();
    if (game is VoidRelayGame) {
      unawaited(game.playButtonClickSound());
    }

    if (kDebugMode) {
      debugPrint(
        '[PICKUP] heart collected heal=${healed.toStringAsFixed(1)} '
        'hp=${player.health.toStringAsFixed(1)}/${player.maxHealth.toStringAsFixed(1)}',
      );
    }

    removeFromParent();
  }

  void _renderFallbackHeart(Canvas canvas, Rect rect) {
    final centerX = rect.center.dx;
    final top = rect.top;
    final width = rect.width;
    final height = rect.height;

    final leftCircleCenter = Offset(
      centerX - width * 0.18,
      top + height * 0.30,
    );
    final rightCircleCenter = Offset(
      centerX + width * 0.18,
      top + height * 0.30,
    );
    final radius = width * 0.24;

    final glowPaint = Paint()
      ..color = const Color(0x66FF2E63)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final fillPaint = Paint()..color = const Color(0xFFFF2E63);

    canvas.drawCircle(leftCircleCenter, radius * 1.15, glowPaint);
    canvas.drawCircle(rightCircleCenter, radius * 1.15, glowPaint);

    final heartPath = Path()
      ..moveTo(centerX, top + height * 0.92)
      ..lineTo(rect.left + width * 0.07, top + height * 0.44)
      ..arcToPoint(
        Offset(centerX, top + height * 0.20),
        radius: Radius.circular(radius),
      )
      ..arcToPoint(
        Offset(rect.right - width * 0.07, top + height * 0.44),
        radius: Radius.circular(radius),
      )
      ..close();

    canvas.drawPath(heartPath, glowPaint);
    canvas.drawPath(heartPath, fillPaint);
  }
}
