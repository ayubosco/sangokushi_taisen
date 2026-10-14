import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/data/card_models.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';

import 'feel_gates_test.dart' show readyGame;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('H0 and unverified knobs stay put', () {
    final g = readyGame();
    expect(TaisenGame.kWatchFractionOfGame, 0.125);
    expect(g.watchH / g.size.y, closeTo(0.125, 1e-9));
    expect(g.fieldH / g.size.y, closeTo(0.875, 1e-9));
    expect(TaisenGame.kTokenWidthFracOfField, closeTo(0.097, 1e-9));
    expect(TaisenGame.kSoftPinPathPx, 261);
    expect(TaisenGame.kChargeTravelNeed, 120);
    expect(TaisenGame.kReviveBaseSec, 15);
    expect(g.floatingActionHitRect('攻城'), Rect.zero);
    expect(g.floatingActionHitRect('突擊'), Rect.zero);
  });

  test('enter enemy castle zone shows a prep gauge and does not chip', () {
    final g = readyGame();
    final at = _inEnemyZone(g, gate: true);
    final castle = g.enemyCastle;
    _placeOwn(g, at, TroopType.siege);
    expect(g.debugSiegePrepVisible(0), isTrue);
    expect(g.debugSiegeFace(0), 'gate');
    g.debugStepPursuit(0);
    expect(g.debugSiegePrepVisible(0), isTrue);
    expect(g.debugSiegePrep01(0), 0);
    expect(g.debugSiegePrepsLanded(0), 0);
    expect(g.debugSiegePrepPause(0), isEmpty);
    expect(g.enemyCastle, castle);
    expect(g.debugUnitHp(0), TaisenGame.kRansenMaxHp);
    expect(g.debugRetreatCause(0), isEmpty);
  });

  test('prep fills only while stationary and outside 亂戰', () {
    final g = readyGame();
    final at = _inEnemyZone(g, gate: true);
    _placeOwn(g, at, TroopType.siege);
    g.debugStepPursuit(0.4);
    expect(
      g.debugSiegePrep01(0),
      closeTo(0.4 * TaisenGame.kSiegePrepFillPerSec, 1e-9),
    );
    expect(g.debugSiegePrepsLanded(0), 0);
    expect(g.debugSiegePrepPause(0), isEmpty);

    final held = g.debugSiegePrep01(0);
    g.panStart(at);
    g.panUpdate(Offset(at.dx, at.dy + 36));
    g.debugStepPursuit(0.4);
    expect(g.inEnemyCastleZone(0), isTrue);
    expect(g.debugSiegePrepPause(0), 'move');
    expect(g.debugSiegePrep01(0), held);
    expect(g.debugSiegePrepVisible(0), isTrue);
  });

  test('leave zone clears the gauge; re-enter starts from empty', () {
    final g = readyGame();
    final at = _inEnemyZone(g, gate: true);
    _placeOwn(g, at, TroopType.siege);
    g.debugStepPursuit(0.4);
    expect(g.debugSiegePrep01(0), greaterThan(0));

    g.fieldPos[0] = Offset(g.size.x * 0.42, g.watchH + g.fieldH * 0.42);
    g.dragTo = null;
    g.dragging = false;
    g.debugStepPursuit(0.2);
    expect(g.inEnemyCastleZone(0), isFalse);
    expect(g.debugSiegePrepVisible(0), isFalse);
    expect(g.debugSiegePrep01(0), 0);

    g.fieldPos[0] = at;
    g.debugStepPursuit(0.2);
    expect(g.debugSiegePrepVisible(0), isTrue);
    expect(
      g.debugSiegePrep01(0),
      closeTo(0.2 * TaisenGame.kSiegePrepFillPerSec, 1e-9),
    );
  });

  test('ally bump and 亂戰 pause the fill', () {
    final ally = readyGame();
    final at = _inEnemyZone(ally, gate: true);
    _placeOwn(ally, at, TroopType.siege);
    ally.debugStepPursuit(0.4);
    final held = ally.debugSiegePrep01(0);
    _addBody(ally, at, TroopType.infantry, enemy: false);
    ally.debugStepPursuit(0.4);
    expect(ally.debugInRansen(0), isFalse);
    expect(ally.debugSiegePrepPause(0), 'ally');
    expect(ally.debugSiegePrep01(0), held);
    expect(ally.debugSiegePrepVisible(0), isTrue);
    expect(ally.debugUnitHp(0), TaisenGame.kRansenMaxHp);

    final mash = readyGame();
    final mashAt = _inEnemyZone(mash, gate: true);
    _placeOwn(mash, mashAt, TroopType.siege);
    mash.debugStepPursuit(0.4);
    final mashHeld = mash.debugSiegePrep01(0);
    _addBody(mash, mashAt, TroopType.cavalry, enemy: true);
    mash.debugStepPursuit(0.4);
    expect(mash.debugInRansen(0), isTrue);
    expect(mash.debugSiegePrepPause(0), 'ransen');
    expect(mash.debugSiegePrep01(0), mashHeld);
    expect(mash.debugSiegePrepVisible(0), isTrue);
  });

  test('an opposing bow in the existing range slows fill; no bow does not', () {
    final open = readyGame();
    final openAt = _inEnemyZone(open, gate: true);
    _placeOwn(open, openAt, TroopType.siege);
    _addBody(open, openAt + const Offset(0, 180), TroopType.cavalry, enemy: true);
    open.debugStepPursuit(1);
    expect(
      open.debugSiegePrep01(0),
      closeTo(TaisenGame.kSiegePrepFillPerSec, 1e-9),
    );
    expect(open.debugSiegePrepSlowed(0), isFalse);

    final pressed = readyGame();
    final at = _inEnemyZone(pressed, gate: true);
    _placeOwn(pressed, at, TroopType.siege);
    final bowAt = at + const Offset(0, 180);
    _addBody(pressed, bowAt, TroopType.bow, enemy: true);
    final gap = (bowAt - at).distance;
    expect(gap, lessThan(pressed.fieldH * 0.5));
    expect(pressed.inMeleeContact(at, bowAt), isFalse);
    pressed.debugStepPursuit(1);
    expect(pressed.debugSiegePrepSlowed(0), isTrue);
    expect(
      pressed.debugSiegePrep01(0),
      closeTo(TaisenGame.kSiegePrepFillPerSec * TaisenGame.kSiegePrepBowSlowMul, 1e-6),
    );
    expect(pressed.debugSiegePrep01(0), lessThan(open.debugSiegePrep01(0)));

    final far = readyGame();
    final farSiege = _inEnemyZone(far, gate: true);
    _placeOwn(far, farSiege, TroopType.siege);
    final band = far.castleBandRect;
    final farBow = Offset(band.center.dx, band.top + band.height * 0.5);
    _addBody(far, farBow, TroopType.bow, enemy: true);
    expect((farBow - farSiege).distance, greaterThan(far.fieldH * 0.5));
    far.debugStepPursuit(1);
    expect(far.debugSiegePrepSlowed(0), isFalse);
    expect(
      far.debugSiegePrep01(0),
      closeTo(TaisenGame.kSiegePrepFillPerSec, 1e-9),
    );
  });

  test('a full prep nicks the castle, and the gate nick is greater than the wall', () {
    final gateDrop = _completedNick(gate: true);
    final wallDrop = _completedNick(gate: false);
    expect(wallDrop, closeTo(TaisenGame.kSiegeWallNick, 1e-6));
    expect(gateDrop, closeTo(TaisenGame.kSiegeGateNick, 1e-6));
    expect(gateDrop, greaterThan(wallDrop));
  });

  test('a spear in the enemy castle zone keeps its tip and grows no prep gauge', () {
    final g = readyGame();
    final at = _inEnemyZone(g, gate: true);
    _placeOwn(g, at, TroopType.spear);
    expect(g.spearTipExtendedAt(0), isTrue);
    expect(g.debugSiegePrepVisible(0), isFalse);
    g.debugStepPursuit(0.2);
    expect(g.spearTipExtendedAt(0), isTrue);
    expect(g.debugSiegePrep01(0), 0);
    expect(g.debugSiegePrepVisible(0), isFalse);
  });
}

double _completedNick({required bool gate}) {
  final g = readyGame();
  final at = _inEnemyZone(g, gate: gate);
  _placeOwn(g, at, TroopType.siege);
  expect(g.debugSiegeFace(0), gate ? 'gate' : 'wall');
  final before = g.enemyCastle;
  final hp = g.debugUnitHp(0);
  g.debugStepPursuit(1 / TaisenGame.kSiegePrepFillPerSec);
  expect(g.debugSiegePrepsLanded(0), 1);
  expect(g.debugSiegePrep01(0), 0);
  expect(g.debugSiegePrepVisible(0), isTrue);
  expect(g.debugUnitHp(0), hp);
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

void _addBody(TaisenGame g, Offset at, TroopType troop, {required bool enemy}) {
  final card = Cost6Roster.all.firstWhere(
    (c) => c.troop == troop && (enemy || c.id != g.field.first.id),
  );
  g.field.add(card);
  g.fieldIsEnemy.add(enemy);
  g.fieldInCastle.add(false);
  g.fieldPos.add(at);
}
