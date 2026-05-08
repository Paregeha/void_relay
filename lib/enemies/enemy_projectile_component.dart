import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../core/debug/debug_collision_config.dart';
import '../core/utils/safe_asset_loader.dart';
import '../flame_game.dart';

class EnemyProjectileComponent extends PositionComponent {
  Vector2 velocity = Vector2.zero();
  double lifetime = GameConfig.enemyProjectileLifetime;
  double timeAlive = 0;
  double damage = GameConfig.enemyProjectileDamage;
  double maxRange = 520;
  double distanceTraveled = 0;
  double angleOffset = 0;
  String spritePath = 'assets/sprites/enemies/enemy_bullet.png';
  bool isAlive = true;
  Image? _sprite;
  Rect? _sourceRect;
  static final Paint _imagePaint = Paint();
  static final Paint _fallbackPaint = Paint()..color = const Color(0xFFFF4444);
  static final Paint _debugHitboxPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..color = const Color(0xFFFFA500);

  Rect get worldRect => Rect.fromCenter(
    center: Offset(absolutePosition.x, absolutePosition.y),
    width: size.x,
    height: size.y,
  );

  @override
  Future<void> onLoad() async {
    size = Vector2(14, 6);
    anchor = Anchor.center;
    _sprite = await _loadBulletSprite(spritePath);
    final image = _sprite;
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
  void update(double dt) {
    super.update(dt);
    final game = findGame();
    if (game is VoidRelayGame && game.isGameplayInputBlocked) {
      return;
    }
    if (!isAlive) return;

    timeAlive += dt;
    if (timeAlive > lifetime) {
      onHit();
      return;
    }

    final deltaX = velocity.x * dt;
    final deltaY = velocity.y * dt;
    position.x += deltaX;
    position.y += deltaY;
    distanceTraveled += math.sqrt(deltaX * deltaX + deltaY * deltaY);
    if (velocity.length2 > 0) {
      angle = math.atan2(velocity.y, velocity.x) + angleOffset;
    }
    if (distanceTraveled >= maxRange) {
      onHit();
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

    final image = _sprite;
    if (image == null) {
      canvas.drawRect(localHitboxRect, _fallbackPaint);
      if (DebugCollisionConfig.showCollisionBoxes &&
          DebugCollisionConfig.showEnemyBulletHitbox) {
        canvas.drawRect(localHitboxRect, _debugHitboxPaint);
      }
      return;
    }

    final src =
        _sourceRect ??
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = localHitboxRect;

    canvas.drawImageRect(image, src, dst, _imagePaint);
    if (DebugCollisionConfig.showCollisionBoxes &&
        DebugCollisionConfig.showEnemyBulletHitbox) {
      canvas.drawRect(localHitboxRect, _debugHitboxPaint);
    }
  }

  void onHit() {
    if (!isAlive) return;
    isAlive = false;
    removeFromParent();
  }

  Future<Image?> _loadBulletSprite(String preferredPath) async {
    final candidates = <String>[
      preferredPath,
      'assets/sprites/enemies/enemy_bullet.png',
      'assets/enemies/enemy_bullet.png',
      'assets/enemy/enemy_bullet.png',
    ];

    for (final path in candidates) {
      final image = await loadUiImageSafe(path);
      if (image != null) {
        return image;
      }
    }
    return null;
  }
}
