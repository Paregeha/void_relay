import 'package:flutter_bloc/flutter_bloc.dart';

import '../../config/game_config.dart';
import 'events/heat_event.dart';
import 'states/heat_state.dart';

class HeatBloc extends Bloc<HeatEvent, HeatState> {
  HeatBloc() : super(const HeatInitial()) {
    on<HeatIncreaseEvent>(_onHeatIncrease);
    on<HeatResetEvent>(_onHeatReset);
    on<HeatOverheatEvent>(_onOverheat);
    on<HeatCoolEvent>(_onHeatCool);
  }

  Future<void> _onHeatIncrease(
    HeatIncreaseEvent event,
    Emitter<HeatState> emit,
  ) async {
    double newHeat = state.currentHeat + event.amount;

    // Cap at maxHeat
    if (newHeat > GameConfig.maxHeat) {
      newHeat = GameConfig.maxHeat;
    }

    // Check if overheated
    if (newHeat >= GameConfig.overheatThreshold) {
      emit(HeatOverheated(newHeat));
    } else {
      emit(HeatUpdated(newHeat, false));
    }
  }

  Future<void> _onHeatReset(
    HeatResetEvent event,
    Emitter<HeatState> emit,
  ) async {
    emit(const HeatInitial());
  }

  Future<void> _onOverheat(
    HeatOverheatEvent event,
    Emitter<HeatState> emit,
  ) async {
    emit(HeatOverheated(GameConfig.maxHeat));
  }

  Future<void> _onHeatCool(HeatCoolEvent event, Emitter<HeatState> emit) async {
    final newHeat = (state.currentHeat - event.amount).clamp(
      0.0,
      GameConfig.maxHeat,
    );
    if (newHeat == 0) {
      emit(const HeatInitial());
    } else {
      emit(HeatUpdated(newHeat, false));
    }
  }
}
