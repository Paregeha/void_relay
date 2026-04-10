abstract class HeatState {
  final double currentHeat;
  const HeatState(this.currentHeat);
}

class HeatInitial extends HeatState {
  const HeatInitial() : super(0.0);
}

class HeatUpdated extends HeatState {
  final bool isOverheated;
  const HeatUpdated(double heat, this.isOverheated) : super(heat);
}

class HeatOverheated extends HeatState {
  const HeatOverheated(double heat) : super(heat);
}
