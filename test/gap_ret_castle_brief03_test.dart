import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/data/card_models.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';
import 'package:sangokushi_taisen/game/unit_life.dart';

import 'feel_gates_test.dart' show readyGame;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Brief 03 locks stay the existing gate, revive, and empty 歸城 button', () {
    final g = readyGame();
    expect(TaisenGame.kCastleBandFracOfField, 0.12);
    expect(TaisenGame.kCastleEnterDepth, 0.60);
    expect(TaisenGame.kCastleExitDepth, 0.40);
    expect(TaisenGame.kRetreatMoraleCost, 0);
    expect(TaisenGame.kReviveBaseSec, 15);
    expect(TaisenGame.kReviveSkillMul, closeTo(2 / 3, 1e-9));
    expect(g.floatingActionHitRect('歸城'), Rect.zero);
    expect(g.floatingActionHitRect('返城'), Rect.zero);
    expect(g.debugReturnFlashLabel, isEmpty);
  });

  test('living march into the gate heals and flashes 歸城, not a skull', () {
    final g = readyGame();
    final start = Offset(g.size.x * 0.42, g.watchH + g.fieldH * 0.40);
    _placeOwn(g, start, hp: 40);
    final band = g.castleBandRect;
    final deep = Offset(band.center.dx, band.top + band.height * 0.72);
    g.panStart(start);
    g.panEnd(deep);

    var frames = 0;
    while (!g.fieldInCastle[0] && frames < 500) {
      g.debugStepPursuit(1 / 60);
      frames++;
    }
    expect(g.fieldInCastle[0], isTrue, reason: 'release inside the gate parks');
    expect(g.debugUnitLife(0), UnitLife.alive);
    expect(g.debugShowsSkull(0), isFalse);
    expect(g.debugLifeTipAt(0), '返城回血');
    expect(g.debugReturnFlashLabel, '歸城');
    expect(g.debugHitLabel, isNot('復活'));
    expect(g.debugHitLabel, isNot('撤退'));
    expect(g.debugReviveLeft(0), 0);

    final hp = g.debugUnitHp(0);
    g.debugStepPursuit(1);
    expect(
      g.debugUnitHp(0),
      closeTo(hp + TaisenGame.kRansenTickPerSec, 0.05),
      reason: 'readable heal stays the existing playtest stub',
    );
    expect(g.debugUnitLife(0), UnitLife.alive);
    expect(g.debugShowsSkull(0), isFalse);
  });

  test('a drag that stops short of 6成 does not park or heal', () {
    final g = readyGame();
    final start = Offset(g.size.x * 0.42, g.watchH + g.fieldH * 0.40);
    _placeOwn(g, start, hp: 40);
    final shallow = _depthPoint(g, 0.50);
    g.panStart(start);
    g.panEnd(shallow);
    var frames = 0;
    while (g.dragTo != null && frames < 500) {
      g.debugStepPursuit(1 / 60);
      frames++;
    }
    expect(g.dragTo, isNull);
    expect(g.fieldInCastle[0], isFalse);
    expect(g.debugUnitLife(0), UnitLife.alive);
    expect(g.debugShowsSkull(0), isFalse);
    expect(g.debugUnitHp(0), 40);
    expect(g.debugLifeTipAt(0), isEmpty);
    expect(g.debugReturnFlashLabel, isEmpty);
    expect(g.castleDepth01(g.fieldPos[0]), lessThan(TaisenGame.kCastleEnterDepth));
  });

  test('castle gate is 6成 in and 4成 out, one pixel either side', () {
    final g = readyGame();
    final outside = Offset(g.size.x * 0.40, g.watchH + g.fieldH * 0.42);
    _placeOwn(g, outside);
    g.matchMorale = 5;
    g.debugForceHpZero(0);
    expect(g.debugLifeTipAt(0), '返城');
    expect(g.matchMorale, 5);

    g.fieldPos[0] = _depthPoint(g, TaisenGame.kCastleEnterDepth, px: -1);
    g.debugStepPursuit(0.4);
    expect(g.debugUnitLife(0), UnitLife.retreating);
    expect(g.debugReviveLeft(0), closeTo(15, 0.001));
    expect(g.debugLifeTipAt(0), '返城');

    g.fieldPos[0] = _depthPoint(g, TaisenGame.kCastleEnterDepth, px: 1);
    g.debugStepPursuit(0.4);
    expect(g.debugUnitLife(0), UnitLife.inCastleReviving);
    expect(g.debugReviveLeft(0), closeTo(14.6, 0.05));
    expect(g.debugLifeTipAt(0), isEmpty);

    var left = g.debugReviveLeft(0);
    g.fieldPos[0] = _depthPoint(g, 0.50);
    g.debugStepPursuit(0.4);
    expect(g.debugUnitLife(0), UnitLife.inCastleReviving);
    expect(g.debugReviveLeft(0), closeTo(left - 0.4, 0.05));
    expect(g.debugLifeTipAt(0), isEmpty);

    left = g.debugReviveLeft(0);
    g.fieldPos[0] = _depthPoint(g, TaisenGame.kCastleExitDepth, px: 1);
    g.debugStepPursuit(0.2);
    expect(g.debugReviveLeft(0), closeTo(left - 0.2, 0.05));
    expect(g.debugLifeTipAt(0), isEmpty);

    left = g.debugReviveLeft(0);
    g.fieldPos[0] = _depthPoint(g, TaisenGame.kCastleExitDepth, px: -1);
    g.debugStepPursuit(0.5);
    expect(g.debugReviveLeft(0), closeTo(left, 0.001));
    expect(g.debugLifeTipAt(0), '返城');
    expect(g.debugUnitLife(0), UnitLife.inCastleReviving);

    g.fieldPos[0] = _depthPoint(g, 0.50);
    g.debugStepPursuit(0.4);
    expect(g.debugReviveLeft(0), closeTo(left, 0.001));
    expect(g.debugLifeTipAt(0), '返城');

    g.fieldPos[0] = _depthPoint(g, TaisenGame.kCastleEnterDepth, px: 1);
    g.debugStepPursuit(0.3);
    expect(g.debugReviveLeft(0), closeTo(left - 0.3, 0.05));
    expect(g.debugLifeTipAt(0), isEmpty);
    expect(g.debugShowsSkull(0), isTrue);
  });

  test('Watch mirrors skull, 返城, and the in-castle bar on the same countdown', () {
    final g = readyGame();
    final outside = Offset(g.size.x * 0.36, g.watchH + g.fieldH * 0.40);
    _placeOwn(g, outside);
    g.debugForceHpZero(0);
    final frozen = g.debugReviveLeft(0);
    g.debugStepPursuit(0.5);
    expect(g.debugReviveLeft(0), frozen);

    final outsideMirror = g.debugWatchReviveMirror(0)!;
    expect(outsideMirror.skull, isTrue);
    expect(outsideMirror.tip, '返城');
    expect(outsideMirror.bar, isFalse);
    expect(outsideMirror.reviveLeft, frozen);
    _paint(g);
    expect(g.debugWatchPaintLog, contains(outsideMirror.skullTag));
    expect(g.debugWatchPaintLog, contains(outsideMirror.tipTag));
    expect(g.debugWatchPaintLog, contains(outsideMirror.anchorTag));
    expect(g.debugWatchPaintLog.where((t) => t.startsWith('watch-revive:')), isEmpty);

    final moved = Offset(outside.dx + 28, outside.dy);
    g.fieldPos[0] = moved;
    final movedMirror = g.debugWatchReviveMirror(0)!;
    expect(movedMirror.anchor.dx, isNot(closeTo(outsideMirror.anchor.dx, 0.5)));
    expect(movedMirror.reviveLeft, frozen);
    _paint(g);
    expect(g.debugWatchPaintLog, contains(movedMirror.anchorTag));
    expect(g.debugWatchPaintLog, contains(movedMirror.tipTag));

    g.fieldPos[0] = _depthPoint(g, 0.72);
    g.debugStepPursuit(0.25);
    final inside = g.debugWatchReviveMirror(0)!;
    expect(g.debugUnitLife(0), UnitLife.inCastleReviving);
    expect(inside.bar, isTrue);
    expect(inside.tip, isEmpty);
    expect(inside.reviveLeft, closeTo(g.debugReviveLeft(0), 1e-9));
    expect(inside.barTag, 'watch-revive:${g.debugReviveLeft(0).toStringAsFixed(2)}');
    expect(inside.anchor, g.mapFieldToWatch(g.watchBodyAt(0), _band(g)));
    _paint(g);
    expect(g.debugWatchPaintLog, contains(inside.skullTag));
    expect(g.debugWatchPaintLog, contains(inside.barTag));
    expect(g.debugWatchPaintLog.where((t) => t.startsWith('watch-fancheng')), isEmpty);

    final held = g.debugReviveLeft(0);
    g.fieldPos[0] = outside;
    g.debugStepPursuit(0.4);
    expect(g.debugReviveLeft(0), closeTo(held, 0.001));
    final back = g.debugWatchReviveMirror(0)!;
    expect(back.bar, isFalse);
    expect(back.tip, '返城');
    expect(back.reviveLeft, closeTo(held, 1e-9));
    _paint(g);
    expect(g.debugWatchPaintLog, contains(back.tipTag));
    expect(g.debugWatchPaintLog.where((t) => t.startsWith('watch-revive:')), isEmpty);

    final enemy = Cost6Roster.all.firstWhere((c) => c.id == 'caocao');
    g.field.add(enemy);
    g.fieldIsEnemy.add(true);
    g.fieldInCastle.add(false);
    g.fieldPos.add(Offset(g.size.x * 0.7, g.watchH + g.fieldH * 0.3));
    g.debugForceHpZero(1);
    expect(g.debugWatchReviveMirror(1), isNull);
    expect(g.debugLifeTipAt(1), isEmpty);
    _paint(g);
    expect(g.debugWatchPaintLog.where((t) => t.endsWith(':1')), isEmpty);
  });

  test('living heal on Watch is 歸城, not the skull 返城 plate', () {
    final g = readyGame();
    final band = g.castleBandRect;
    final at = Offset(band.center.dx, band.top + band.height * 0.72);
    _placeOwn(g, at, hp: 40);
    g.panStart(at);
    g.panEnd(at);
    expect(g.fieldInCastle[0], isTrue);
    expect(g.debugUnitLife(0), UnitLife.alive);
    expect(g.debugReturnFlashLabel, '歸城');
    expect(g.debugWatchReviveMirror(0), isNull);
    _paint(g);
    expect(g.debugWatchPaintLog, contains('watch-guicheng'));
    expect(g.debugWatchPaintLog.where((t) => t.startsWith('watch-fancheng')), isEmpty);
    expect(g.debugWatchPaintLog.where((t) => t.startsWith('watch-skull')), isEmpty);
  });

  test('selected skull outside lights the band; a living finger in the band does too', () {
    final skull = readyGame();
    final at = Offset(skull.size.x * 0.4, skull.watchH + skull.fieldH * 0.4);
    _placeOwn(skull, at);
    skull.debugForceHpZero(0);
    skull.castleBandHot = false;
    skull.selectedIndex = 0;
    skull.debugStepPursuit(0);
    expect(skull.debugLifeTipAt(0), '返城');
    expect(skull.castleBandHot, isTrue);

    final living = readyGame();
    final sit = Offset(living.size.x * 0.4, living.watchH + living.fieldH * 0.4);
    _placeOwn(living, sit, hp: 80);
    living.castleBandHot = false;
    living.selectedIndex = 0;
    living.debugStepPursuit(0);
    expect(living.castleBandHot, isFalse);
    expect(living.debugLifeTipAt(0), isEmpty);

    final band = living.castleBandRect;
    living.panStart(sit);
    living.panUpdate(Offset(band.center.dx, band.center.dy));
    expect(living.dragging, isTrue);
    expect(living.fieldInCastle[0], isFalse);
    expect(living.castleBandHot, isTrue);
    expect(living.castleDepth01(living.fieldPos[0]), lessThan(TaisenGame.kCastleEnterDepth));
  });
}

void _placeOwn(TaisenGame g, Offset at, {double? hp}) {
  final card = Cost6Roster.all.firstWhere((c) => c.id == 'zhaoyun');
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
  if (hp != null) g.debugSetUnitHp(0, hp);
}

Offset _depthPoint(TaisenGame g, double depth, {double px = 0}) {
  final band = g.castleBandRect;
  return Offset(band.center.dx, band.top + band.height * depth + px);
}

Rect _band(TaisenGame g) => Rect.fromLTWH(0, 0, g.size.x, g.watchH);

void _paint(TaisenGame g) {
  g.debugRecordWatchPaint = true;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  g.render(canvas);
  recorder.endRecording().dispose();
}
