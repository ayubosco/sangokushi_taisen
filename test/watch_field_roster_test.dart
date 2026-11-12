import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';
import 'package:sangokushi_taisen/game/unit_life.dart';
import 'package:sangokushi_taisen/game/watch_field_roster.dart';

import 'feel_gates_test.dart' show readyGame;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Watch chrome stays put while it shows the whole field', () {
    final g = readyGame();
    expect(TaisenGame.kWatchFractionOfGame, 0.125);
    expect(g.watchH / g.size.y, closeTo(0.125, 1e-9));
  });

  test('every body of both sides is on the Watch at its field position', () {
    final g = readyGame()..setupMatchDemoField();
    final roster = g.debugWatchRoster();
    final band = _band(g);

    expect(roster.length, g.field.length);
    expect(roster.where((u) => !u.enemy).length, 3);
    expect(roster.where((u) => u.enemy).length, 2);
    for (final u in roster) {
      expect(u.enemy, g.isEnemyAt(u.index));
      expect(u.troop, g.field[u.index].troop);
      expect(u.anchor, g.mapFieldToWatch(g.fieldPos[u.index], band));
      expect(band.contains(u.anchor), isTrue);
      expect(u.down, isFalse);
      expect(u.hp01, 1.0);
    }

    _paintWatch(g);
    for (final u in roster) {
      expect(g.debugWatchPaintLog, contains(u.unitTag));
      expect(g.debugWatchPaintLog, contains(u.anchorTag));
    }
    expect(g.debugWatchPaintLog, contains('watch-tally:3/3:2/2'));
  });

  test('a body that moves on the field moves on the Watch the same frame', () {
    final g = readyGame()..setupMatchDemoField();
    final before = g.debugWatchRoster()[4].anchor;
    g.fieldPos[4] = g.fieldPos[4] + const Offset(60, 120);
    final after = g.debugWatchRoster()[4].anchor;

    expect(after, isNot(before));
    expect(after, g.mapFieldToWatch(g.fieldPos[4], _band(g)));
  });

  test('HP and retreat read from the field, and the headcount follows', () {
    final g = readyGame()..setupMatchDemoField();
    g.debugSetUnitHp(1, TaisenGame.kRansenMaxHp * 0.25);
    g.debugForceHpZero(3);

    final roster = g.debugWatchRoster();
    expect(roster[1].hp01, closeTo(0.25, 1e-9));
    expect(roster[1].down, isFalse);
    expect(g.debugUnitLife(3), UnitLife.retreating);
    expect(roster[3].down, isTrue);
    expect(roster[3].hp01, 0.0);

    final tally = WatchFieldTally.of(roster);
    expect(tally.ownUp, 3);
    expect(tally.enemyUp, 1);
    expect(tally.label, '己 3／3　敵 1／2');

    _paintWatch(g);
    expect(g.debugWatchPaintLog, contains(roster[3].downTag));
    expect(g.debugWatchPaintLog, isNot(contains(roster[1].downTag)));
    expect(g.debugWatchPaintLog, contains('watch-tally:3/3:1/2'));
  });

  test('far bodies read smaller than near bodies of the same side', () {
    final g = readyGame()..setupMatchDemoField();
    g.fieldPos[1] = Offset(g.fieldPos[1].dx, g.watchH + g.fieldH * 0.15);
    final roster = g.debugWatchRoster();

    expect(roster[1].depth01, greaterThan(roster[2].depth01));
    expect(roster[1].scale, lessThan(roster[2].scale));
  });
}

void _paintWatch(TaisenGame g) {
  g.debugRecordWatchPaint = true;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  g.render(canvas);
  recorder.endRecording().dispose();
}

Rect _band(TaisenGame g) => Rect.fromLTWH(0, 0, g.size.x, g.watchH);
