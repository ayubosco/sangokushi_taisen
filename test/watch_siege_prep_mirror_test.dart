import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/data/card_models.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';
import 'package:sangokushi_taisen/game/watch_siege_mirror.dart';

import 'feel_gates_test.dart' show readyGame;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('H0 chrome and unverified knobs stay put while Watch mirrors siege prep',
      () {
    final g = readyGame();
    expect(TaisenGame.kWatchFractionOfGame, 0.125);
    expect(g.watchH / g.size.y, closeTo(0.125, 1e-9));
    expect(g.fieldH / g.size.y, closeTo(0.875, 1e-9));
    expect(TaisenGame.kTokenWidthFracOfField, closeTo(0.097, 1e-9));
    expect(TaisenGame.kSoftPinPathPx, 261);
    expect(TaisenGame.kChargeTravelNeed, 120);
    expect(TaisenGame.kReviveBaseSec, 15);
    expect(g.floatingActionHitRect('攻城'), Rect.zero);
    expect(watchPaintsOwnDemoPlate(ownIsSiege: true), isFalse);
    expect(watchPaintsOwnDemoPlate(ownIsSiege: false), isTrue);
  });

  test('Watch fill matches the field gauge and is not a demo plate', () {
    final g = readyGame();
    final at = _ownZone(g, gate: true);
    _placeOwn(g, at, TroopType.siege);
    g.watchKind = AWindowKind.intercept;
    g.debugStepPursuit(0.4);

    final mirror = g.debugWatchSiegeMirror(0)!;
    expect(g.debugWatchDemoPlateSuppressed(0), isTrue);
    expect(mirror.fill01, closeTo(g.debugSiegePrep01(0), 1e-9));
    expect(mirror.fill01, closeTo(0.4 * TaisenGame.kSiegePrepFillPerSec, 1e-9));
    expect(mirror.pause, isEmpty);
    expect(mirror.paused, isFalse);
    expect(mirror.slowed, isFalse);
    expect(mirror.face, 'gate');
    expect(mirror.anchor, g.mapFieldToWatch(g.watchBodyAt(0), _band(g)));

    _paintWatch(g);
    expect(g.debugWatchPaintLog, contains(mirror.prepTag));
    expect(g.debugWatchPaintLog, contains(mirror.anchorTag));
    expect(g.debugWatchPaintLog, contains(mirror.faceTag));
    expect(g.debugWatchPaintLog, isNot(contains('demo-intercept')));
    expect(g.debugWatchPaintLog, isNot(contains('demo-bow')));
    expect(g.debugWatchPaintLog, isNot(contains('demo-charge')));
    expect(g.debugWatchPaintLog, isNot(contains('watch-tip')));
    expect(g.debugWatchPaintLog, isNot(contains('watch-bow')));
    expect(
      g.debugWatchPaintLog,
      contains('castle-enemy:${g.enemyCastle.toStringAsFixed(4)}'),
    );
  });

  test('pause, clear, and a body move stay same-frame on Watch', () {
    final g = readyGame();
    final at = _ownZone(g, gate: true);
    _placeOwn(g, at, TroopType.siege);
    g.debugStepPursuit(0.4);
    final held = g.debugSiegePrep01(0);
    final before = g.debugWatchSiegeMirror(0)!.anchor;

    g.panStart(at);
    g.panUpdate(Offset(at.dx, at.dy + 36));
    g.debugStepPursuit(0.4);
    final paused = g.debugWatchSiegeMirror(0)!;
    expect(paused.pause, 'move');
    expect(paused.pause, g.debugSiegePrepPause(0));
    expect(paused.fill01, held);
    expect(paused.fill01, g.debugSiegePrep01(0));
    g.watchKind = AWindowKind.bow;
    _paintWatch(g);
    expect(g.debugWatchPaintLog, contains(paused.pauseTag));
    expect(g.debugWatchPaintLog, contains(paused.prepTag));
    expect(g.debugWatchPaintLog, isNot(contains('demo-bow')));

    g.dragging = false;
    g.dragTo = null;
    g.fieldPos[0] = Offset(at.dx + 18, at.dy);
    g.debugStepPursuit(0);
    final moved = g.debugWatchSiegeMirror(0)!;
    expect(moved.fill01, held);
    expect(moved.anchor.dx, isNot(closeTo(before.dx, 0.5)));
    expect(moved.anchor, g.mapFieldToWatch(g.watchBodyAt(0), _band(g)));
    _paintWatch(g);
    expect(g.debugWatchPaintLog, contains(moved.anchorTag));

    g.fieldPos[0] = Offset(g.size.x * 0.42, g.watchH + g.fieldH * 0.42);
    g.debugStepPursuit(0.2);
    expect(g.debugSiegePrepVisible(0), isFalse);
    expect(g.debugWatchSiegeMirror(0), isNull);
    expect(g.debugWatchSiegeMirrors(), isEmpty);
    expect(g.debugWatchDemoPlateSuppressed(0), isTrue);
    g.watchKind = AWindowKind.intercept;
    _paintWatch(g);
    expect(
        g.debugWatchPaintLog.where((t) => t.startsWith('siege-prep')), isEmpty);
    expect(g.debugWatchPaintLog, isNot(contains('demo-intercept')));
  });

  test('ally bump and 亂戰 pause the Watch gauge on the same fill', () {
    final ally = readyGame();
    final at = _ownZone(ally, gate: true);
    _placeOwn(ally, at, TroopType.siege);
    ally.debugStepPursuit(0.4);
    final held = ally.debugSiegePrep01(0);
    _addBody(ally, at, TroopType.infantry, enemy: false);
    ally.debugStepPursuit(0.4);
    final mirror = ally.debugWatchSiegeMirror(0)!;
    expect(mirror.pause, 'ally');
    expect(mirror.fill01, held);
    _paintWatch(ally);
    expect(ally.debugWatchPaintLog, contains('siege-pause:ally'));
    expect(ally.debugWatchPaintLog, contains(mirror.prepTag));

    final mash = readyGame();
    final mashAt = _ownZone(mash, gate: true);
    _placeOwn(mash, mashAt, TroopType.siege);
    mash.debugStepPursuit(0.4);
    final mashHeld = mash.debugSiegePrep01(0);
    _addBody(mash, mashAt, TroopType.cavalry, enemy: true);
    mash.debugStepPursuit(0.4);
    final mashMirror = mash.debugWatchSiegeMirror(0)!;
    expect(mashMirror.pause, 'ransen');
    expect(mashMirror.fill01, mashHeld);
    _paintWatch(mash);
    expect(mash.debugWatchPaintLog, contains('siege-pause:ransen'));
  });

  test('bow slow on the field is the Watch slow mark and the shorter fill', () {
    final open = readyGame();
    _placeOwn(open, _ownZone(open, gate: true), TroopType.siege);
    open.debugStepPursuit(1);
    final openMirror = open.debugWatchSiegeMirror(0)!;
    expect(openMirror.slowed, isFalse);
    _paintWatch(open);
    expect(open.debugWatchPaintLog, isNot(contains('siege-slow')));

    final pressed = readyGame();
    final at = _ownZone(pressed, gate: true);
    _placeOwn(pressed, at, TroopType.siege);
    final bowAt = at + const Offset(0, 180);
    _addBody(pressed, bowAt, TroopType.bow, enemy: true);
    pressed.debugStepPursuit(1);
    final mirror = pressed.debugWatchSiegeMirror(0)!;
    expect(mirror.slowed, pressed.debugSiegePrepSlowed(0));
    expect(mirror.slowed, isTrue);
    expect(
      mirror.fill01,
      closeTo(TaisenGame.kSiegePrepFillPerSec * TaisenGame.kSiegePrepBowSlowMul,
          1e-6),
    );
    expect(mirror.fill01, lessThan(openMirror.fill01));
    _paintWatch(pressed);
    expect(pressed.debugWatchPaintLog, contains('siege-slow'));
    expect(pressed.debugWatchPaintLog, contains(mirror.prepTag));
  });

  test('gate nick and wall nick show on the Watch castle bar, gate above wall',
      () {
    final gateDrop = _nickAndPaint(gate: true);
    final wallDrop = _nickAndPaint(gate: false);
    expect(gateDrop, closeTo(TaisenGame.kSiegeGateNick, 1e-6));
    expect(wallDrop, closeTo(TaisenGame.kSiegeWallNick, 1e-6));
    expect(gateDrop, greaterThan(wallDrop));
  });

  test(
      'own and enemy gauges mirror together, including a pause on only one side',
      () {
    final g = readyGame();
    final ownAt = _ownZone(g, gate: true);
    final enemyAt = _enemyZone(g, gate: false);
    _placeOwn(g, ownAt, TroopType.siege);
    _addBody(g, enemyAt, TroopType.siege, enemy: true);
    g.debugStepPursuit(0.4);
    expect(g.debugWatchSiegeMirrors(), hasLength(2));
    expect(g.debugWatchSiegeMirror(0)!.fill01, g.debugSiegePrep01(0));
    expect(g.debugWatchSiegeMirror(1)!.fill01, g.debugSiegePrep01(1));
    expect(g.debugWatchSiegeMirror(0)!.face, 'gate');
    expect(g.debugWatchSiegeMirror(1)!.face, 'wall');
    expect(g.debugWatchSiegeMirror(0)!.anchor.dy,
        isNot(closeTo(g.debugWatchSiegeMirror(1)!.anchor.dy, 0.5)));

    final ownHeld = g.debugSiegePrep01(0);
    _addBody(g, ownAt, TroopType.infantry, enemy: false);
    g.debugStepPursuit(0.4);
    final own = g.debugWatchSiegeMirror(0)!;
    final enemy = g.debugWatchSiegeMirror(1)!;
    expect(own.pause, 'ally');
    expect(own.fill01, ownHeld);
    expect(enemy.pause, isEmpty);
    expect(enemy.fill01, greaterThan(own.fill01));
    expect(enemy.fill01, g.debugSiegePrep01(1));
    _paintWatch(g);
    expect(g.debugWatchPaintLog, contains(own.prepTag));
    expect(g.debugWatchPaintLog, contains(own.pauseTag));
    expect(g.debugWatchPaintLog, contains(enemy.prepTag));
    expect(g.debugWatchPaintLog, contains(enemy.faceTag));
    expect(g.debugWatchPaintLog.where((t) => t == 'siege-pause:ally'),
        hasLength(1));
  });

  test('a spear keeps its Watch tip plate and grows no siege mirror', () {
    final g = readyGame();
    _placeOwn(g, _ownZone(g, gate: true), TroopType.spear);
    g.debugStepPursuit(0.2);
    expect(g.spearTipExtendedAt(0), isTrue);
    expect(g.debugSiegePrepVisible(0), isFalse);
    expect(g.debugWatchSiegeMirror(0), isNull);
    expect(g.debugWatchDemoPlateSuppressed(0), isFalse);
    _paintWatch(g);
    expect(g.debugWatchPaintLog, contains('demo-intercept'));
    expect(g.debugWatchPaintLog, contains('watch-tip'));
    expect(g.debugWatchPaintLog.where((t) => t.startsWith('siege-')), isEmpty);
  });

  test('a siege that is not the Watch poster still mirrors its field gauge',
      () {
    final g = readyGame();
    _placeOwn(g, Offset(g.size.x * 0.4, g.watchH + g.fieldH * 0.55),
        TroopType.cavalry);
    _addBody(g, _ownZone(g, gate: true), TroopType.siege, enemy: false);
    g.debugStepPursuit(0.4);
    expect(g.watchOwnIndex, 0);
    expect(g.debugWatchDemoPlateSuppressed(0), isFalse);
    expect(g.debugWatchSiegeMirror(0), isNull);
    final siege = g.debugWatchSiegeMirror(1)!;
    expect(siege.fill01, g.debugSiegePrep01(1));
    expect(siege.face, 'gate');
    _paintWatch(g);
    expect(g.debugWatchPaintLog, contains('demo-charge'));
    expect(g.debugWatchPaintLog, contains(siege.prepTag));
    expect(g.debugWatchPaintLog, contains(siege.anchorTag));
  });
}

