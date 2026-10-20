import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/data/card_models.dart';
import 'package:sangokushi_taisen/game/faction_colors.dart';
import 'package:sangokushi_taisen/game/fx_windows.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';

import 'feel_gates_test.dart' show readyGame;

/// LOOKALIKE deepen (LK-01..LK-05). Soft Pass punch 0 stays Soft Pass.
/// Headless stills land in [kStillDir] for UIUX re-Gate. Not a Feel pass.
const kStillDir = 'artifacts/lookalike-lk-2026-10-20';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('W1–W5 Watch mirrors idle, gold, and scrape at fraction 0.125', () {
    final g = readyGame();
    expect(TaisenGame.kWatchFractionOfGame, 0.125);
    expect(g.watchH / g.size.y, closeTo(0.125, 1e-9));

    final at = _fieldAt(g, 0.40, 0.50);
    _placeOwn(g, at, TroopType.spear);
    g.ownFacing = 0;
    expect(g.spearTipExtendedAt(0), isTrue);
    expect(g.watchTipMirrorAt(0), WatchTipMirror.idle);
    _paint(g);
    expect(g.debugWatchPaintLog, contains('watch-tip'));
    expect(g.debugWatchPaintLog, contains('watch-tip-idle'));
    expect(g.debugWatchPaintLog, isNot(contains('watch-tip-gold')));

    _turn(g, at, const Offset(80, 0));
    expect(g.spearQiangjiGoldAt(0), isTrue);
    expect(g.watchTipMirrorAt(0), WatchTipMirror.gold);
    _paint(g);
    expect(g.debugWatchPaintLog, contains('watch-tip-gold'));
    expect(g.debugWatchPaintLog, contains('watch-tip'));

    _addCavalry(g, g.spearTipAt(0));
    g.enemyFacing = 0;
    g.debugArmEnemyChargeAura();
    g.debugStepPursuit(1 / 60);
    expect(g.debugHitLabel, '迎擊');
    expect(g.spearQiangjiGoldAt(0), isFalse);
    expect(g.watchTipMirrorAt(0), WatchTipMirror.scrape);
    expect(g.debugHitFlashLeft, greaterThan(0));
    expect(
      g.debugHitFlashLeft,
      lessThanOrEqualTo(FxWindows.toSeconds(FxWindows.interceptHitFlashC) + 1e-9),
    );
    expect(g.debugHitLabel, isNot('3450'));
    _paint(g);
    expect(g.debugWatchPaintLog, contains('watch-tip-scrape'));
    expect(g.debugWatchPaintLog, contains('watch-geigeki'));
    expect(g.debugWatchPaintLog, isNot(contains('watch-tip-gold')));
    expect(g.watchH / g.size.y, closeTo(0.125, 1e-9));
  });

  test('T1–T6 tip scrape is not body 乱戦, and gold follows the turn', () {
    final tip = readyGame();
    final at = _fieldAt(tip, 0.42, 0.50);
    _placeOwn(tip, at, TroopType.spear);
    tip.ownFacing = 0;
    _turn(tip, at, const Offset(0, 70));
    expect(tip.spearQiangjiGoldAt(0), isTrue);
    _addCavalry(tip, tip.spearTipAt(0));
    tip.enemyFacing = 0;
    tip.debugArmEnemyChargeAura();
    tip.debugStepPursuit(1 / 60);
    expect(tip.debugHitLabel, '迎擊');
    expect(tip.debugTipScrapeArmed, isTrue);
    expect(tip.spearQiangjiGoldAt(0), isFalse);
    expect(tip.spearTipExtendedAt(0), isTrue);
    expect(tip.debugInRansen(0), isFalse);
    expect(tip.debugUnitHp(1), isNot(3450));

    final mash = readyGame();
    final body = _fieldAt(mash, 0.42, 0.50);
    _placeOwn(mash, body, TroopType.spear);
    mash.ownFacing = 0;
    _turn(mash, body, const Offset(70, 0));
    expect(mash.spearQiangjiGoldAt(0), isTrue);
    _addCavalry(mash, body);
    mash.debugStepPursuit(1 / 60);
    expect(mash.debugInRansen(0), isTrue);
    expect(mash.debugHitLabel, isNot('迎擊'));
    expect(mash.spearTipExtendedAt(0), isFalse);
    expect(mash.watchTipMirrorAt(0), WatchTipMirror.clear);
    expect(mash.spearQiangjiGoldAt(0), isFalse);
    _paint(mash);
    expect(mash.debugWatchPaintLog, contains('watch-tip-clear'));
    expect(mash.debugWatchPaintLog, isNot(contains('watch-tip')));
    expect(mash.debugHitLabel, isNot('3450'));

    final same = readyGame();
    final spot = _fieldAt(same, 0.36, 0.55);
    _placeOwn(same, spot, TroopType.spear);
    same.debugLockCardFacing(0, math.pi);
    same.selectedIndex = 0;
    same.panStart(spot);
    same.panEnd(spot + const Offset(0, 70));
    same.dragTo = null;
    expect(same.spearQiangjiArmedAt(0), isFalse);
    expect(same.watchTipMirrorAt(0), WatchTipMirror.idle);
    expect(TaisenGame.kSpearTipReach, closeTo(48 * 1.28, 0.001));
  });

  test('K1–K3 spend, range clear, and no 6/2 or fullscreen', () {
    final g = readyGame();
    g.setupSession2Field();
    final before = g.matchMorale;
    final cost = g.field[0].strategyMorale;
    expect(before, greaterThan(cost));
    expect(g.strategyPreviewVisible, isTrue);
    expect(g.strategyPreviewCaption, isNot(contains('6vs2')));
    expect(g.strategyCastBlocksField, isFalse);
    final inside = g.strategyPreviewCenter! + Offset(g.strategyPreviewRadius * 0.3, 0);
    expect(g.castStrategyOnMap(inside), isTrue);
    expect(g.matchMorale, before - cost);
    expect(g.strategyPreviewVisible, isFalse);
    expect(g.debugStrategyBeamFrom, isNotNull);
    expect(g.debugStrategyBeamTo, isNotNull);
    g.cancelStrategyPreview();
    expect(g.strategyPreviewVisible, isFalse);
    expect(g.matchMorale, before - cost);
    // K4 Soft note: headless pt size only. Not a device millimetre pass.
    expect(TaisenGame.kStrategySealPt, 64);
    expect(TaisenGame.kStrategySealCenter, const Offset(350, 814));
    expect(TaisenGame.kSoftPassFrameW, 402);
    expect(TaisenGame.kSoftPassFrameH, 874);
  });

  testWidgets('headless stills for W/T/K re-Gate', (tester) async {
    await tester.runAsync(() async {
      final dir = Directory(kStillDir);
      await dir.create(recursive: true);

      final idle = readyGame();
      final at = _fieldAt(idle, 0.40, 0.52);
      _placeOwn(idle, at, TroopType.spear);
      idle.ownFacing = 0;
      await _shoot(idle, 'w1-watch-idle.png');

      _turn(idle, at, const Offset(90, 0));
      expect(idle.watchTipMirrorAt(0), WatchTipMirror.gold);
      await _shoot(idle, 'w2-watch-gold.png');
      await _shoot(idle, 't4-direction-arms-gold.png');

      final whiff = readyGame();
      final wAt = _fieldAt(whiff, 0.36, 0.48);
      _placeOwn(whiff, wAt, TroopType.spear);
      whiff.ownFacing = 0;
      _turn(whiff, wAt, const Offset(90, 0));
      final body = whiff.tokenCenter(0);
      final tip = whiff.spearTipAt(0);
      final along = tip - body;
      final unit = along / along.distance;
      final side = Offset(-unit.dy, unit.dx);
      final gap = math.max(TaisenGame.kSpearTipHitR, whiff.meleeContactDist) + 40;
      final end = tip + unit * 70 + side * gap;
      _addCavalry(whiff, end);
      whiff.fieldPos[1] = end;
      whiff.debugStepPursuit(1 / 60);
      expect(whiff.spearQiangjiGoldAt(0), isTrue);
      expect(whiff.debugHitLabel, isNot('迎擊'));
      expect(whiff.watchTipMirrorAt(0), WatchTipMirror.gold);
      await _shoot(whiff, 't5-whiff-gold.png');

      final cast = readyGame();
      cast.setupSession2Field();
      final before = cast.matchMorale;
      final center = cast.strategyPreviewCenter!;
      expect(cast.castStrategyOnMap(center), isTrue);
      expect(cast.matchMorale, lessThan(before));
      expect(cast.strategyPreviewVisible, isFalse);
      await _shoot(cast, 'k2-beam-after-spend.png');

      final hit = readyGame();
      final hAt = _fieldAt(hit, 0.42, 0.50);
      _placeOwn(hit, hAt, TroopType.spear);
      hit.ownFacing = 0;
      _turn(hit, hAt, const Offset(0, 72));
      _addCavalry(hit, hit.spearTipAt(0));
      hit.enemyFacing = 0;
      hit.debugArmEnemyChargeAura();
      hit.debugStepPursuit(1 / 60);
      expect(hit.watchTipMirrorAt(0), WatchTipMirror.scrape);
      await _armReadability(hit);
      await _shoot(hit, 'w3-watch-scrape.png');
      await _shoot(hit, 't1-tip-geigeki.png');

      final mash = readyGame();
      final mAt = _fieldAt(mash, 0.42, 0.50);
      _placeOwn(mash, mAt, TroopType.spear);
      mash.ownFacing = 0;
      _turn(mash, mAt, const Offset(70, 0));
      _addCavalry(mash, mAt);
      mash.debugStepPursuit(1 / 60);
      expect(mash.watchTipMirrorAt(0), WatchTipMirror.clear);
      expect(mash.debugHitLabel, isNot('迎擊'));
      await _armReadability(mash);
      await _shoot(mash, 't2-body-ransen.png');
      await _shootPair(hit, mash, 't1-t2-scrape-vs-mash.png');

      await _armReadability(hit);
      final beat = _beatGame();
      final readyPool = beat.matchMorale;
      beat.selectedIndex = null;
      beat.cancelStrategyPreview();
      expect(beat.strategyPreviewVisible, isFalse);
      expect(beat.selectedIndex, isNull);
      await _shootBeat(beat, 'b1-seal-ready.png');

      final card = beat.tokenCenter(1);
      beat.selectedIndex = 1;
      beat.cancelStrategyPreview();
      beat.dragging = true;
      beat.dragFrom = card;
      beat.dragTo = card + const Offset(0, -36);
      expect(beat.pinnedMarchAt(1), isTrue);
      expect(beat.strategyPreviewVisible, isFalse);
      expect(beat.matchMorale, readyPool);
      await _shootBeat(beat, 'b2-card-lift.png');

      beat.dragging = false;
      beat.dragTo = null;
      beat.selectOrDetailAt(beat.tokenCenter(1));
      expect(beat.strategyPreviewVisible, isTrue);
      expect(beat.strategyPreviewCaption, isNot(contains('6vs2')));
      expect(beat.strategyPreviewCaption, isNot(contains('6/2')));
      expect(beat.matchMorale, readyPool);
      await _shootBeat(beat, 'b3-range-on.png');

      final cancel = _beatGame();
      cancel.selectOrDetailAt(cancel.tokenCenter(1));
      final cancelPool = cancel.matchMorale;
      expect(cancel.strategyPreviewVisible, isTrue);
      cancel.cancelStrategyPreview();
      expect(cancel.strategyPreviewVisible, isFalse);
      expect(cancel.matchMorale, cancelPool);
      await _shootBeat(cancel, 'k2-cancel-range-clear.png');

      final aimCenter = beat.strategyPreviewCenter!;
      final aim = aimCenter + const Offset(40, -16);
      expect(beat.strategyPreviewContains(aim), isTrue);
      final cost = beat.strategyMoraleCostAt(1);
      expect(cost, isNotNull);
      expect(beat.castStrategyOnMap(aim), isTrue);
      expect(beat.matchMorale, readyPool - cost!);
      expect(beat.strategyPreviewVisible, isFalse);
      expect(beat.debugStrategyBeamFrom, isNotNull);
      expect(beat.debugStrategyBeamTo, isNotNull);
      expect(beat.debugStrategyFxLeft, greaterThan(0));
      expect(beat.strategyCastBlocksField, isFalse);
      await _shootBeat(beat, 'b5-beam-mid.png');

      beat.debugAdvanceStrategyFx(beat.debugStrategyFxLeft + 0.05);
      expect(beat.debugStrategyFxLeft, 0);
      expect(beat.matchMorale, readyPool - cost);
      expect(beat.strategyPreviewVisible, isFalse);
      expect(beat.strategyCastBlocksField, isFalse);
      await _shootBeat(beat, 'b6-morale-aftermath.png');
    });
  });
}

