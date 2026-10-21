import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/data/card_models.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';

import 'feel_gates_test.dart' show readyGame;

/// AUTH-GAP §3 弓攻城. Observed-from-英傑 stage 4 遠攻削敵「速派單一弓兵攻城」:
/// one archer on the enemy gate shows「攻城中」+ countdown. The bow reuses the
/// siege gauge, fill rate, and gate/wall nick. No bow siege number is invented.
/// Not a Feel Pass.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('unverified knobs stay put; no 攻城 button', () {
    final g = readyGame();
    expect(TaisenGame.kSiegePrepFillPerSec, 0.25);
    expect(TaisenGame.kSiegePrepBowSlowMul, 0.55);
    expect(TaisenGame.kSiegeWallNick, 0.03);
    expect(TaisenGame.kSiegeGateNick, 0.05);
    expect(g.floatingActionHitRect('攻城'), Rect.zero);
  });

  test('only 攻城 and 弓 siege; 槍 / 騎 / 歩 were not observed', () {
    expect(TaisenGame.sieges(TroopType.siege), isTrue);
    expect(TaisenGame.sieges(TroopType.bow), isTrue);
    expect(TaisenGame.sieges(TroopType.spear), isFalse);
    expect(TaisenGame.sieges(TroopType.cavalry), isFalse);
    expect(TaisenGame.sieges(TroopType.infantry), isFalse);
  });

  test('a single bow on the enemy gate shows 攻城中 + countdown and does not chip', () {
    final g = readyGame();
    final castle = g.enemyCastle;
    _placeOwn(g, _inEnemyZone(g, gate: true), TroopType.bow);
    expect(g.inEnemyCastleZone(0), isTrue);
    expect(g.debugSiegePrepVisible(0), isTrue);
    expect(g.debugSiegeFace(0), 'gate');
    expect(g.debugSiegeCaption(0), '攻城中');

    g.debugStepPursuit(0);
    final full = (1 / TaisenGame.kSiegePrepFillPerSec).ceil();
    expect(g.debugSiegeCountdownSec(0), full);
    expect(g.enemyCastle, castle);
    expect(g.debugUnitHp(0), TaisenGame.kRansenMaxHp);
  });

  test('the bow countdown runs down with the fill at the 攻城 rate', () {
    final g = readyGame();
    _placeOwn(g, _inEnemyZone(g, gate: true), TroopType.bow);
    g.debugStepPursuit(1.0);
    expect(g.debugSiegePrep01(0), closeTo(TaisenGame.kSiegePrepFillPerSec, 1e-9));
    expect(g.debugSiegeCountdownSec(0), (1 / TaisenGame.kSiegePrepFillPerSec).ceil() - 1);
  });

  test('a move holds the bow gauge and the countdown', () {
    final g = readyGame();
    final at = _inEnemyZone(g, gate: true);
    _placeOwn(g, at, TroopType.bow);
    g.debugStepPursuit(1.0);
    final held = g.debugSiegePrep01(0);
    final left = g.debugSiegeCountdownSec(0);

    g.panStart(at);
    g.panUpdate(Offset(at.dx, at.dy + 36));
    g.debugStepPursuit(0.4);
    expect(g.inEnemyCastleZone(0), isTrue);
    expect(g.debugSiegePrepPause(0), 'move');
    expect(g.debugSiegePrep01(0), held);
    expect(g.debugSiegeCountdownSec(0), left);
  });

  test('a full bow prep nicks the castle once; gate above wall', () {
    final gate = _completedBowNick(gate: true);
    final wall = _completedBowNick(gate: false);
    expect(gate, closeTo(TaisenGame.kSiegeGateNick, 1e-6));
    expect(wall, closeTo(TaisenGame.kSiegeWallNick, 1e-6));
    expect(gate, greaterThan(wall));
  });

  test('leaving the zone clears the bow gauge and caption', () {
    final g = readyGame();
    _placeOwn(g, _inEnemyZone(g, gate: true), TroopType.bow);
    g.debugStepPursuit(0.4);
    expect(g.debugSiegePrep01(0), greaterThan(0));

    g.fieldPos[0] = Offset(g.size.x * 0.42, g.watchH + g.fieldH * 0.42);
    g.debugStepPursuit(0);
    expect(g.debugSiegePrepVisible(0), isFalse);
    expect(g.debugSiegePrep01(0), 0);
    expect(g.debugSiegeCaption(0), isEmpty);
    expect(g.debugSiegeCountdownSec(0), 0);
  });

  test('a spear on the gate still grows no gauge and no caption', () {
    final g = readyGame();
    _placeOwn(g, _inEnemyZone(g, gate: true), TroopType.spear);
    g.debugStepPursuit(0.4);
    expect(g.debugSiegePrepVisible(0), isFalse);
    expect(g.debugSiegeCaption(0), isEmpty);
    expect(g.spearTipExtendedAt(0), isTrue);
  });

  test('Watch mirrors the sieging bow and drops its demo plate', () {
    final g = readyGame();
    _placeOwn(g, _inEnemyZone(g, gate: true), TroopType.bow);
    g.debugStepPursuit(0.4);
    final m = g.debugWatchSiegeMirror(0);
    expect(m, isNotNull);
    expect(m!.fill01, g.debugSiegePrep01(0));
    expect(g.debugWatchDemoPlateSuppressed(0), isTrue);

    g.fieldPos[0] = Offset(g.size.x * 0.42, g.watchH + g.fieldH * 0.42);
    g.debugStepPursuit(0);
    expect(g.debugWatchSiegeMirror(0), isNull);
    expect(g.debugWatchDemoPlateSuppressed(0), isFalse);
  });
}

double _completedBowNick({required bool gate}) {
  final g = readyGame();
  _placeOwn(g, _inEnemyZone(g, gate: gate), TroopType.bow);
  expect(g.debugSiegeFace(0), gate ? 'gate' : 'wall');
  final before = g.enemyCastle;
  g.debugStepPursuit(1 / TaisenGame.kSiegePrepFillPerSec);
  expect(g.debugSiegePrepsLanded(0), 1);
  expect(g.debugSiegePrep01(0), 0);
  expect(g.debugSiegePrepVisible(0), isTrue);
  expect(g.debugRetreatCause(0), isEmpty);
  return before - g.enemyCastle;
}

Offset _inEnemyZone(TaisenGame g, {required bool gate}) {
  final zone = g.enemyCastleZoneRect;
  final x = gate ? zone.center.dx : zone.width * 0.08;
  return Offset(x, zone.top + zone.height * 0.45);
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
