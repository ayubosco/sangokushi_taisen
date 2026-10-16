import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/data/card_models.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';
import 'package:sangokushi_taisen/game/unit_life.dart';

import 'feel_gates_test.dart' show readyGame;

/// Brief 03 — GAP-RET-CASTLE. Living 「歸城」 is not the skull 「返城」.
/// Gate is the existing ~6成 / ~4成 latch. Watch mirrors the live skull.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('H0 chrome and locked revive knobs stay at the Soft Pass values', () {
    final g = readyGame();
    expect(TaisenGame.kWatchFractionOfGame, 0.125);
    expect(g.watchH / g.size.y, closeTo(0.125, 1e-9));
    expect(g.fieldH / g.size.y, closeTo(0.875, 1e-9));
    expect(TaisenGame.kTokenWidthFracOfField, closeTo(0.097, 1e-9));
    expect(TaisenGame.kSoftPinPathPx, 261);
    expect(TaisenGame.kChargeTravelNeed, 120);
    expect(TaisenGame.kCastleBandFracOfField, 0.12);
    expect(TaisenGame.kCastleEnterDepth, 0.60);
    expect(TaisenGame.kCastleExitDepth, 0.40);
    expect(TaisenGame.kReviveBaseSec, 15);
    expect(TaisenGame.kReviveSkillMul, closeTo(2 / 3, 1e-9));
    expect(TaisenGame.kRetreatMoraleCost, 0);
    expect(TaisenGame.kStrategySealPt, 64);
    expect(g.floatingActionHitRect('歸城'), Rect.zero);
    expect(g.floatingActionHitRect('返城'), Rect.zero);
    expect(g.floatingActionHitRect('計略'), Rect.zero);
  });

  test('a living drag into 己城 parks, heals, and flashes 歸城', () {
    final g = readyGame();
    final start = Offset(g.size.x * 0.42, g.watchH + g.fieldH * 0.42);
    _place(g, 'zhaoyun', start);
    g.debugSetUnitHp(0, 40);

    g.panStart(start);
    g.panEnd(_depth(g, 0.72));
    var guard = 0;
    while (g.dragTo != null && guard < 700) {
      g.debugStepPursuit(1 / 60);
      guard++;
    }

    expect(g.fieldInCastle[0], isTrue);
    expect(g.debugUnitLife(0), UnitLife.alive);
    expect(g.debugShowsSkull(0), isFalse);
    expect(g.debugLifeTipAt(0), '返城回血');
    expect(g.debugReturnFlashLabel, '歸城');
    expect(g.debugHitLabel, isNot('撤退'));
    expect(g.debugHitLabel, isNot('復活'));
    expect(g.debugReviveLeft(0), 0);

    final hp = g.debugUnitHp(0);
    g.debugStepPursuit(1);
    expect(g.debugUnitHp(0), closeTo(hp + TaisenGame.kRansenTickPerSec, 0.05));
    expect(g.debugUnitLife(0), UnitLife.alive);
    expect(g.debugWatchReviveMirror(0), isNull);

    _paint(g);
    expect(g.debugWatchPaintLog, contains('watch-guicheng'));
    expect(g.debugWatchPaintLog, isNot(contains('watch-fancheng')));
    expect(g.debugWatchPaintLog, isNot(contains('watch-skull')));
  });

  test('a shallow march stops short of the gate and does not heal', () {
    final g = readyGame();
    final start = Offset(g.size.x * 0.42, g.watchH + g.fieldH * 0.42);
    _place(g, 'zhaoyun', start);
    g.debugSetUnitHp(0, 40);

    g.panStart(start);
    g.panEnd(_depth(g, 0.50));
    var guard = 0;
    while (g.dragTo != null && guard < 700) {
      g.debugStepPursuit(1 / 60);
      guard++;
    }

    expect(g.dragTo, isNull);
    expect(g.fieldInCastle[0], isFalse);
    expect(g.debugUnitLife(0), UnitLife.alive);
    expect(g.debugUnitHp(0), 40);
    expect(g.debugLifeTipAt(0), isNot('返城回血'));
    expect(g.debugReturnFlashLabel, isEmpty);
    expect(g.castleDepth01(g.fieldPos[0]), lessThan(TaisenGame.kCastleEnterDepth));
  });

  test('the gate holds from ~6成 until the body drops under ~4成', () {
    final g = readyGame();
    final outside = Offset(g.size.x * 0.40, g.watchH + g.fieldH * 0.40);
    _place(g, 'zhaoyun', outside);
    g.matchMorale = 5;
    g.debugForceHpZero(0);
    final frozen = g.debugReviveLeft(0);

    g.debugStepPursuit(3);
    expect(g.debugUnitLife(0), UnitLife.retreating);
    expect(g.debugReviveLeft(0), closeTo(frozen, 0.001));
    expect(g.debugLifeTipAt(0), '返城');
    expect(g.matchMorale, 5);

    g.fieldPos[0] = _depth(g, 0.50);
    g.debugStepPursuit(1);
    expect(g.debugUnitLife(0), UnitLife.retreating);
    expect(g.debugReviveLeft(0), closeTo(frozen, 0.001));

    g.fieldPos[0] = _pxFromDepth(g, TaisenGame.kCastleEnterDepth, -1);
    g.debugStepPursuit(1);
    expect(g.debugUnitLife(0), UnitLife.retreating);
    expect(g.debugReviveLeft(0), closeTo(frozen, 0.001));

    g.fieldPos[0] = _pxFromDepth(g, TaisenGame.kCastleEnterDepth, 1);
    g.debugStepPursuit(0.5);
    expect(g.debugUnitLife(0), UnitLife.inCastleReviving);
    final entered = g.debugReviveLeft(0);
    expect(entered, lessThan(frozen - 0.2));
    expect(g.debugLifeTipAt(0), isEmpty);

    g.fieldPos[0] = _depth(g, 0.50);
    g.debugStepPursuit(0.5);
    final held = g.debugReviveLeft(0);
    expect(held, lessThan(entered - 0.2));
    expect(g.debugLifeTipAt(0), isEmpty);

    g.fieldPos[0] = _pxFromDepth(g, TaisenGame.kCastleExitDepth, -1);
    g.debugStepPursuit(1);
    expect(g.debugReviveLeft(0), closeTo(held, 0.001));
    expect(g.debugLifeTipAt(0), '返城');
    expect(g.debugUnitLife(0), UnitLife.inCastleReviving);

    g.fieldPos[0] = _depth(g, 0.41);
    g.debugStepPursuit(1);
    expect(g.debugReviveLeft(0), closeTo(held, 0.001));
    expect(g.debugLifeTipAt(0), '返城');

    g.fieldPos[0] = _pxFromDepth(g, TaisenGame.kCastleEnterDepth, 1);
    g.debugStepPursuit(0.5);
    expect(g.debugReviveLeft(0), lessThan(held - 0.2));
    expect(g.debugLifeTipAt(0), isEmpty);
  });

  test('Watch mirrors the skull outside and the bar inside', () {
    final g = readyGame();
    final outside = Offset(g.size.x * 0.36, g.watchH + g.fieldH * 0.38);
    _place(g, 'zhaoyun', outside);
    g.debugForceHpZero(0);

    final out = g.debugWatchReviveMirror(0)!;
    expect(out.skull, isTrue);
    expect(out.tip, '返城');
    expect(out.bar, isFalse);
    expect(out.anchor, g.mapFieldToWatch(g.watchBodyAt(0), _band(g)));
    _paint(g);
    expect(g.debugWatchPaintLog, contains(out.skullTag));
    expect(g.debugWatchPaintLog, contains(out.tipTag));
    expect(g.debugWatchPaintLog, contains(out.anchorTag));
    expect(g.debugWatchPaintLog, isNot(contains('watch-revive')));
    expect(g.debugWatchPaintLog, isNot(contains('watch-guicheng')));

    g.fieldPos[0] = outside + const Offset(80, 0);
    final moved = g.debugWatchReviveMirror(0)!;
    expect(moved.anchorTag, isNot(out.anchorTag));
    expect(moved.tip, '返城');

    g.fieldPos[0] = _depth(g, 0.72);
    g.debugStepPursuit(0.4);
    final inside = g.debugWatchReviveMirror(0)!;
    expect(g.debugUnitLife(0), UnitLife.inCastleReviving);
    expect(inside.bar, isTrue);
    expect(inside.tip, isEmpty);
    expect(inside.reviveLeft, closeTo(g.debugReviveLeft(0), 1e-9));
    expect(
      inside.barTag,
      'watch-revive:${g.debugReviveLeft(0).toStringAsFixed(2)}',
    );
    expect(inside.anchor, g.mapFieldToWatch(g.watchBodyAt(0), _band(g)));
    _paint(g);
    expect(g.debugWatchPaintLog, contains(inside.skullTag));
    expect(g.debugWatchPaintLog, contains(inside.barTag));
    expect(g.debugWatchPaintLog, contains(inside.anchorTag));
    expect(g.debugWatchPaintLog, isNot(contains('watch-fancheng')));
    expect(g.debugWatchPaintLog, isNot(contains('watch-guicheng')));
  });

  test('an enemy skull is not the own Watch mirror', () {
    final g = readyGame();
    final ownAt = Offset(g.size.x * 0.30, g.watchH + g.fieldH * 0.45);
    _place(g, 'zhaoyun', ownAt);
    final enemy = Cost6Roster.all.firstWhere((c) => c.id == 'caocao');
    g.field.add(enemy);
    g.fieldIsEnemy.add(true);
    g.fieldInCastle.add(false);
    g.fieldPos.add(Offset(g.size.x * 0.70, g.watchH + g.fieldH * 0.30));
    g.debugForceHpZero(1);

    expect(g.debugShowsSkull(1), isTrue);
    expect(g.debugWatchReviveMirror(1), isNull);
    expect(g.debugWatchReviveMirror(0), isNull);
    _paint(g);
    expect(g.debugWatchPaintLog, isNot(contains('watch-fancheng')));
    expect(g.debugWatchPaintLog, isNot(contains('watch-skull')));
  });

  test('drop glow follows a living pin and a skull outside; the field stays cold', () {
    final living = readyGame();
    final start = Offset(living.size.x * 0.40, living.watchH + living.fieldH * 0.40);
    _place(living, 'zhaoyun', start);
    living.debugStepPursuit(0.2);
    expect(living.castleBandHot, isFalse);

    living.panStart(start);
    living.panUpdate(_depth(living, 0.72));
    expect(living.dragging, isTrue);
    expect(living.castleBandHot, isTrue);
    expect(living.fieldInCastle[0], isFalse);
    expect(living.fieldPos[0].dy, closeTo(start.dy, 1));

    final skull = readyGame();
    _place(skull, 'zhaoyun', start);
    skull.debugForceHpZero(0);
    expect(skull.castleBandHot, isFalse);
    skull.debugStepPursuit(0.2);
    expect(skull.debugLifeTipAt(0), '返城');
    expect(skull.castleBandHot, isTrue);
    expect(skull.fieldInCastle[0], isFalse);
  });

  test('finger-down over 己城 does not park the skull', () {
    final g = readyGame();
    final start = Offset(g.size.x * 0.40, g.watchH + g.fieldH * 0.40);
    _place(g, 'zhaoyun', start);
    g.debugForceHpZero(0);
    final frozen = g.debugReviveLeft(0);

    g.panStart(start);
    g.panUpdate(_depth(g, 0.72));
    g.debugStepPursuit(1 / 60);

    expect(g.dragging, isTrue);
    expect(g.fieldInCastle[0], isFalse);
    expect(g.debugUnitLife(0), UnitLife.retreating);
    expect(g.debugReviveLeft(0), closeTo(frozen, 0.001));
    expect(g.debugLifeTipAt(0), '返城');
  });
}

Offset _depth(TaisenGame g, double depth) {
  final band = g.castleBandRect;
  return Offset(band.center.dx, band.top + band.height * depth);
}

Offset _pxFromDepth(TaisenGame g, double depth, int px) {
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

void _place(TaisenGame g, String id, Offset at) {
  final card = Cost6Roster.all.firstWhere((c) => c.id == id);
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
  g.dragTo = null;
  g.dragging = false;
}
