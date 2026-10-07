import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/data/card_models.dart';
import 'package:sangokushi_taisen/game/c_clock.dart';
import 'package:sangokushi_taisen/game/fx_windows.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';
import 'package:sangokushi_taisen/game/unit_life.dart';

import 'feel_gates_test.dart' show readyGame;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cavalry aura contact drops more HP than one second of 亂戰 and stays overlapped', () {
    final g = readyGame();
    final start = Offset(g.size.x * 0.18, g.watchH + g.fieldH * 0.70);
    _placeOwn(g, start, TroopType.cavalry);
    _addEnemy(g, Offset(start.dx + 280, start.dy - 220));
    g.panStart(start);
    g.panEnd(Offset(start.dx + 260, start.dy));
    const dt = 1 / 60.0;
    var guard = 0;
    while (!g.auraActive && g.dragTo != null && guard < 600) {
      g.debugStepPursuit(dt);
      guard++;
    }
    expect(g.auraActive, isTrue);
    g.dragTo = null;
    g.fieldPos[1] = g.fieldPos[0];
    final before = g.debugUnitHp(1);
    g.debugStepPursuit(dt);
    final dropped = before - g.debugUnitHp(1);
    expect(g.debugHitLabel, '突撃');
    expect(dropped, greaterThan(TaisenGame.kRansenTickPerSec));
    expect(g.debugUnitHp(1), greaterThan(0));
    expect(g.debugUnitLife(1), UnitLife.alive);
    expect(g.debugInRansen(0), isTrue);
    expect(g.debugInRansen(1), isTrue);
  });

  test('spear tip is not body 亂戰 and a cavalry on the tip retreats', () {
    final g = readyGame();
    final at = Offset(g.size.x * 0.45, g.watchH + g.fieldH * 0.55);
    _placeOwn(g, at, TroopType.spear);
    final tip = g.spearTipAt(0);
    _addEnemy(g, tip);
    expect(g.inMeleeContact(g.tokenCenter(0), g.tokenCenter(1)), isFalse);
    expect((g.spearTipAt(0) - g.tokenCenter(1)).distance, lessThan(TaisenGame.kSpearTipHitR));

    g.debugStepPursuit(1 / 60);
    expect(g.debugInRansen(0), isFalse);
    expect(g.debugInRansen(1), isFalse);
    expect(g.debugHitLabel, '撤退');
    expect(g.debugRetreatCause(1), '迎擊');
    expect(g.debugUnitHp(1), 0);
    expect(g.debugUnitLife(1), UnitLife.retreating);
    expect(g.debugUnitLife(0), UnitLife.alive);

    final bodies = readyGame();
    final stacked = Offset(bodies.size.x * 0.45, bodies.watchH + bodies.fieldH * 0.55);
    _placeOwn(bodies, stacked, TroopType.spear);
    _addEnemy(bodies, stacked);
    bodies.debugStepPursuit(1 / 60);
    expect(bodies.debugInRansen(0), isTrue);
    expect(bodies.spearTipExtendedAt(0), isFalse);
    expect(bodies.debugHitLabel, isNot('迎擊'));
    expect(bodies.debugUnitLife(1), UnitLife.alive);
  });

  test('a stopped bow shot does not weaken at low HP; marching fires nothing', () {
    final g = readyGame();
    final at = Offset(g.size.x * 0.30, g.watchH + g.fieldH * 0.50);
    _placeOwn(g, at, TroopType.bow);
    _addEnemy(g, at + const Offset(180, 0));
    expect(g.inMeleeContact(g.tokenCenter(0), g.tokenCenter(1)), isFalse);

    g.selectOrDetailAt(at);
    g.debugStepPursuit(CClock.secondsPerC * FxWindows.bowStopBeforeShotC + 0.05);
    expect(g.debugBowWinding, isTrue);
    g.selectOrDetailAt(at);
    final firstDrop = TaisenGame.kRansenMaxHp - g.debugUnitHp(1);
    expect(g.debugHitLabel, '射');
    expect(firstDrop, closeTo(TaisenGame.kBowShotBurstSec * TaisenGame.kRansenTickPerSec, 0.001));

    g.debugSetUnitHp(1, TaisenGame.kRansenMaxHp);
    g.debugSetUnitHp(0, 8);
    g.selectOrDetailAt(at);
    g.debugStepPursuit(CClock.secondsPerC * FxWindows.bowStopBeforeShotC + 0.05);
    g.selectOrDetailAt(at);
    final secondDrop = TaisenGame.kRansenMaxHp - g.debugUnitHp(1);
    expect(secondDrop, closeTo(firstDrop, 0.001));
    expect(g.debugUnitHp(0), 8);

    final moving = readyGame();
    final from = Offset(moving.size.x * 0.28, moving.watchH + moving.fieldH * 0.50);
    _placeOwn(moving, from, TroopType.bow);
    _addEnemy(moving, from + const Offset(180, 0));
    moving.selectOrDetailAt(from);
    moving.debugStepPursuit(CClock.secondsPerC * FxWindows.bowStopBeforeShotC + 0.05);
    moving.panStart(from);
    // Enemy sits on +x. A downward march is outside the aim cone, so no arrow.
    moving.panEnd(from + const Offset(0, 140));
    moving.selectOrDetailAt(from);
    expect(moving.debugUnitHp(1), TaisenGame.kRansenMaxHp);
    moving.debugStepPursuit(0.2);
    expect(moving.debugBowWinding, isFalse);
    expect(moving.debugUnitHp(1), TaisenGame.kRansenMaxHp);
  });

  test('infantry only trades the overlap tick and never flashes 突撃', () {
    final g = readyGame();
    final at = Offset(g.size.x * 0.40, g.watchH + g.fieldH * 0.40);
    _placeOwn(g, at, TroopType.infantry);
    _addEnemy(g, at);
    g.debugStepPursuit(1);
    expect(g.debugHitLabel, isNot('突撃'));
    expect(g.debugUnitHp(0), closeTo(TaisenGame.kRansenMaxHp - TaisenGame.kRansenTickPerSec, 0.05));
    expect(g.debugUnitHp(1), closeTo(TaisenGame.kRansenMaxHp - TaisenGame.kRansenTickPerSec, 0.05));
    expect(g.debugUnitLife(1), UnitLife.alive);
  });

  test('siege 亂戰 barely chips the enemy; castle-band contact still hurts the siege', () {
    final scramble = readyGame();
    final at = Offset(scramble.size.x * 0.42, scramble.watchH + scramble.fieldH * 0.42);
    expect(scramble.inCastleBand(at), isFalse);
    _placeOwn(scramble, at, TroopType.siege);
    _addEnemy(scramble, at);
    scramble.debugStepPursuit(1);
    final siegeDealt = TaisenGame.kRansenMaxHp - scramble.debugUnitHp(1);
    expect(
      siegeDealt,
      closeTo(TaisenGame.kRansenTickPerSec * TaisenGame.kSiegeRansenMul, 0.05),
    );
    expect(siegeDealt, lessThan(TaisenGame.kRansenTickPerSec * 0.5));
    expect(scramble.debugUnitLife(1), UnitLife.alive);

    final castle = readyGame();
    final band = castle.castleBandRect;
    final siegeAt = Offset(band.left + 64, band.top + band.height * 0.55);
    final enemyAt = Offset(band.right - 64, siegeAt.dy);
    _placeOwn(castle, siegeAt, TroopType.siege);
    _addEnemy(castle, enemyAt);
    expect(castle.inCastleBand(siegeAt), isTrue);
    expect(castle.inCastleBand(enemyAt), isTrue);
    expect(castle.inMeleeContact(siegeAt, enemyAt), isFalse);
    castle.debugStepPursuit(1);
    expect(castle.debugCastleChipAt(0), isTrue);
    expect(castle.debugUnitHp(0), closeTo(TaisenGame.kRansenMaxHp - TaisenGame.kRansenTickPerSec, 0.05));
    expect(castle.debugUnitHp(1), TaisenGame.kRansenMaxHp);
    expect(castle.debugInRansen(0), isFalse);
  });
}

void _placeOwn(TaisenGame g, Offset at, TroopType troop) {
  final card = Cost6Roster.all.firstWhere((c) => c.troop == troop);
  g.field
    ..clear()
    ..add(card);
  g.fieldPos
    ..clear()
    ..add(at);
  g.fieldIsEnemy
    ..clear()
    ..add(false);
  g.fieldInCastle
    ..clear()
    ..add(false);
  g.selectedIndex = 0;
  g.dragging = false;
  g.dragTo = null;
}

void _addEnemy(TaisenGame g, Offset at) {
  final card = Cost6Roster.all.firstWhere((c) => c.id == 'caocao');
  g.field.add(card);
  g.fieldIsEnemy.add(true);
  g.fieldInCastle.add(false);
  g.fieldPos.add(at);
}
