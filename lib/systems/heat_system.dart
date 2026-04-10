import 'package:flame/components.dart';

import '../config/game_config.dart';
import '../core/bloc/events/heat_event.dart';
import '../core/bloc/heat_bloc.dart';
import '../core/bloc/states/heat_state.dart';
import '../flame_game.dart';

class HeatSystem extends Component {
  final HeatBloc heatBloc;

  HeatSystem({required this.heatBloc});

  @override
  void update(double dt) {
    super.update(dt);

    if (!GameConfig.heatEnabled) return;

    final game = findGame();
    if (game is VoidRelayGame && game.isGameplayInputBlocked) {
      return;
    }

    if (heatBloc.state is HeatOverheated) {
      return;
    }

    final heatIncrease = GameConfig.heatIncreasePerSecond * dt;
    heatBloc.add(HeatIncreaseEvent(heatIncrease));
  }

  void resetHeat() {
    heatBloc.add(const HeatResetEvent());
  }

  void coolHeat(double amount) {
    heatBloc.add(HeatCoolEvent(amount));
  }

  double getCurrentHeat() => heatBloc.state.currentHeat;

  double getNormalizedHeat() {
    final maxHeat = GameConfig.maxHeat;
    if (maxHeat <= 0) return 0;
    final normalized = getCurrentHeat() / maxHeat;
    return normalized.clamp(0, 1).toDouble();
  }
}
