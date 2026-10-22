import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/data/card_models.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';

import 'feel_gates_test.dart' show readyGame;

/// AUTH-GAP SGE-01..04 (checklist §6). Existence + interrupt rules only.
/// Soft Pass ≠ Feel. No Official rate, DPS, or gate mul is asserted here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SGE-01 entering the zone paints a yellow gauge on the sieging body', () {
    final g = readyGame();
    final at = _inEnemyZone(g);
    _placeOwn(g, at);
    final castle = g.enemyCastle;
    g.debugStepPursuit(0);
    final tags = _renderSiegeTags(g);
    expect(tags, contains('field-prep:0:0.0000'));
    expect(tags.where((t) => t.startsWith('field-pause:')), isEmpty);
    expect(g.debugSiegeCaption(0), TaisenGame.kSiegingCaption);
    expect(TaisenGame.kSiegePrepYellow, const Color(0xFFFFD54F));
    expect(g.enemyCastle, castle, reason: 'entering is a gauge, not an instant chip');
  });

  test('SGE-01 a body outside the zone paints no gauge', () {
    final g = readyGame();
    _placeOwn(g, Offset(g.size.x / 2, g.watchH + g.fieldH * 0.5));
    g.debugStepPursuit(0.4);
    expect(g.debugSiegePrepVisible(0), isFalse);
    expect(_renderSiegeTags(g), isEmpty);
  });

  test('SGE-02 a body moved without the finger holds the fill', () {
    final g = readyGame();
    final at = _inEnemyZone(g);
    _placeOwn(g, at);
    g.selectedIndex = null;
    g.debugStepPursuit(0.4);
    final held = g.debugSiegePrep01(0);
    expect(held, greaterThan(0));

    // Not selected, no drag, no pin: only the body shifted between ticks.
    g.fieldPos[0] = at + const Offset(14, 0);
    expect(g.inEnemyCastleZone(0), isTrue);
    g.debugStepPursuit(0.4);
    expect(g.debugSiegePrepPause(0), 'move');
    expect(g.debugSiegePrep01(0), held);

    // Standing on the new point resumes the fill.
    g.debugStepPursuit(0.4);
    expect(g.debugSiegePrepPause(0), isEmpty);
    expect(g.debugSiegePrep01(0), greaterThan(held));
  });

  test('SGE-02 an enemy sieger walking in its zone does not fill', () {
    final g = readyGame();
    final band = g.castleBandRect;
    final at = Offset(band.center.dx, band.top + band.height * 0.4);
    _placeOwn(g, Offset(g.size.x / 2, g.watchH + g.fieldH * 0.5));
    _addBody(g, at, TroopType.siege, enemy: true);
    const e = 1;
    expect(g.inEnemyCastleZone(e), isTrue);
    g.debugStepPursuit(0.4);
    final held = g.debugSiegePrep01(e);
    expect(held, greaterThan(0));
    final own = g.ownCastle;

    for (var k = 1; k <= 4; k++) {
      g.fieldPos[e] = at + Offset(6.0 * k, 0);
      g.debugStepPursuit(0.4);
      expect(g.debugSiegePrepPause(e), 'move');
    }
    expect(g.debugSiegePrep01(e), held);
    expect(g.debugSiegePrepsLanded(e), 0);
    expect(g.ownCastle, own);
  });

  test('SGE-02 亂戰 holds the fill while the gauge stays up', () {
    final g = readyGame();
    final at = _inEnemyZone(g);
    _placeOwn(g, at);
    g.debugStepPursuit(0.4);
    final held = g.debugSiegePrep01(0);
    _addBody(g, at, TroopType.infantry, enemy: true);
    g.debugStepPursuit(0.4);
    expect(g.debugInRansen(0), isTrue);
    expect(g.debugSiegePrepPause(0), 'ransen');
    expect(g.debugSiegePrep01(0), held);
    expect(_renderSiegeTags(g), contains('field-pause:0:ransen'));
  });

  test('SGE-03 leaving the zone takes the gauge off the map', () {
    final g = readyGame();
    final at = _inEnemyZone(g);
    _placeOwn(g, at);
    g.debugStepPursuit(0.4);
    expect(g.debugSiegePrep01(0), greaterThan(0));

    g.fieldPos[0] = Offset(at.dx, g.watchH + g.fieldH * 0.5);
    g.debugStepPursuit(0.2);
    expect(g.debugSiegePrepVisible(0), isFalse);
    expect(g.debugSiegePrep01(0), 0);
    expect(g.debugSiegeCaption(0), isEmpty);
    expect(g.debugSiegeCountdownSec(0), 0);
    expect(_renderSiegeTags(g), isEmpty);
  });

  test('SGE-03 a body that retreats drops its gauge', () {
    final g = readyGame();
    final at = _inEnemyZone(g);
    _placeOwn(g, at);
    g.debugStepPursuit(0.4);
    expect(g.debugSiegePrep01(0), greaterThan(0));
    g.debugForceHpZero(0);
    g.debugStepPursuit(0.1);
    expect(g.debugSiegePrepVisible(0), isFalse);
    expect(g.debugSiegePrep01(0), 0);
  });

  test('SGE-04 ally bump pauses the fill and the field gauge reads held', () {
    final g = readyGame();
    final at = _inEnemyZone(g);
    _placeOwn(g, at);
    g.debugStepPursuit(0.4);
    final held = g.debugSiegePrep01(0);
    _addBody(g, at + const Offset(10, 0), TroopType.infantry, enemy: false);
    g.debugStepPursuit(0.4);
    expect(g.debugInRansen(0), isFalse);
    expect(g.debugSiegePrepPause(0), 'ally');
    expect(g.debugSiegePrep01(0), held);
    final tags = _renderSiegeTags(g);
    expect(tags, contains('field-pause:0:ally'));
    expect(tags, contains('field-prep:0:${held.toStringAsFixed(4)}'));

    // Ally steps clear: the bump is over and the fill resumes from where it held.
    g.fieldPos[1] = Offset(at.dx, g.watchH + g.fieldH * 0.6);
    g.debugStepPursuit(0.4);
    expect(g.debugSiegePrepPause(0), isEmpty);
    expect(g.debugSiegePrep01(0), greaterThan(held));
    expect(
      _renderSiegeTags(g).where((t) => t.startsWith('field-pause:')),
      isEmpty,
    );
  });

  test('SGE-04 a held countdown does not tick down', () {
    final g = readyGame();
    final at = _inEnemyZone(g);
    _placeOwn(g, at);
    g.debugStepPursuit(0.4);
    _addBody(g, at + const Offset(10, 0), TroopType.infantry, enemy: false);
    g.debugStepPursuit(0.1);
    final sec = g.debugSiegeCountdownSec(0);
    for (var k = 0; k < 10; k++) {
      g.debugStepPursuit(0.5);
    }
    expect(g.debugSiegeCountdownSec(0), sec);
    expect(g.debugSiegePrepsLanded(0), 0);
  });
}

List<String> _renderSiegeTags(TaisenGame g) {
  g.debugRecordSiegePaint = true;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  g.render(canvas);
  recorder.endRecording();
  return g.debugSiegePaintLog;
}

Offset _inEnemyZone(TaisenGame g) {
  final zone = g.enemyCastleZoneRect;
  return Offset(zone.center.dx, zone.top + zone.height * 0.45);
}

void _placeOwn(TaisenGame g, Offset at) {
  final card = Cost6Roster.all.firstWhere((c) => c.troop == TroopType.siege);
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
