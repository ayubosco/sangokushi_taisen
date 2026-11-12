import 'package:flutter/material.dart';

import '../data/card_models.dart';

/// Same-frame Watch read of one body on the field.
///
/// 全戰場 Monitor: the Watch shows every body of both sides, not only the
/// featured own/enemy pair. Position, life and HP are the field's own numbers
/// this frame. Read-only, no new combat value.
class WatchUnitMirror {
  const WatchUnitMirror({
    required this.index,
    required this.enemy,
    required this.troop,
    required this.down,
    required this.hp01,
    required this.anchor,
    required this.depth01,
  });

  final int index;
  final bool enemy;
  final TroopType troop;

  /// Retreating, reviving in 己城, or waiting to redeploy.
  final bool down;

  /// 0–1 of the field HP bar.
  final double hp01;

  /// Watch-band point of the body. Moves when the field body moves.
  final Offset anchor;

  /// 0 near (own castle) to 1 far (enemy castle).
  final double depth01;

  /// Far bodies read smaller. The featured pair keeps its own larger scale.
  double get scale =>
      (enemy ? 0.82 - 0.22 * depth01 : 1.0 - 0.28 * depth01).clamp(0.55, 1.0) * 0.8;

  String get unitTag => 'watch-unit:$index:${enemy ? 'enemy' : 'own'}';
  String get anchorTag =>
      'watch-unit-at:$index:${anchor.dx.toStringAsFixed(1)},${anchor.dy.toStringAsFixed(1)}';
  String get downTag => 'watch-unit-down:$index';
}

/// Standing bodies over all bodies, per side. The 戰場情況 headcount.
class WatchFieldTally {
  const WatchFieldTally({
    required this.ownUp,
    required this.ownAll,
    required this.enemyUp,
    required this.enemyAll,
  });

  factory WatchFieldTally.of(Iterable<WatchUnitMirror> roster) {
    var ownUp = 0, ownAll = 0, enemyUp = 0, enemyAll = 0;
    for (final u in roster) {
      if (u.enemy) {
        enemyAll++;
        if (!u.down) enemyUp++;
      } else {
        ownAll++;
        if (!u.down) ownUp++;
      }
    }
    return WatchFieldTally(
      ownUp: ownUp,
      ownAll: ownAll,
      enemyUp: enemyUp,
      enemyAll: enemyAll,
    );
  }

  final int ownUp;
  final int ownAll;
  final int enemyUp;
  final int enemyAll;

  String get label => '己 $ownUp／$ownAll　敵 $enemyUp／$enemyAll';
  String get tag => 'watch-tally:$ownUp/$ownAll:$enemyUp/$enemyAll';
}
