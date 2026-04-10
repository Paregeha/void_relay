abstract class HeatEvent {
  const HeatEvent();
}

class HeatIncreaseEvent extends HeatEvent {
  final double amount;
  const HeatIncreaseEvent(this.amount);
}

class HeatResetEvent extends HeatEvent {
  const HeatResetEvent();
}

class HeatOverheatEvent extends HeatEvent {
  const HeatOverheatEvent();
}

class HeatCoolEvent extends HeatEvent {
  final double amount;
  const HeatCoolEvent(this.amount);
}
