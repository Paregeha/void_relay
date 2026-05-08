import 'dart:ui';

import 'package:flame/components.dart';

import '../../config/game_config.dart';
import '../../core/utils/safe_asset_loader.dart';

class RepairTerminal extends PositionComponent {
  static const String _blueTerminalPath =
      'assets/sprites/world/terminal_blue.png';
  static const String _redTerminalPath =
      'assets/sprites/world/terminal_red.png';
  static const double _width = 36.0;
  static const double _height = 52.0;
  static const double _completedVisualDuration = 0.9;

  // Separate visual tuning per asset to compensate different padding/centering.
  static const _TerminalVisualConfig _blueVisualConfig = _TerminalVisualConfig(
    size: Size(42.0, 58.0),
    offset: Offset(0.0, 0.0),
  );
  static const _TerminalVisualConfig _redVisualConfig = _TerminalVisualConfig(
    size: Size(49.0, 66.0),
    offset: Offset(0.0, 8.0),
  );

  static Future<void>? _sharedTerminalLoadFuture;
  static Image? _sharedBlueTerminalImage;
  static Image? _sharedRedTerminalImage;

  final double interactionRange;
  final String saveId;
  final void Function()? onRepairCompleted;
  final bool Function()? isDoorFailureActive;

  bool isRepairing = false;
  bool isRepaired = false;

  double _pulseTimer = 0;
  double _repairProgress = 0;
  double _completedTimer = 0;

  double get repairProgress => _repairProgress;

  double get completedTimer => _completedTimer;

  RepairTerminal({
    required Vector2 position,
    required this.saveId,
    this.interactionRange = 64,
    this.onRepairCompleted,
    this.isDoorFailureActive,
  }) : super(
         position: position,
         size: Vector2(_width, _height),
         anchor: Anchor.bottomCenter,
       );

  void restoreState({
    required bool isRepairing,
    required bool isRepaired,
    required double repairProgress,
    required double completedTimer,
  }) {
    this.isRepairing = isRepairing;
    this.isRepaired = isRepaired;
    _repairProgress = repairProgress;
    _completedTimer = completedTimer;
  }

  bool get canStartRepair => !isRepairing && !isRepaired;

  bool get _showLockedVisual => isDoorFailureActive?.call() ?? false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _ensureSharedTerminalImagesLoaded();
  }

  void startRepair() {
    if (!canStartRepair) return;
    isRepairing = true;
    _repairProgress = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _pulseTimer += dt;

    if (isRepaired && !isRepairing) {
      _completedTimer += dt;
      if (_completedTimer >= _completedVisualDuration) {
        isRepaired = false;
        _completedTimer = 0;
        _repairProgress = 0;
      }
    }

    if (!isRepairing) return;

    _repairProgress += dt;
    if (_repairProgress >= GameConfig.doorRepairDuration) {
      isRepairing = false;
      isRepaired = true;
      _completedTimer = 0;
      _repairProgress = GameConfig.doorRepairDuration;
      onRepairCompleted?.call();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final isLocked = _showLockedVisual;
    final terminalImage = isLocked
        ? _sharedRedTerminalImage
        : _sharedBlueTerminalImage;
    final visualConfig = isLocked ? _redVisualConfig : _blueVisualConfig;

    if (terminalImage != null) {
      final sourceRect = Rect.fromLTWH(
        0,
        0,
        terminalImage.width.toDouble(),
        terminalImage.height.toDouble(),
      );
      final destRect = Rect.fromLTWH(
        (size.x - visualConfig.size.width) / 2 + visualConfig.offset.dx,
        size.y - visualConfig.size.height + visualConfig.offset.dy,
        visualConfig.size.width,
        visualConfig.size.height,
      );
      final paint = Paint()
        ..isAntiAlias = false
        ..filterQuality = FilterQuality.none;
      canvas.drawImageRect(terminalImage, sourceRect, destRect, paint);
    } else {
      final t = (_pulseTimer * 2).remainder(2.0);
      final pulse = t < 1.0 ? 0.55 + t * 0.35 : 0.9 - (t - 1.0) * 0.35;

      final borderColor = isRepaired
          ? Color.fromRGBO(90, 255, 140, 0.95)
          : (isRepairing
                ? Color.fromRGBO(255, 210, 80, pulse)
                : Color.fromRGBO(170, 190, 210, 0.82));

      final coreColor = isRepaired
          ? const Color(0xFF34E07E)
          : (isRepairing ? const Color(0xFFFFC94B) : const Color(0xFF56616E));

      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = const Color(0xFF111821),
      );

      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );

      canvas.drawRect(
        Rect.fromLTWH(8, 10, size.x - 16, size.y - 24),
        Paint()..color = coreColor,
      );
    }

    final progress = (GameConfig.doorRepairDuration <= 0)
        ? 0.0
        : (_repairProgress / GameConfig.doorRepairDuration).clamp(0.0, 1.0);

    canvas.drawRect(
      Rect.fromLTWH(6, size.y - 10, size.x - 12, 5),
      Paint()..color = const Color(0x445A6878),
    );

    canvas.drawRect(
      Rect.fromLTWH(6, size.y - 10, (size.x - 12) * progress, 5),
      Paint()
        ..color = isRepaired
            ? const Color(0xFF45F58B)
            : const Color(0xFFFFD268),
    );
  }

  Future<void> _ensureSharedTerminalImagesLoaded() async {
    final inFlight = _sharedTerminalLoadFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final loadFuture = _loadSharedTerminalImages();
    _sharedTerminalLoadFuture = loadFuture;
    await loadFuture;
  }

  Future<void> _loadSharedTerminalImages() async {
    final blue = await loadUiImageSafe(_blueTerminalPath);
    final red = await loadUiImageSafe(_redTerminalPath);
    _sharedBlueTerminalImage = blue;
    _sharedRedTerminalImage = red;
  }
}

class _TerminalVisualConfig {
  const _TerminalVisualConfig({required this.size, required this.offset});

  final Size size;
  final Offset offset;
}