void _paint(TaisenGame g) {
  g.debugRecordWatchPaint = true;
  final recorder = ui.PictureRecorder();
  g.render(ui.Canvas(recorder));
  recorder.endRecording().dispose();
}

Future<void> _armReadability(TaisenGame g) async {
  final font = File('/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf');
  if (font.existsSync()) {
    await ui.loadFontFromList(await font.readAsBytes(), fontFamily: TaisenGame.kInkFontFamily);
  }
  await g.softLockCues.loadAll();
}

Future<void> _shootPair(TaisenGame left, TaisenGame right, String name) async {
  final w = left.size.x.ceil();
  final h = left.size.y.ceil();
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(ui.Rect.fromLTWH(0, 0, w * 2.0, h.toDouble()), ui.Paint()..color = const ui.Color(0xFF0A0A0A));
  left.render(canvas);
  canvas.save();
  canvas.translate(w.toDouble(), 0);
  right.render(canvas);
  canvas.restore();
  final picture = recorder.endRecording();
  final image = await picture.toImage(w * 2, h);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final file = File('$kStillDir/$name');
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  expect(file.lengthSync(), greaterThan(8000));
}

Future<void> _shoot(TaisenGame g, String name) async {
  g.debugRecordWatchPaint = true;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  g.render(canvas);
  final picture = recorder.endRecording();
  final image = await picture.toImage(g.size.x.ceil(), g.size.y.ceil());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final file = File('$kStillDir/$name');
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  expect(file.lengthSync(), greaterThan(4000));
  expect(g.watchH / g.size.y, closeTo(0.125, 1e-9));
}

