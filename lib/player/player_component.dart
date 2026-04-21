import 'dart:ui';

import 'package:flame/components.dart';
import 'package:void_relay/player/skeletal/player_animation_state.dart';
import 'package:void_relay/player/skeletal/skeletal_player.dart';

import '../config/game_config.dart';
import '../flame_game.dart';
import '../sound_assets.dart';
import '../weapons/beam_cutter.dart';
import '../weapons/pulse_blaster.dart';
import '../weapons/weapon_manager.dart';
import 'player_controller.dart';

enum PlayerAnimState { idle, run, jump, fall, dash, attack, death }

enum PlayerLifeState { alive, dying, dead }

class PlayerComponent extends PositionComponent {
  Vector2 velocity = Vector2.zero();
  double maxHealth = GameConfig.playerMaxHealth;
  double health = GameConfig.playerMaxHealth;
  double _invulnerabilityTimer = 0.0;
  bool isOnGround = false;
  bool canDash = true;
  bool _isSprintHeld = false;
  int facingDirection = 1;
  int _jumpsUsed = 0;
  PlayerAnimState _animState = PlayerAnimState.idle;
  double _dashAnimTimer = 0.0;
  double _dashTrailCooldown = 0.0;
  PlayerLifeState _lifeState = PlayerLifeState.alive;

  // REPLACED: old sprite-sheet visual with hierarchical skeletal puppet.
  SkeletalPlayer? _skeletalVisual;

  late PlayerController _controller;
  late WeaponManager weaponManager;

  PlayerLifeState get lifeState => _lifeState;
  bool get isAlive => _lifeState == PlayerLifeState.alive;
  bool get isDying => _lifeState == PlayerLifeState.dying;
  bool get isDead => _lifeState == PlayerLifeState.dead;

  @override
  Future<void> onLoad() async {
    size = Vector2(32, 64);
    anchor = Anchor.center;

    _controller = PlayerController(this);
    weaponManager = WeaponManager(this);
    add(weaponManager);

    _initDefaultLoadout();
    await _initSkeletalVisual();
  }

  void _initDefaultLoadout() {
    weaponManager.setLoadout([PulseBlaster(), BeamCutter()], initialIndex: 0);
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_dashAnimTimer > 0) _dashAnimTimer -= dt;
    if (_dashTrailCooldown > 0) _dashTrailCooldown -= dt;
    if (_invulnerabilityTimer > 0) _invulnerabilityTimer -= dt;

    final game = findGame();
    final isGameplayBlocked =
        game is VoidRelayGame && game.isGameplayInputBlocked;

    if (!isAlive || isGameplayBlocked) {
      velocity.setZero();
    } else {
      velocity.y += GameConfig.gravity * dt;
      if (velocity.y > GameConfig.maxFallSpeed) {
        velocity.y = GameConfig.maxFallSpeed;
      }

      _controller.update(dt);
      position += velocity * dt;
    }

    _updateAnimationState();
    _syncSkeletalVisual();

    if (_dashAnimTimer > 0 && _dashTrailCooldown <= 0) {
      final game = findGame();
      if (game is VoidRelayGame) {
        game.spawnDashTrail(absolutePosition, direction: facingDirection);
      }
      _dashTrailCooldown = 0.03;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _renderWeapon(canvas);
  }

  // ── Movement ─────────────────────────────────────────────────────────────

  void moveLeft(double dt) {
    velocity.x = -_horizontalSpeed;
    facingDirection = -1;
  }

  void moveRight(double dt) {
    velocity.x = _horizontalSpeed;
    facingDirection = 1;
  }

  double get _horizontalSpeed =>
      GameConfig.playerSpeed *
      (_isSprintHeld ? GameConfig.playerSprintMultiplier : 1.0);

  void setSprintHeld(bool held) {
    _isSprintHeld = held;
  }

  void stopHorizontal() {
    velocity.x = 0;
  }

  void jump() {
    if (GameConfig.playerMaxJumps <= 0) return;

    if (isOnGround) {
      velocity.y = GameConfig.playerJumpForce;
      isOnGround = false;
      _jumpsUsed = 1;
      return;
    }

    if (!_canUseAirJump) return;

    velocity.y = GameConfig.playerJumpForce;
    _jumpsUsed += 1;
  }

  bool get _canUseAirJump => _jumpsUsed < GameConfig.playerMaxJumps;

