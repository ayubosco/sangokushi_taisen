import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/data/card_models.dart';
import 'package:sangokushi_taisen/game/c_clock.dart';
import 'package:sangokushi_taisen/game/fx_windows.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';

import 'feel_gates_test.dart' show readyGame;

/// Brief 02 — 弓 静止射撃. Stopped fire, drag/march silence, 走射 off,
/// 亂戰 cancel, half-field sticky aim, aura 軽減 stub, siege-slow only
/// while that bow is actually standing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('H0 chrome and Unverified knobs stay at the Soft Pass values', () {
    final g = readyGame();
    expect(TaisenGame.kWatchFractionOfGame, 0.125);
    expect(g.watchH / g.size.y, closeTo(0.125, 1e-9));
    expect(g.fieldH / g.size.y, closeTo(0.875, 1e-9));
    expect(TaisenGame.kTokenWidthFracOfField, closeTo(0.097, 1e-9));
    expect(TaisenGame.kSoftPinPathPx, 261);
    expect(TaisenGame.kChargeTravelNeed, 120);
    expect(TaisenGame.kReviveBaseSec, 15);
    expect(TaisenGame.kSpearTipReach, closeTo(48 * 1.28, 1e-9));
    expect(TaisenGame.kStrategySealPt, 64);
    expect(g.debugBowRangePx, closeTo(g.fieldH * 0.5, 1e-9));
    expect(TaisenGame.pursuitWikiBase(TroopType.bow), 0.8);
    expect(g.floatingActionHitRect('射'), Rect.zero);
    expect(g.floatingActionHitRect('射撃'), Rect.zero);
  });

  test('a stopped bow looses after 蓄勢 with no drag, and low HP does not weaken it', () {
    final g = readyGame();
    final at = _fieldAt(g, 0.42, 0.55);
    _placeOwn(g, at, TroopType.bow);
    _addEnemy(g, at + const Offset(150, -20), 'zhangliang');
    expect(g.inMeleeContact(g.tokenCenter(0), g.tokenCenter(1)), isFalse);
    expect((g.tokenCenter(1) - g.tokenCenter(0)).distance, lessThan(g.debugBowRangePx));
    g.debugSetUnitHp(0, 8);

    final windup = _windupSec;
    g.debugStepPursuit(windup * 0.45);
    expect(g.debugBowWinding, isTrue, reason: '蓄勢 tell before the first arrow');
    expect(g.debugHitLabel, isNot('射'));
    expect(g.debugUnitHp(1), TaisenGame.kRansenMaxHp);
    expect(g.debugBowLockAt(0), 1);

    g.debugStepPursuit(windup * 0.65);
    final drop = TaisenGame.kRansenMaxHp - g.debugUnitHp(1);
    expect(g.debugHitLabel, '射');
    expect(g.debugBowWinding, isFalse);
    expect(drop, closeTo(_fullShot, 0.001));
    expect(g.debugUnitHp(0), 8, reason: 'shooter HP does not scale the burst');
    expect(g.dragging, isFalse);
    expect(g.dragTo, isNull);
  });

  test('drag and a committed march loose nothing, then a fresh 蓄勢 is required', () {
    final g = readyGame();
    final at = _fieldAt(g, 0.40, 0.50);
    _placeOwn(g, at, TroopType.bow);
    _addEnemy(g, at + const Offset(130, -36), 'zhangliang');

    final windup = _windupSec;
    g.debugStepPursuit(windup * 0.85);
    expect(g.debugBowWinding, isTrue);
    expect(g.debugUnitHp(1), TaisenGame.kRansenMaxHp);

    g.panStart(at);
    g.panUpdate(at + const Offset(90, 0));
    g.debugStepPursuit(windup);
    expect(g.dragging, isTrue);
    expect(g.debugBowMovingAt(0), isTrue);
    expect(g.debugBowWinding, isFalse);
    expect(g.debugHitLabel, isNot('射'));
    expect(g.debugUnitHp(1), TaisenGame.kRansenMaxHp);

    g.panEnd(at + const Offset(0, 80));
    var frames = 0;
    while (g.dragTo != null && frames < 500) {
      g.debugStepPursuit(1 / 60);
      frames++;
      expect(g.debugUnitHp(1), TaisenGame.kRansenMaxHp, reason: 'frame $frames');
      expect(g.debugHitLabel, isNot('射'));
      expect(g.debugBowWinding, isFalse);
    }
    expect(g.dragTo, isNull);
    expect(g.debugBowMovingAt(0), isFalse);

    g.debugStepPursuit(windup * 0.45);
    expect(g.debugBowWinding, isTrue, reason: 're-settle shows 蓄勢 before the arrow');
    expect(g.debugUnitHp(1), TaisenGame.kRansenMaxHp);
    g.debugStepPursuit(windup * 0.65);
    expect(g.debugHitLabel, '射');
    expect(TaisenGame.kRansenMaxHp - g.debugUnitHp(1), closeTo(_fullShot, 0.001));
  });

  test('creeping the body without a waypoint still silences the volley', () {
    final g = readyGame();
    final at = _fieldAt(g, 0.38, 0.48);
    _placeOwn(g, at, TroopType.bow);
    _addEnemy(g, at + const Offset(160, 0), 'zhangliang');
    g.debugStepPursuit(_windupSec * 0.5);
    expect(g.debugBowWinding, isTrue);

    final frames = (_windupSec * 60).ceil();
    for (var i = 0; i < frames; i++) {
      g.fieldPos[0] = g.fieldPos[0] + const Offset(0, 1.2);
      g.debugStepPursuit(1 / 60);
      expect(g.debugUnitHp(1), TaisenGame.kRansenMaxHp, reason: 'creep $i');
      expect(g.debugBowWinding, isFalse);
    }
    expect(g.dragTo, isNull);
    expect(
      (g.tokenCenter(1) - g.tokenCenter(0)).distance,
      lessThan(g.debugBowRangePx),
      reason: 'the creep must stay inside the existing half-field',
    );

    g.debugStepPursuit(_windupSec * 0.4);
    expect(g.debugBowWinding, isTrue);
    expect(g.debugUnitHp(1), TaisenGame.kRansenMaxHp);
    g.debugStepPursuit(_windupSec * 0.7);
    expect(g.debugHitLabel, '射');
  });

  test('adjacent range-only keeps shooting; body overlap cancels the same frame', () {
    final g = readyGame();
    final at = _fieldAt(g, 0.46, 0.52);
    _placeOwn(g, at, TroopType.bow);
    final gap = g.meleeContactDist + 14;
    _addEnemy(g, at + Offset(gap, 0), 'zhangliang');
    expect(g.inMeleeContact(g.tokenCenter(0), g.tokenCenter(1)), isFalse);
    expect((g.tokenCenter(1) - at).distance, lessThan(g.debugBowRangePx));

    g.debugStepPursuit(_windupSec * 0.45);
    expect(g.debugBowWinding, isTrue);
    g.debugStepPursuit(_windupSec * 0.65);
    expect(g.debugHitLabel, '射');
    expect(TaisenGame.kRansenMaxHp - g.debugUnitHp(1), closeTo(_fullShot, 0.001));

    final afterShot = g.debugUnitHp(1);
    g.fieldPos[1] = g.fieldPos[0];
    g.debugStepPursuit(0.35);
    expect(g.debugInRansen(0), isTrue);
    expect(g.debugInRansen(1), isTrue);
    expect(g.debugBowWinding, isFalse);
    final glued = afterShot - g.debugUnitHp(1);
    expect(glued, lessThan(_fullShot * 0.5), reason: '乱戦 tick is not another arrow');
    expect(glued, greaterThan(0));

    g.fieldPos[1] = g.fieldPos[0] + Offset(gap, 0);
    g.debugStepPursuit(1 / 60);
    expect(g.debugInRansen(0), isFalse);
    final peeled = g.debugUnitHp(1);
    g.debugStepPursuit(_windupSec * 0.45);
    expect(g.debugBowWinding, isTrue);
    expect(g.debugUnitHp(1), closeTo(peeled, 0.05));
    g.debugStepPursuit(_windupSec * 0.65);
    expect(peeled - g.debugUnitHp(1), closeTo(_fullShot, 0.05));
  });

  test('half-field range holds; past it never looses', () {
    final inside = readyGame();
    final at = _fieldAt(inside, 0.50, 0.86);
    _placeOwn(inside, at, TroopType.bow);
    final inDist = inside.debugBowRangePx * 0.80;
    _addEnemy(inside, at + Offset(0, -inDist), 'zhangliang');
    expect((inside.tokenCenter(1) - at).distance, lessThan(inside.debugBowRangePx));
    inside.debugStepPursuit(_windupSec * 1.15);
    expect(inside.debugHitLabel, '射');

    final outside = readyGame();
    final farAt = _fieldAt(outside, 0.50, 0.90);
    _placeOwn(outside, farAt, TroopType.bow);
    final outDist = outside.debugBowRangePx * 1.12;
    _addEnemy(outside, farAt + Offset(0, -outDist), 'zhangliang');
    expect((outside.tokenCenter(1) - farAt).distance, greaterThan(outside.debugBowRangePx));
    outside.debugStepPursuit(_windupSec * 2);
    expect(outside.debugHitLabel, isNot('射'));
    expect(outside.debugBowWinding, isFalse);
    expect(outside.debugBowLockAt(0), isNull);
    expect(outside.debugUnitHp(1), TaisenGame.kRansenMaxHp);
  });

  test('micro-twist keeps the lock; a large reface may switch', () {
    final g = readyGame();
    final at = _fieldAt(g, 0.40, 0.58);
    _placeOwn(g, at, TroopType.bow);
    g.ownFacing = 0;
    _addEnemy(g, at + const Offset(0, -200), 'zhangliang');
    _addEnemy(g, at + const Offset(110, -40), 'zhouyu');
    g.debugStepPursuit(1 / 60);
    expect(g.debugBowLockAt(0), 1, reason: 'front target sticks first');

    g.debugLockCardFacing(0, 0.70);
    g.debugStepPursuit(1 / 60);
    expect(g.debugBowLockAt(0), 1, reason: '0.70 rad is under the large-reface gate');
    expect(g.debugUnitHp(2), TaisenGame.kRansenMaxHp);

    g.debugLockCardFacing(0, TaisenGame.kBowRetargetFacingRad + 0.20);
    g.debugStepPursuit(1 / 60);
    expect(g.debugBowLockAt(0), 2);
  });

  test('aura cavalry takes the existing 軽減 stub, less than the same cav standing', () {
    final openDrop = _oneShot(armAura: false);
    final auraDrop = _oneShot(armAura: true);
    expect(openDrop, closeTo(_fullShot, 0.001));
    expect(auraDrop, lessThan(openDrop));
    expect(auraDrop, closeTo(openDrop * TaisenGame.kBowVsChargeAuraMul, 0.001));
    expect(TaisenGame.kBowVsChargeAuraMul, lessThan(1));
    expect(TaisenGame.kBowVsChargeAuraMul, greaterThan(0));
  });

  test('a moving bow does not slow the siege gauge; a standing bow does', () {
    final still = readyGame();
    final siegeAt = _ownSiegeZone(still);
    _placeOwn(still, siegeAt, TroopType.siege);
    final bowAt = siegeAt + const Offset(0, 170);
    _addEnemy(still, bowAt, 'sunquan');
    expect((bowAt - siegeAt).distance, lessThan(still.debugBowRangePx));
    expect(still.inMeleeContact(siegeAt, bowAt), isFalse);
    still.debugStepPursuit(0.35);
    expect(still.debugSiegePrepSlowed(0), isTrue);
    expect(
      still.debugSiegePrep01(0),
      closeTo(0.35 * TaisenGame.kSiegePrepFillPerSec * TaisenGame.kSiegePrepBowSlowMul, 1e-6),
    );

    still.fieldPos[1] = bowAt + const Offset(36, 0);
    final before = still.debugSiegePrep01(0);
    still.debugStepPursuit(0.35);
    expect(still.debugSiegePrepSlowed(0), isFalse);
    expect(
      still.debugSiegePrep01(0) - before,
      closeTo(0.35 * TaisenGame.kSiegePrepFillPerSec, 1e-6),
    );

    final marching = readyGame();
    final at = _enemyCastle(marching);
    _placeEnemySiege(marching, at);
    final ownBow = at + const Offset(0, -160);
    _addOwn(marching, ownBow, TroopType.bow);
    expect((ownBow - at).distance, lessThan(marching.debugBowRangePx));
    marching.debugStepPursuit(0.3);
    expect(marching.debugSiegePrepSlowed(0), isTrue);

    marching.panStart(ownBow);
    marching.panUpdate(ownBow + const Offset(80, 0));
    final mid = marching.debugSiegePrep01(0);
    marching.debugStepPursuit(0.3);
    expect(marching.debugBowMovingAt(1), isTrue);
    expect(marching.debugSiegePrepSlowed(0), isFalse);
    expect(
      marching.debugSiegePrep01(0) - mid,
      closeTo(0.3 * TaisenGame.kSiegePrepFillPerSec, 1e-6),
    );
  });

  test('Watch paints 蓄勢 only while the bow is stopped and winding', () {
    final g = readyGame();
    final at = _fieldAt(g, 0.44, 0.50);
    _placeOwn(g, at, TroopType.bow);
    _addEnemy(g, at + const Offset(140, -10), 'zhangliang');
    g.watchKind = AWindowKind.bow;
    g.debugStepPursuit(_windupSec * 0.4);
    expect(g.debugBowWinding, isTrue);
    _paint(g);
    expect(g.debugWatchPaintLog, contains('watch-bow'));

    g.panStart(at);
    g.panUpdate(at + const Offset(70, 0));
    _paint(g);
    expect(g.debugWatchPaintLog, isNot(contains('watch-bow')));
    expect(g.debugWatchPaintLog, isNot(contains('demo-bow')));
    expect(g.debugBowWinding, isFalse);
  });
}

