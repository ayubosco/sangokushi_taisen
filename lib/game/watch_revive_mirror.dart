import 'package:flutter/material.dart';

/// Same-frame Watch read of one skull on the way home.
///
/// Brief 03 / GAP-RET-CASTLE: the skull, 「返城」, and the in-castle bar are
/// the live field state. Not a demo-cycle poster, and not the living
/// 「歸城」 heal cue (that plate is `watch-guicheng`).
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

  /// Grey skull is up. Alive bodies never build this mirror.
  final bool skull;

  /// 「返城」 while the skull is outside 己城. Empty once the gate holds it.
  final String tip;

  /// Countdown bar only while the skull is reviving inside the gate.
  final bool bar;

  /// Seconds left. Frozen outside; the field countdown uses the same number.
  final double reviveLeft;

  /// Adapted base (or 活 ×2/3). Not a new Official second.
  final double reviveTotal;

  /// Watch-band point of the body. Moves when the field body moves.
  final Offset anchor;

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
