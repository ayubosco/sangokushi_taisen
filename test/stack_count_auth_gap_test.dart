import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/data/card_models.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';

import 'feel_gates_test.dart' show readyGame;

/// AUTH-GAP leftover: stack counts on one token. Observed-from-英傑 foil
/// readouts: one token carries a count (4 輕騎兵, 3 長槍兵). Soft Lock records
/// the count per slot. It is not drawn (no badge layout from the foil) and no
/// combat path reads it. Not a Feel Pass.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every token is a single body unless a count is recorded', () {
    final g = readyGame();
    g.setupMatchDemoField();
    for (var i = 0; i < g.field.length; i++) {
      expect(g.stackCountAt(i), 1);
    }
    expect(g.stackCountAt(-1), 1);
    expect(g.stackCountAt(g.field.length), 1);
  });

  test('foil readouts record on one token each: 4 輕騎兵, 3 長槍兵', () {
    final g = _duel();
    expect(g.field[0].troop, TroopType.cavalry);
    expect(g.setStackCount(0, 4), isTrue);
    expect(g.setStackCount(1, 3), isTrue);
    expect(g.stackCountAt(0), 4);
    expect(g.stackCountAt(1), 3);
    // Still one token per slot: the count does not add field slots.
    expect(g.field, hasLength(2));
  });

  test('a count below one or a slot off the field is refused', () {
    final g = _duel();
    expect(g.setStackCount(0, 0), isFalse);
    expect(g.setStackCount(0, -2), isFalse);
    expect(g.setStackCount(2, 4), isFalse);
    expect(g.setStackCount(-1, 4), isFalse);
    expect(g.stackCountAt(0), 1);
  });

  test('a restage clears recorded counts with the rest of the per-unit state', () {
    final g = _duel();
    g.setStackCount(0, 4);
    g.setStackCount(1, 3);
    _restage(g);
    expect(g.stackCountAt(0), 1);
    expect(g.stackCountAt(1), 1);
  });

  test('spawn and hand → 自陣城門 deploy add a single body; earlier counts stay', () {
    final g = _duel();
    g.setStackCount(0, 4);
    expect(g.spawnCard(_foot()), isTrue);
    expect(g.stackCountAt(2), 1);
    g.hand.add(_foot());
    final band = g.castleBandRect;
    expect(g.deployHandCardToGate(0, Offset(band.center.dx, band.top + band.height * 0.8)), isTrue);
    expect(g.stackCountAt(3), 1);
    expect(g.stackCountAt(0), 4);
  });

  test('combat is blind to the count: same march, contact, and HP as a single body', () {
    final single = _duel();
    final stacked = _duel()
      ..setStackCount(0, 4)
      ..setStackCount(1, 3);
    for (final g in [single, stacked]) {
      final from = g.tokenCenter(0);
      g.panStart(from);
      g.panUpdate(g.tokenCenter(1));
      g.panEnd(g.tokenCenter(1));
    }
    final singleHits = <String>[];
    final stackedHits = <String>[];
    for (var f = 0; f < 600; f++) {
      single.debugStepPursuit(1 / 60);
      stacked.debugStepPursuit(1 / 60);
      singleHits.add(single.debugHitLabel);
      stackedHits.add(stacked.debugHitLabel);
    }
    // The run must reach contact, or the comparison proves nothing.
    expect(singleHits, contains('突撃'));
    expect(single.debugUnitHp(1), lessThan(TaisenGame.kRansenMaxHp));
    expect(stackedHits, singleHits);
    for (var i = 0; i < 2; i++) {
      expect(stacked.tokenCenter(i), single.tokenCenter(i));
      expect(stacked.debugUnitHp(i), single.debugUnitHp(i));
      expect(stacked.debugUnitLife(i), single.debugUnitLife(i));
    }
    expect(stacked.stackCountAt(0), 4);
    expect(stacked.stackCountAt(1), 3);
  });
}

CardFace _foot() => Cost6Roster.all.firstWhere((c) => c.troop == TroopType.infantry,
    orElse: () => Cost6Roster.all.first);

TaisenGame _duel() {
  final g = readyGame();
  _restage(g);
  return g;
}

void _restage(TaisenGame g) {
  g.debugRestageOwnEnemy(
    ownId: 'zhaoyun',
    ownAt: Offset(g.size.x * 0.30, g.watchH + g.fieldH * 0.60),
    enemyAt: Offset(g.size.x * 0.70, g.watchH + g.fieldH * 0.20),
  );
}
