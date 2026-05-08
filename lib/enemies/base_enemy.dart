import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../flame_game.dart';
import 'enemy_health_bar.dart';

enum EnemyLifeState { alive, dying, dead }

class BaseEnemy extends PositionComponent {
  String saveId = '';
  String saveType = 'base_enemy';
  Vector2 velocity = Vector2.zero();
  double maxHealth = GameConfig.baseEnemyHealth;
  double health = GameConfig.baseEnemyHealth;
  double difficultyHpMultiplier = 1.0;
  double difficultySpeedMultiplier = 1.0;
  double difficultyDamageMultiplier = 1.0;
  double difficultyProjectileSpeedMultiplier = 1.0;
  bool useDefaultMovement = true;
  double defaultSpeedX = GameConfig.enemyDefaultSpeedX;
  EnemyLifeState lifeState = EnemyLifeState.alive;

  bool get isAlive => lifeState == EnemyLifeState.alive;
  bool get isDying => lifeState == EnemyLifeState.dying;
  bool get isDead => lifeState == EnemyLifeState.dead;
  double get maxHp => maxHealth;
  set maxHp(double value) => maxHealth = value;
  double get hp => health;
  set hp(double value) => health = value;

  /// Can this enemy currently damage the player via body overlap.
  bool get canDealContactDamage => isAlive && health > 0;

  /// Contact damage value used by collision handler.
  double get contactDamage =>
      GameConfig.enemyContactDamage * difficultyDamageMultiplier;

  /// Hook for one-shot attack windows (e.g. crawler bite).
  void onContactDamageApplied() {}

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Single unified position update path for all enemies.
    anchor = Anchor.center;
    if (useDefaultMovement) {
      velocity.x = defaultSpeedX;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final game = findGame();
    if (game is VoidRelayGame && game.isGameplayInputBlocked) {
      return;
    }
    if (useDefaultMovement) {
      velocity.x = defaultSpeedX;
    }
    // Unified enemy movement integration path.
    position += velocity * dt;
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = const Color(0xFF0000FF);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
  }

  @override
  void renderTree(Canvas canvas) {
    super.renderTree(canvas);
    _renderHealthBarOverlay(canvas);
  }

  void takeDamage(double damage) {
    if (!isAlive) return;
    if (damage <= 0) return;
    health -= damage;
    if (health <= 0) {
      die();
    }
  }

  bool get showHealthBar =>
      GameConfig.showEnemyHpBars && maxHealth > 0 && health < maxHealth;

  Rect get healthBarBoundsLocal => Rect.fromLTWH(0, 0, size.x, size.y);

  double get healthBarGap => 6.0;

  double get healthBarHeight => 5.0;

  void _renderHealthBarOverlay(Canvas canvas) {
    if (!showHealthBar || !isAlive || maxHealth <= 0) return;

    final bounds = healthBarBoundsLocal;
    if (bounds.width <= 0) return;

    final top = bounds.top - healthBarGap - healthBarHeight;
    EnemyHealthBar.render(
      canvas,
      left: bounds.left,
      top: top,
      width: bounds.width,
      hp: health,
      maxHp: maxHealth,
      height: healthBarHeight,
    );
  }

  void die() {
    if (isDead) return;
    health = 0;
    lifeState = EnemyLifeState.dead;
    removeFromParent();
  }

  void onPlayerDetected() {
    // Hook for future logic
  }

  bool get saveFacingRight => velocity.x >= 0;

  void applySaveFacingRight(bool value) {
    final speed = velocity.x.abs();
    velocity.x = value ? speed : -speed;
  }

  String get saveState => lifeState.name;
}
