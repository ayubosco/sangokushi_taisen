/// Troop life after HP hits 0. Not a Feel boot.
///
/// Living 歸城 is not this machine. An alive body parked in 己城 heals
/// and keeps the 「歸城」 / 「返城回血」 cue. No skull and no revive bell.
///
/// alive → retreating when HP ≤ 0.
/// retreating → inCastleReviving only inside the own castle gate.
/// Outside that gate the countdown stays frozen (「返城」 until re-entry).
/// inCastleReviving → readyRedeploy when the countdown ends (HP full).
/// readyRedeploy → alive once the body leaves the castle.
enum UnitLife { alive, retreating, inCastleReviving, readyRedeploy }

/// True when a skill name is 活 or 復活. No other skill changes the timer.
bool skillHasRevive(Iterable<String> skills) => skills.any((s) => s.contains('活'));

/// Base 15s [adapted]. 活／復活 multiplies by 2/3 (≈10s). No per-troop table.
double reviveSeconds({
  required bool skilled,
  required double baseSec,
  required double skillMul,
}) {
  return skilled ? baseSec * skillMul : baseSec;
}