double get _windupSec => CClock.secondsPerC * FxWindows.bowStopBeforeShotC;

double get _fullShot => TaisenGame.kBowShotBurstSec * TaisenGame.kRansenTickPerSec;

double _oneShot({required bool armAura}) {
  final g = readyGame();
  final at = _fieldAt(g, 0.36, 0.55);
  _placeOwn(g, at, TroopType.bow);
  _addEnemy(g, at + const Offset(150, -24), 'caocao');
  expect(g.field[1].troop, TroopType.cavalry);
  expect(g.inMeleeContact(g.tokenCenter(0), g.tokenCenter(1)), isFalse);
  if (armAura) g.debugArmEnemyChargeAura();
  g.debugStepPursuit(_windupSec * 1.15);
  expect(g.debugHitLabel, '射');
  return TaisenGame.kRansenMaxHp - g.debugUnitHp(1);
}

Offset _fieldAt(TaisenGame g, double xFrac, double yFrac) =>
    Offset(g.size.x * xFrac, g.watchH + g.fieldH * yFrac);

Offset _ownSiegeZone(TaisenGame g) {
  final zone = g.enemyCastleZoneRect;
  return Offset(zone.center.dx, zone.top + zone.height * 0.45);
}

Offset _enemyCastle(TaisenGame g) {
  final zone = g.castleBandRect;
  return Offset(zone.center.dx, zone.top + zone.height * 0.5);
}