Offset _fieldAt(TaisenGame g, double x, double y) {
  return Offset(g.size.x * x, g.watchH + g.fieldH * y);
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
}

void _addCavalry(TaisenGame g, Offset at) {
  final card = Cost6Roster.all.firstWhere((c) => c.id == 'caocao');
  g.field.add(card);
  g.fieldIsEnemy.add(true);
  g.fieldInCastle.add(false);
  g.fieldPos.add(at);
}

void _turn(TaisenGame g, Offset at, Offset delta) {
  g.selectedIndex = 0;
  g.panStart(at);
  g.panEnd(at + delta);
  g.dragTo = null;
  g.dragging = false;
}

const double _kBeatHudH = 40;

double get _beatFooterH =>
    TaisenGame.kSoftPassFrameH -
    (TaisenGame.kStrategySealCenter.dy - TaisenGame.kStrategySealPt / 2);

double get _beatFieldH => TaisenGame.kSoftPassFrameH - _kBeatHudH - _beatFooterH;

/// Session-2 board inside the Soft Pass frame. Seal and 士氣 are the real chrome.
TaisenGame _beatGame() {
  final g = readyGame();
  g.onGameResize(Vector2(TaisenGame.kSoftPassFrameW, _beatFieldH));
  g.setupSession2Field();
  return g;
}

