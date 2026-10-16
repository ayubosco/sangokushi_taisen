import 'package:flutter/material.dart';

/// Same-frame Watch read of one own skull.
///
/// Brief 03: live skull, 「返城」 while the body is outside the castle gate,
/// and the in-castle revive bar. Not the living 「歸城」 plate, and not a
/// demo poster. Enemy skulls are not mirrored.
class WatchReviveMirror {
  const WatchReviveMirror({
    required this.index,
    required this.skull,
    required this.tip,
    required this.bar,
    required this.reviveLeft,
    required this.reviveTotal,
    required this.anchor,
  });

  final int index;

  /// Own body is not alive (skull / grey card).
  final bool skull;

  /// 「返城」 while the skull is outside the gate. Empty once the countdown runs.
  final String tip;

  /// In-castle revive bar is up. Hidden while the count is frozen outside.
  final bool bar;

  /// Same seconds the field countdown uses this frame.
  final double reviveLeft;

  /// Base or 活／復活 total. Not a new Official duration.
  final double reviveTotal;

  /// Watch-band point of the body. Moves when the field body moves.
  final Offset anchor;

  /// Remaining fraction. Shrinks with [reviveLeft]. 0 when the total is empty.
  double get remain01 {
    if (reviveTotal <= 0) return 0;
    return (reviveLeft / reviveTotal).clamp(0.0, 1.0);
  }

  String get skullTag => 'watch-skull:$index';
  String get tipTag => 'watch-fancheng:$index';
  String get barTag => 'watch-revive:${reviveLeft.toStringAsFixed(2)}';
  String get anchorTag =>
      'watch-revive-at:${anchor.dx.toStringAsFixed(1)},${anchor.dy.toStringAsFixed(1)}';
}