void _placeOwn(TaisenGame g, Offset at, TroopType troop) {
  final picked = Cost6Roster.all.firstWhere((c) => c.troop == troop);
  g.field
    ..clear()
    ..add(picked);
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

void _placeEnemySiege(TaisenGame g, Offset at) {
  final card = Cost6Roster.all.firstWhere((c) => c.troop == TroopType.siege);
  g.field
    ..clear()
    ..add(card);
  g.fieldPos
    ..clear()
    ..add(at);
  g.fieldIsEnemy
    ..clear()
    ..add(true);
  g.fieldInCastle
    ..clear()
    ..add(false);
  g.selectedIndex = null;
  g.dragging = false;
  g.dragTo = null;
}

void _addOwn(TaisenGame g, Offset at, TroopType troop) {
  final card = Cost6Roster.all.firstWhere((c) => c.troop == troop);
  g.field.add(card);
  g.fieldIsEnemy.add(false);
  g.fieldInCastle.add(false);
  g.fieldPos.add(at);
}

void _addEnemy(TaisenGame g, Offset at, String id) {
  final card = Cost6Roster.all.firstWhere((c) => c.id == id);
  g.field.add(card);
  g.fieldIsEnemy.add(true);
  g.fieldInCastle.add(false);
  g.fieldPos.add(at);
}

void _paint(TaisenGame g) {
  g.debugRecordWatchPaint = true;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  g.render(canvas);
  recorder.endRecording().dispose();
}