double _nickAndPaint({required bool gate}) {
  final g = readyGame();
  _placeOwn(g, _ownZone(g, gate: gate), TroopType.siege);
  final before = g.enemyCastle;
  g.debugStepPursuit(1 / TaisenGame.kSiegePrepFillPerSec);
  final mirror = g.debugWatchSiegeMirror(0)!;
  expect(mirror.face, gate ? 'gate' : 'wall');
  expect(g.debugSiegePrepsLanded(0), 1);
  expect(mirror.fill01, 0);
  _paintWatch(g);
  expect(g.debugWatchPaintLog, contains(mirror.faceTag));
  expect(
    g.debugWatchPaintLog,
    contains('castle-enemy:${g.enemyCastle.toStringAsFixed(4)}'),
  );
  expect(before - g.enemyCastle, greaterThan(0));
  return before - g.enemyCastle;
}

void _paintWatch(TaisenGame g) {
  g.debugRecordWatchPaint = true;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  g.render(canvas);
  recorder.endRecording().dispose();
}

Rect _band(TaisenGame g) => Rect.fromLTWH(0, 0, g.size.x, g.watchH);

Offset _ownZone(TaisenGame g, {required bool gate}) {
  final zone = g.enemyCastleZoneRect;
  final x = gate ? zone.center.dx : zone.width * 0.08;
  return Offset(x, zone.top + zone.height * 0.45);
}

Offset _enemyZone(TaisenGame g, {required bool gate}) {
  final zone = g.castleBandRect;
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