  void dash() {
    if (canDash) {
      velocity.x += GameConfig.playerDashForce * (velocity.x >= 0 ? 1 : -1);
      canDash = false;
      _dashAnimTimer = 0.12;
      _setAnimationState(PlayerAnimState.dash);
    }
  }

  void land() {
    isOnGround = true;
    canDash = true;
    _jumpsUsed = 0;
  }

  // ── Health ────────────────────────────────────────────────────────────────

  bool get isInvulnerable => _invulnerabilityTimer > 0;

  void takeDamage(double amount) {
    if (!isAlive || isInvulnerable) return;

    health -= amount;
    if (health <= 0) {
      health = 0;
      beginDying();
      final game = findGame();
      if (game is VoidRelayGame) {
        game.beginPlayerDeathSequence();
      }
      return;
    }

    _invulnerabilityTimer = GameConfig.invulnerabilityDuration;

    final game = findGame();
    if (game is VoidRelayGame) {
      game.playSfx(SoundAssets.hit);
      game.spawnHitSpark(absolutePosition);
    }
  }

  // ── Animation state ───────────────────────────────────────────────────────

  void _updateAnimationState() {
    if (!isAlive) {
      _setAnimationState(PlayerAnimState.death);
      return;
    }

    if (_dashAnimTimer > 0) {
      _setAnimationState(PlayerAnimState.dash);
      return;
    }

    if (!isOnGround) {
      _setAnimationState(
        velocity.y < 0 ? PlayerAnimState.jump : PlayerAnimState.fall,
      );
      return;
    }

    if (weaponManager.isTriggerHeld) {
      _setAnimationState(PlayerAnimState.attack);
      return;
    }

    if (velocity.x.abs() > 1) {
      _setAnimationState(PlayerAnimState.run);
      return;
    }

    _setAnimationState(PlayerAnimState.idle);
  }

  void _setAnimationState(PlayerAnimState state) {
    _animState = state;
  }

  SkeletalPlayerAnimationState _resolveSkeletalAnimState() {
    switch (_animState) {
      case PlayerAnimState.idle:
        return SkeletalPlayerAnimationState.idle;
      case PlayerAnimState.run:
        return SkeletalPlayerAnimationState.run;
      case PlayerAnimState.jump:
        return SkeletalPlayerAnimationState.jump;
      case PlayerAnimState.fall:
        return SkeletalPlayerAnimationState.fall;
      case PlayerAnimState.dash:
        return SkeletalPlayerAnimationState.dash;
      case PlayerAnimState.attack:
        return SkeletalPlayerAnimationState.attack;
      case PlayerAnimState.death:
        return SkeletalPlayerAnimationState.death;
    }
  }

  Future<void> _initSkeletalVisual() async {
    _skeletalVisual = SkeletalPlayer()
      ..position = size / 2
      ..size = size.clone();
    add(_skeletalVisual!);
  }

  void _syncSkeletalVisual() {
    final skeletal = _skeletalVisual;
    if (skeletal == null) return;

    skeletal.applyGameplayState(
      animationState: _resolveSkeletalAnimState(),
      velocity: velocity,
      isOnGround: isOnGround,
      facingDirection: facingDirection,
    );
  }

  // ── Weapon render ─────────────────────────────────────────────────────────

  void _renderWeapon(Canvas canvas) {
    if (!isAlive) return;

    const gunLength = 16.0;
    const gunHeight = 5.0;

    final dir = facingDirection.toDouble();
    final centerX = size.x / 2 + dir * (size.x / 2 - 4);
    final centerY = size.y / 2 - 8;

    final bodyPaint = Paint()..color = const Color(0xFF6A6A6A);
    final muzzlePaint = Paint()..color = const Color(0xFFB8E8FF);

    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: gunLength,
        height: gunHeight,
      ),
      bodyPaint,
    );
    canvas.drawCircle(
      Offset(centerX + dir * (gunLength / 2), centerY),
      1.8,
      muzzlePaint,
    );
  }

  void beginDying() {
    if (!isAlive) return;
    _lifeState = PlayerLifeState.dying;
    velocity.setZero();
    _setAnimationState(PlayerAnimState.death);
  }

  void markDead() {
    if (_lifeState == PlayerLifeState.dead) return;
    _lifeState = PlayerLifeState.dead;
    velocity.setZero();
    _setAnimationState(PlayerAnimState.death);
  }
}
