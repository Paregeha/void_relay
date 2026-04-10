import 'dart:ui';

import 'package:flame/components.dart';

import '../../config/game_config.dart';
import '../../core/utils/safe_asset_loader.dart';
import '../../player/player_component.dart';
import '../../world/platform/platform_component.dart';
import '../base_enemy.dart';
import 'crawler_ai.dart';

enum CrawlerAnimState { idle, move, attack }

class Crawler extends BaseEnemy {
  PlayerComponent? player;
  List<PlatformComponent> platforms = const [];
  late CrawlerAI ai;

  CrawlerAnimState _animState = CrawlerAnimState.idle;
  double _animTime = 0;
  SpriteAnimationGroupComponent<CrawlerAnimState>? _spriteGroup;

  @override
  Future<void> onLoad() async {
    useDefaultMovement = false;
    await super.onLoad();
    size = Vector2(32, 32);
    health = GameConfig.crawlerHealth;
    ai = CrawlerAI();
    await _tryInitSpriteAnimation();
  }

  @override
  void update(double dt) {
    _animTime += dt;
    _updateAi(dt);
    _applyGravity(dt);
    // Single movement integration path from BaseEnemy.
    super.update(dt);
    _resolveGroundCollision(dt);
    _updateAnimationState();
    if (_spriteGroup != null) {
      _spriteGroup!.current = _animState;
    }
  }

  void _updateAi(double dt) {
    final playerRef = player;
    if (playerRef == null) return;
    ai.update(this, playerRef, dt);
  }

  void _applyGravity(double dt) {
    velocity.y += GameConfig.gravity * dt;
    if (velocity.y > GameConfig.maxFallSpeed) {
      velocity.y = GameConfig.maxFallSpeed;
    }
  }

  void _resolveGroundCollision(double dt) {
    if (platforms.isEmpty || velocity.y < 0) return;

    final crawlerRect = toRect();
    final prevBottom = crawlerRect.bottom - velocity.y * dt;

    for (final platform in platforms) {
      final platformRect = platform.toRect();
      final horizontalOverlap =
          crawlerRect.right >
              platformRect.left + GameConfig.platformCollisionTolerance &&
          crawlerRect.left <
              platformRect.right - GameConfig.platformCollisionTolerance;
      if (!horizontalOverlap) continue;

      final crossedPlatformTop =
          prevBottom <=
              platformRect.top + GameConfig.platformCollisionTolerance &&
          crawlerRect.bottom >= platformRect.top;
      if (!crossedPlatformTop) continue;

      position.y = platformRect.top - size.y / 2;
      velocity.y = 0;
      return;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_spriteGroup == null) {
      final paint = Paint()..color = _resolvePlaceholderColor();
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
    }
  }

  void _updateAnimationState() {
    if (ai.currentState == 'chase') {
      _animState = CrawlerAnimState.attack;
      return;
    }
    if (velocity.x.abs() > 0.1) {
      _animState = CrawlerAnimState.move;
      return;
    }
    _animState = CrawlerAnimState.idle;
  }

  Color _resolvePlaceholderColor() {
    switch (_animState) {
      case CrawlerAnimState.idle:
        return const Color(0xFF00CC66);
      case CrawlerAnimState.move:
        return _animTime % 0.2 < 0.1
            ? const Color(0xFF00FF88)
            : const Color(0xFF00DD77);
      case CrawlerAnimState.attack:
        return const Color(0xFF55FF33);
    }
  }

  Future<void> _tryInitSpriteAnimation() async {
    final image = await loadUiImageSafe(
      'assets/sprites/enemies/crawler_sheet.png',
    );
    if (image == null) {
      _spriteGroup = null;
      return;
    }

    final animations = <CrawlerAnimState, SpriteAnimation>{
      CrawlerAnimState.idle: SpriteAnimation.fromFrameData(
        image,
        SpriteAnimationData.sequenced(
          amount: 2,
          stepTime: 0.2,
          textureSize: Vector2(32, 32),
          texturePosition: Vector2.zero(),
        ),
      ),
      CrawlerAnimState.move: SpriteAnimation.fromFrameData(
        image,
        SpriteAnimationData.sequenced(
          amount: 4,
          stepTime: 0.1,
          textureSize: Vector2(32, 32),
          texturePosition: Vector2(0, 32),
        ),
      ),
      CrawlerAnimState.attack: SpriteAnimation.fromFrameData(
        image,
        SpriteAnimationData.sequenced(
          amount: 3,
          stepTime: 0.08,
          textureSize: Vector2(32, 32),
          texturePosition: Vector2(0, 64),
        ),
      ),
    };

    _spriteGroup = SpriteAnimationGroupComponent<CrawlerAnimState>(
      animations: animations,
      current: _animState,
      size: size,
    );
    add(_spriteGroup!);
  }
}