Future<void> _shootBeat(TaisenGame g, String name) async {
  expect(g.watchH / g.size.y, closeTo(0.125, 1e-9));
  const w = TaisenGame.kSoftPassFrameW;
  const h = TaisenGame.kSoftPassFrameH;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final lacquer = ui.Paint()..color = FactionColors.lacquer;
  canvas.drawRect(const ui.Rect.fromLTWH(0, 0, w, h), lacquer);
  _paintMoraleHud(canvas, g.matchMorale, w);
  canvas.save();
  canvas.translate(0, _kBeatHudH);
  canvas.clipRect(ui.Rect.fromLTWH(0, 0, w, _beatFieldH));
  g.render(canvas);
  canvas.restore();
  final footerTop = _kBeatHudH + _beatFieldH;
  canvas.drawRect(ui.Rect.fromLTWH(0, footerTop, w, _beatFooterH), lacquer);
  _ink(canvas, 'Cost 6', Offset.zero, 16).paint(canvas, Offset(12, footerTop + 28));
  _paintSeal(canvas);
  final picture = recorder.endRecording();
  final image = await picture.toImage(w.ceil(), h.ceil());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final file = File('$kStillDir/$name');
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  expect(file.lengthSync(), greaterThan(8000));
}

void _paintMoraleHud(ui.Canvas canvas, int morale, double width) {
  final label = _ink(canvas, '士氣 $morale', Offset.zero, 14);
  final textX = width - 12 - label.width;
  label.paint(canvas, Offset(textX, 11));
  var x = textX - 6;
  for (var i = 0; i < morale; i++) {
    x -= 11;
    _paintHex(canvas, Offset(x, 14));
  }
}

