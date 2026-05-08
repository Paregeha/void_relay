import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

import '../config/game_config.dart';
import '../core/bloc/events/heat_event.dart';
import '../core/bloc/heat_bloc.dart';
import '../core/bloc/states/heat_state.dart';
import '../flame_game.dart';

class HeatSystem extends Component {
  final HeatBloc heatBloc;
  bool _didLogDisabled = false;
  double _debugHeatLogTimer = 0.0;
  bool _didLogOverheated = false;

  HeatSystem({required this.heatBloc});

  @override
  void update(double dt) {
    super.update(dt);

    if (!GameConfig.enableCoreHeating) {
      if (!_didLogDisabled) {
        _didLogDisabled = true;
        if (false) print('[CoreHeat] disabled by enableCoreHeating=false');
      }
      if (false) print('[CoreHeat] heat update skipped');
      return;
    }

    final game = findGame();
    if (game is VoidRelayGame && game.isGameplayInputBlocked) {
      return;
    }

    if (heatBloc.state is HeatOverheated) {
      if (!_didLogOverheated && kDebugMode) {
        _didLogOverheated = true;
        debugPrint('[CORE_HEAT] overheated');
      }
      return;
    }

    _didLogOverheated = false;

    final heatRate =
        GameConfig.heatIncreasePerSecond * GameConfig.coreHeatGainMultiplier;
    final heatIncrease = heatRate * dt;
    _debugHeatLogTimer += dt;
    if (kDebugMode && _debugHeatLogTimer >= 1.0) {
      _debugHeatLogTimer = 0.0;
      debugPrint(
        '[CORE_HEAT] heat=${heatBloc.state.currentHeat.toStringAsFixed(1)} '
        'max=${GameConfig.maxHeat.toStringAsFixed(1)} '
        'rate=${heatRate.toStringAsFixed(2)}',
      );
    }
    heatBloc.add(HeatIncreaseEvent(heatIncrease));
  }

  void resetHeat() {
    heatBloc.add(const HeatResetEvent());
  }

  void coolHeat(double amount) {
    final before = heatBloc.state.currentHeat;
    heatBloc.add(HeatCoolEvent(amount));
    final after = (before - amount).clamp(0.0, GameConfig.maxHeat).toDouble();
    if (kDebugMode) {
      debugPrint(
        '[CORE_HEAT] cooled by pickup '
        'amount=${amount.toStringAsFixed(1)} '
        'heat=${after.toStringAsFixed(1)}/${GameConfig.maxHeat.toStringAsFixed(1)}',
      );
    }
  }

  double getCurrentHeat() => heatBloc.state.currentHeat;

  double getNormalizedHeat() {
    final maxHeat = GameConfig.maxHeat;
    if (maxHeat <= 0) return 0;
    final normalized = getCurrentHeat() / maxHeat;
    return normalized.clamp(0, 1).toDouble();
  }
}
