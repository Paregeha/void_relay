import 'dart:ui';
import 'dart:math' as math;

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../core/utils/safe_asset_loader.dart';
import '../flame_game.dart';

class ProjectileComponent extends PositionComponent {
  Vector2 velocity = Vector2.zero();
  double lifetime = GameConfig.playerProjectileLifetime;
  double timeAlive = 0;
  double maxRange = 420.0;
  double distanceTraveled = 0;
  double damage = GameConfig.pulseBlasterDamage;
  bool isAlive = true;
  bool hasMountedOnce = false;
  Image? _bulletImage;
  Rect? _sourceRect;
  double? _previousAbsoluteX;
  double? _previousAbsoluteY;

  static const double _outOfBoundsMargin = 128.0;
  static final Paint _imagePaint = Paint();
  static final Paint _fallbackPaint = Paint()..color = const Color(0xFFFFFF00);

  Rect get worldRect => Rect.fromCenter(
    center: Offset(absolutePosition.x, absolutePosition.y),
    width: size.x,
    height: size.y,
  );

  Rect get sweptWorldRect {
    final current = worldRect;
    final previousX = _previousAbsoluteX;
    final previousY = _previousAbsoluteY;
    if (previousX == null || previousY == null) {
      return current;
    }

    final previous = Rect.fromCenter(
      center: Offset(previousX, previousY),
      width: size.x,
      height: size.y,
    );

    return current.expandToInclude(previous);
  }

  @override
  Future<void> onLoad() async {
    size = size.isZero()
        ? Vector2(GameConfig.playerBulletWidth, GameConfig.playerBulletHeight)
        : size;
    anchor = Anchor.center;
    _bulletImage = await loadUiImageSafe(GameConfig.playerBulletSpritePath);
    final image = _bulletImage;
    if (image != null) {
      _sourceRect = Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      );
    }
  }

  @override
  void onMount() {
    super.onMount();
    hasMountedOnce = true;
  }

  @override
  void update(double dt) {
    super.update(dt);

    final game = findGame();
    if (game is VoidRelayGame && game.isGameplayInputBlocked) {
      return;
    }

    if (!isAlive) return;

    timeAlive += dt;
    if (timeAlive > lifetime) {
      removeFromParent();
      isAlive = false;
      return;
    }

    final currentAbsolute = absolutePosition;
    _previousAbsoluteX = currentAbsolute.x;
    _previousAbsoluteY = currentAbsolute.y;
    final deltaX = velocity.x * dt;
    final deltaY = velocity.y * dt;
    position.x += deltaX;
    position.y += deltaY;
    distanceTraveled += math.sqrt(deltaX * deltaX + deltaY * deltaY);

    if (distanceTraveled >= maxRange) {
      removeFromParent();
      isAlive = false;
      return;
    }

    if (_isFarOutsideWorldBounds()) {
      removeFromParent();
      isAlive = false;
      return;
    }
  }

  @override
  void render(Canvas canvas) {
    final localHitboxRect = Rect.fromCenter(
      center: Offset.zero,
      width: size.x,
      height: size.y,
    );

    final image = _bulletImage;
    if (image == null) {
      canvas.drawRect(localHitboxRect, _fallbackPaint);
      return;
    }

    final sourceRect =
        _sourceRect ??
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final destRect = localHitboxRect;

    final shouldFlip = velocity.x < 0;
    if (shouldFlip) {
      canvas.save();
      // Mirror around the bullet center (anchor=center) without positional shift.
      canvas.scale(-1.0, 1.0);
      canvas.drawImageRect(image, sourceRect, destRect, _imagePaint);
      canvas.restore();
      return;
    }

    canvas.drawImageRect(image, sourceRect, destRect, _imagePaint);
  }

  void onHit() {
    if (isAlive) {
      isAlive = false;
      removeFromParent();
    }
  }

  bool _isFarOutsideWorldBounds() {
    final game = findGame();
    if (game is! VoidRelayGame) return false;

    final worldSize = game.gameWorld?.roomSize;
    final worldWidth = worldSize?.x ?? GameConfig.defaultWorldWidth;
    final worldHeight = worldSize?.y ?? GameConfig.defaultWorldHeight;

    return position.x < -_outOfBoundsMargin ||
        position.y < -_outOfBoundsMargin ||
        position.x > worldWidth + _outOfBoundsMargin ||
        position.y > worldHeight + _outOfBoundsMargin;
  }
}