void _paintHex(ui.Canvas canvas, Offset origin) {
  const w = 9.0;
  const h = 10.0;
  final path = ui.Path()
    ..moveTo(origin.dx + w * 0.5, origin.dy)
    ..lineTo(origin.dx + w, origin.dy + h * 0.25)
    ..lineTo(origin.dx + w, origin.dy + h * 0.75)
    ..lineTo(origin.dx + w * 0.5, origin.dy + h)
    ..lineTo(origin.dx, origin.dy + h * 0.75)
    ..lineTo(origin.dx, origin.dy + h * 0.25)
    ..close();
  canvas.drawPath(path, ui.Paint()..color = FactionColors.gold);
}

void _paintSeal(ui.Canvas canvas) {
  final rect = ui.Rect.fromCenter(
    center: TaisenGame.kStrategySealCenter,
    width: TaisenGame.kStrategySealPt,
    height: TaisenGame.kStrategySealPt,
  );
  final r = ui.RRect.fromRectAndRadius(rect, const ui.Radius.circular(4));
  canvas.drawRRect(r, ui.Paint()..color = FactionColors.lacquer);
  canvas.drawRRect(
    r,
    ui.Paint()
      ..color = FactionColors.gold
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2,
  );
  final label = _ink(canvas, '計略', Offset.zero, 18);
  label.paint(
    canvas,
    Offset(rect.center.dx - label.width / 2, rect.center.dy - label.height / 2),
  );
}

TextPainter _ink(ui.Canvas canvas, String text, Offset at, double fontSize) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: FactionColors.gold,
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        fontFamily: TaisenGame.kInkFontFamily,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  if (at != Offset.zero) painter.paint(canvas, at);
  return painter;
}
