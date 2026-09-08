/// Locked A windows — durations in C (1C ≈ 3.03s). Drive FX from these, not wall-clock.
class FxWindows {
  static const double chargeAuraVisibleC = 1.0;
  static const double interceptTurnAfterAuraC = 1.0;
  static const double bowStopBeforeShotC = 1.0;
  static const double strategyFxMaxC = 1.0;

  static double toSeconds(double c) => c * 3.03;
}
