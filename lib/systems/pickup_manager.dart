import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

class PickupManager extends Component {
  PickupManager({
    required this.trySpawnCooling,
    required this.trySpawnHeart,
    this.coolingMinInterval = 12.0,
    this.coolingMaxInterval = 18.0,
    this.heartMinInterval = 18.0,
    this.heartMaxInterval = 25.0,
  });

  final bool Function() trySpawnCooling;
  final bool Function() trySpawnHeart;

  final double coolingMinInterval;
  final double coolingMaxInterval;
  final double heartMinInterval;
  final double heartMaxInterval;

  final math.Random _random = math.Random();
  double _coolingTimer = 0.0;
  double _heartTimer = 0.0;
  double _nextCoolingSpawn = 14.0;
  double _nextHeartSpawn = 21.0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _nextCoolingSpawn = _pickInterval(coolingMinInterval, coolingMaxInterval);
    _nextHeartSpawn = _pickInterval(heartMinInterval, heartMaxInterval);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (dt <= 0) return;

    _coolingTimer += dt;
    _heartTimer += dt;

    if (_coolingTimer >= _nextCoolingSpawn) {
      _coolingTimer = 0.0;
      trySpawnCooling();
      _nextCoolingSpawn = _pickInterval(coolingMinInterval, coolingMaxInterval);
    }

    if (_heartTimer >= _nextHeartSpawn) {
      _heartTimer = 0.0;
      trySpawnHeart();
      _nextHeartSpawn = _pickInterval(heartMinInterval, heartMaxInterval);
    }
  }

  double _pickInterval(double min, double max) {
    if (max <= min) return min;
    final value = min + _random.nextDouble() * (max - min);
    if (kDebugMode) {
      debugPrint('[PICKUP_SPAWN] next interval=${value.toStringAsFixed(2)}s');
    }
    return value;
  }
}
