import 'dart:ui';

import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../core/utils/safe_asset_loader.dart';
import '../flame_game.dart';
import '../sound_assets.dart';
import '../weapons/beam_cutter.dart';
import '../weapons/pulse_blaster.dart';
import '../weapons/weapon_manager.dart';
import 'player_controller.dart';

enum PlayerAnimState { idle, run, jump, dash, gun, death }

enum PlayerLifeState { alive, dying, dead }

class PlayerComponent extends PositionComponent {
  static const String _playerSheetPath =
      'assets/sprites/player/player_sheet.png';
  static final Vector2 _playerSheetFrameSize = Vector2(512, 512);

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
  double _animTime = 0.0;
  PlayerLifeState _lifeState = PlayerLifeState.alive;

  SpriteAnimationGroupComponent<PlayerAnimState>? _spriteVisual;
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
    await _tryInitSpriteVisual();
  }

  void _initDefaultLoadout() {
    weaponManager.setLoadout([PulseBlaster(), BeamCutter()], initialIndex: 0);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _animTime += dt;
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
    _syncSpriteVisual();

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
    // super.render propagates to children, including sprite animation group.
    super.render(canvas);
    if (_spriteVisual == null) {
      final paint = Paint()..color = _resolvePlaceholderColor();
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
    }
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

    // Jump #1 from ground + one extra jump in air for MVP mobility.
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

  // ── Animation ─────────────────────────────────────────────────────────────

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
      _setAnimationState(PlayerAnimState.jump);
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

  PlayerAnimState _resolveVisualAnimState() {
    if (_animState == PlayerAnimState.death) return PlayerAnimState.death;
    if (_animState == PlayerAnimState.jump ||
        _animState == PlayerAnimState.dash) {
      return PlayerAnimState.jump;
    }
    if (_animState == PlayerAnimState.run) return PlayerAnimState.run;
    if (_animState == PlayerAnimState.gun) return PlayerAnimState.gun;
    return PlayerAnimState.idle;
  }

  void _syncSpriteVisual() {
    final visual = _spriteVisual;
    if (visual == null) return;

    visual.current = _resolveVisualAnimState();
    visual.scale = Vector2(facingDirection < 0 ? -1 : 1, 1);
  }

  Color _resolvePlaceholderColor() {
    switch (_animState) {
      case PlayerAnimState.idle:
        return const Color(0xFFFF3A3A);
      case PlayerAnimState.run:
        return _animTime % 0.2 < 0.1
            ? const Color(0xFFFF6A6A)
            : const Color(0xFFFF4A4A);
      case PlayerAnimState.jump:
        return const Color(0xFFFF9A3A);
      case PlayerAnimState.dash:
        return const Color(0xFFFFFF3A);
      case PlayerAnimState.gun:
        return const Color(0xFF7AA4FF);
      case PlayerAnimState.death:
        return const Color(0xFF777777);
    }
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

  // ── Sprite visual layer ───────────────────────────────────────────────────

  Future<void> _tryInitSpriteVisual() async {
    final image = await loadUiImageSafe(_playerSheetPath);
    if (image == null) {
      _spriteVisual = null;
      return;
    }

    final animations = <PlayerAnimState, SpriteAnimation>{
      PlayerAnimState.idle: _buildSheetAnimation(
        image,
        row: 0,
        columns: const [0, 1, 2, 3],
        stepTime: 0.16,
      ),
      PlayerAnimState.jump: _buildSheetAnimation(
        image,
        row: 1,
        columns: const [0, 1, 2],
        stepTime: 0.12,
      ),
      PlayerAnimState.run: _buildSheetAnimation(
        image,
        row: 2,
        columns: const [0, 1, 2, 3, 4, 5, 6],
        stepTime: 0.09,
      ),
      PlayerAnimState.gun: _buildSheetAnimation(
        image,
        row: 3,
        columns: const [0, 1, 2],
        stepTime: 0.1,
      ),
      PlayerAnimState.death: _buildSheetAnimation(
        image,
        row: 4,
        columns: const [0, 1, 2],
        stepTime: 0.12,
        loop: false,
      ),
      // Dash reuses run frames for now.
      PlayerAnimState.dash: _buildSheetAnimation(
        image,
        row: 2,
        columns: const [0, 1, 2, 3, 4, 5, 6],
        stepTime: 0.08,
      ),
    };

    _spriteVisual = SpriteAnimationGroupComponent<PlayerAnimState>(
      animations: animations,
      current: _resolveVisualAnimState(),
      size: size,
      position: size / 2,
      anchor: Anchor.center,
    );

    await add(_spriteVisual!);
    _syncSpriteVisual();
  }

  SpriteAnimation _buildSheetAnimation(
    Image image, {
    required int row,
    required List<int> columns,
    required double stepTime,
    bool loop = true,
  }) {
    final sprites = columns
        .map(
          (column) => Sprite(
            image,
            srcPosition: Vector2(
              column * _playerSheetFrameSize.x,
              row * _playerSheetFrameSize.y,
            ),
            srcSize: _playerSheetFrameSize,
          ),
        )
        .toList(growable: false);

    return SpriteAnimation.spriteList(sprites, stepTime: stepTime, loop: loop);
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
