import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/data/card_models.dart';
import 'package:sangokushi_taisen/game/faction_colors.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';
import 'package:sangokushi_taisen/game/unit_life.dart';
import 'package:sangokushi_taisen/game/tutorial_controller.dart';
import 'package:sangokushi_taisen/main.dart';

import 'feel_gates_test.dart' show readyGame;

/// Tutorial P0 after Feel Not Pass (Branch B). Locks M-01 armed-until-hit
/// and M-02 morale spend. Does not lock foil readouts (3450, 士氣 6/2, 智力 6vs2).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('M-01 direction change arms gold until a hit and does not fire 迎撃', () {
    final g = readyGame();
    final at = _fieldAt(g, 0.42, 0.55);
    _placeOwn(g, at, TroopType.spear);
    g.ownFacing = 0;
    expect(g.spearTipExtendedAt(0), isTrue);
    expect(g.spearQiangjiGoldAt(0), isFalse);
    expect(TaisenGame.kSpearTipReach, closeTo(48 * 1.28, 0.001));
    expect(TaisenGame.kSpearTipHitR, 18);

    final far = Offset(g.size.x * 0.9, g.watchH + 20);
    _addEnemy(g, far);
    final hp = g.debugUnitHp(1);

    g.panStart(at);
    g.panEnd(at + const Offset(0, 80));
    g.dragTo = null;
    g.dragging = false;

    expect(g.spearQiangjiArmedAt(0), isTrue);
    expect(g.spearQiangjiGoldAt(0), isTrue);
    expect(g.spearTipExtendedAt(0), isTrue);
    expect(g.debugHitLabel, isNot('迎擊'));
    expect(g.debugUnitHp(1), hp);

    for (var i = 0; i < 20; i++) {
      g.debugStepPursuit(1 / 60);
    }
    expect(g.spearQiangjiGoldAt(0), isTrue, reason: 'a whiff keeps the gold until a hit');
    expect(g.debugHitLabel, isNot('迎擊'));
    expect(g.debugUnitHp(1), hp);
    expect(g.debugHitLabel, isNot('3450'));
  });

  test('M-01 A4 whiff persist: cavalry passes the tip and gold stays until a hit', () {
    final g = readyGame();
    final at = _fieldAt(g, 0.36, 0.48);
    _placeOwn(g, at, TroopType.spear);
    g.ownFacing = 0;
    _turnSpear(g, at, const Offset(90, 0));
    expect(g.spearQiangjiGoldAt(0), isTrue);
    expect(g.spearTipExtendedAt(0), isTrue);

    final body = g.tokenCenter(0);
    final tip = g.spearTipAt(0);
    final along = tip - body;
    final unit = along / along.distance;
    final side = Offset(-unit.dy, unit.dx);
    final gap = math.max(TaisenGame.kSpearTipHitR, g.meleeContactDist) + 40;
    final start = tip - unit * 70 + side * gap;
    final end = tip + unit * 70 + side * gap;
    _addEnemy(g, start);
    expect(g.field[1].troop, TroopType.cavalry);
    final hp = g.debugUnitHp(1);
    var sawBefore = false;
    var sawAfter = false;
    const steps = 12;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      g.fieldPos[1] = Offset(
        start.dx + (end.dx - start.dx) * t,
        start.dy + (end.dy - start.dy) * t,
      );
      g.debugStepPursuit(1 / 60);
      final liveTip = g.spearTipAt(0);
      expect(
        (liveTip - g.tokenCenter(1)).distance,
        greaterThan(TaisenGame.kSpearTipHitR),
        reason: 'frame $i stays outside the tip',
      );
      expect(g.spearQiangjiArmedAt(0), isTrue, reason: 'A4 gold stays armed across the whiff');
      expect(g.spearQiangjiGoldAt(0), isTrue);
      expect(g.spearTipExtendedAt(0), isTrue);
      expect(g.debugHitLabel, isNot('迎擊'));
      expect(g.debugUnitHp(1), hp);
      final proj = (g.tokenCenter(1) - body).dx * unit.dx + (g.tokenCenter(1) - body).dy * unit.dy;
      if (proj < along.distance - 10) sawBefore = true;
      if (proj > along.distance + 10) sawAfter = true;
    }
    expect(sawBefore && sawAfter, isTrue, reason: 'the cavalry passed the tip');
    expect(g.debugHitLabel, isNot('3450'));

    g.fieldPos[1] = g.spearTipAt(0);
    g.enemyFacing = 0;
    g.debugArmEnemyChargeAura();
    g.debugStepPursuit(1 / 60);
    expect(g.debugHitLabel, '迎擊');
    expect(g.spearQiangjiArmedAt(0), isFalse, reason: 'only the hit clears the whiff gold');
    expect(g.spearQiangjiGoldAt(0), isFalse);
    expect(g.spearTipExtendedAt(0), isTrue);
  });

  test('M-01 gold clears on 迎撃 and the arcade gate still owns the hit', () {
    final armed = readyGame();
    final at = _fieldAt(armed, 0.42, 0.50);
    _placeOwn(armed, at, TroopType.spear);
    armed.ownFacing = 0;
    _turnSpear(armed, at, const Offset(0, 72));
    expect(armed.spearQiangjiGoldAt(0), isTrue);

    _addEnemy(armed, armed.spearTipAt(0));
    armed.enemyFacing = 0;
    armed.debugArmEnemyChargeAura();
    final before = armed.debugUnitHp(1);
    armed.debugStepPursuit(1 / 60);

    expect(armed.debugHitLabel, '迎擊');
    expect(armed.spearQiangjiGoldAt(0), isFalse);
    expect(armed.spearTipExtendedAt(0), isTrue, reason: 'arcade tip stays out after the hit');
    expect(before - armed.debugUnitHp(1), TaisenGame.kRansenMaxHp);
    expect(armed.debugUnitHp(1), isNot(3450));

    final plain = readyGame();
    _placeOwn(plain, at, TroopType.spear);
    plain.ownFacing = 0;
    _addEnemy(plain, plain.spearTipAt(0));
    plain.enemyFacing = math.pi;
    plain.debugArmEnemyChargeAura();
    expect(plain.spearQiangjiGoldAt(0), isFalse);
    plain.debugStepPursuit(1 / 60);
    expect(plain.debugHitLabel, '迎擊', reason: '迎撃 does not require the armed flag');
    expect(plain.spearQiangjiGoldAt(0), isFalse);
    expect(plain.spearTipExtendedAt(0), isTrue);
  });

  test('M-01 an armed slow scrape is still one 槍尖 tick, not a new multiplier', () {
    final g = readyGame();
    final at = _fieldAt(g, 0.42, 0.50);
    _placeOwn(g, at, TroopType.spear);
    g.ownFacing = 0;
    _turnSpear(g, at, const Offset(0, 72));
    _addEnemy(g, g.spearTipAt(0));
    g.enemyFacing = 0;
    g.debugSetMoveSpeed(1, 1.1);
    g.debugStepPursuit(1 / 60);
    expect(g.debugHitLabel, isNot('迎擊'));
    expect(g.spearQiangjiGoldAt(0), isFalse, reason: 'a tip hit clears the gold');
    expect(
      g.debugUnitHp(1),
      closeTo(TaisenGame.kRansenMaxHp - TaisenGame.kRansenTickPerSec, 0.01),
    );
    expect(g.spearTipExtendedAt(0), isTrue);
  });

  test('M-01 card lock and a same-direction drag do not arm; a second spear stays dark', () {
    final g = readyGame();
    final at = _fieldAt(g, 0.30, 0.55);
    _placeOwn(g, at, TroopType.spear);
    g.debugLockCardFacing(0, math.pi);
    g.debugStepPursuit(1 / 60);
    expect(g.spearQiangjiArmedAt(0), isFalse);
    expect(g.spearTipExtendedAt(0), isTrue);

    g.panStart(at);
    g.panEnd(at + const Offset(0, 70));
    g.dragTo = null;
    expect(g.spearQiangjiArmedAt(0), isFalse, reason: 'already facing that way');

    _addOwn(g, at + const Offset(90, 0), TroopType.spear);
    g.selectedIndex = 0;
    g.panStart(at);
    g.panEnd(at + const Offset(70, 0));
    g.dragTo = null;
    expect(g.spearQiangjiGoldAt(0), isTrue);
    expect(g.spearQiangjiArmedAt(1), isFalse);
    expect(g.spearTipExtendedAt(1), isTrue);
  });

  test('M-01 亂戰 retracts the tip and clears the gold', () {
    final g = readyGame();
    final at = _fieldAt(g, 0.42, 0.50);
    _placeOwn(g, at, TroopType.spear);
    g.ownFacing = 0;
    _turnSpear(g, at, const Offset(70, 0));
    expect(g.spearQiangjiGoldAt(0), isTrue);
    _addEnemy(g, at);
    g.debugStepPursuit(1 / 60);
    expect(g.debugInRansen(0), isTrue);
    expect(g.spearTipExtendedAt(0), isFalse);
    expect(g.spearQiangjiGoldAt(0), isFalse);
    expect(g.spearQiangjiArmedAt(0), isFalse);
  });

  test('M-01 death releases the armed flag; siege prep is the existing tip gate', () {
    final dead = readyGame();
    final at = _fieldAt(dead, 0.42, 0.50);
    _placeOwn(dead, at, TroopType.spear);
    dead.ownFacing = 0;
    _turnSpear(dead, at, const Offset(70, 0));
    expect(dead.spearQiangjiGoldAt(0), isTrue);
    expect(dead.spearTipExtendedAt(0), isTrue);
    dead.debugForceHpZero(0);
    expect(dead.debugUnitLife(0), UnitLife.retreating);
    expect(dead.spearQiangjiArmedAt(0), isFalse);
    expect(dead.spearQiangjiGoldAt(0), isFalse);
    expect(TaisenGame.kSpearTipReach, closeTo(48 * 1.28, 0.001));

    final zoned = readyGame();
    final zoneAt = _enemyZoneAt(zoned);
    _placeOwn(zoned, zoneAt, TroopType.spear);
    zoned.ownFacing = 0;
    _turnSpear(zoned, zoneAt, const Offset(0, 64));
    zoned.dragTo = null;
    expect(zoned.inEnemyCastleZone(0), isTrue);
    expect(zoned.debugSiegePrepVisible(0), isFalse);
    expect(zoned.spearTipExtendedAt(0), isTrue);
    expect(zoned.spearQiangjiGoldAt(0), isTrue);

    final siege = readyGame();
    final siegeAt = _enemyZoneAt(siege);
    final card = Cost6Roster.all.firstWhere((c) => c.troop == TroopType.siege);
    siege.field
      ..clear()
      ..add(card);
    siege.fieldPos
      ..clear()
      ..add(siegeAt);
    siege.fieldIsEnemy
      ..clear()
      ..add(false);
    siege.fieldInCastle
      ..clear()
      ..add(false);
    siege.debugStepPursuit(1 / 60);
    expect(siege.debugSiegePrepVisible(0), isTrue);
    expect(siege.spearQiangjiArmedAt(0), isFalse);
    expect(siege.spearTipExtendedAt(0), isFalse);
  });

  test('M-02 cast spends the printed card cost, previews range, and does not melt', () {
    final g = readyGame();
    g.setupSession2Field();
    final spear = g.field[0];
    final bow = g.field[1];
    expect(spear.strategyMorale, greaterThan(0));
    expect(bow.strategyMorale, isNot(spear.strategyMorale));
    expect(g.matchMorale, spear.strategyMorale + bow.strategyMorale);
    expect(g.strategyPreviewVisible, isTrue);
    expect(
      g.strategyPreviewCaption,
      '${spear.strategyName} 士氣${spear.strategyMorale} 智力${spear.intel}',
    );
    expect(g.strategyPreviewCaption, isNot(contains('6vs2')));
    expect(g.strategyPreviewRadius, closeTo(g.tokenCardSize.width * 1.5, 0.01));
    expect(g.strategyCastBlocksField, isFalse);

    final center = g.strategyPreviewCenter!;
    final inside = center + Offset(g.strategyPreviewRadius * 0.4, 0);
    expect(inside.dy, greaterThan(g.watchH));
    expect(g.strategyPreviewContains(inside), isTrue);
    expect(g.strategyPreviewContains(center + Offset(g.strategyPreviewRadius + 24, 0)), isFalse);
    expect(g.strategyPreviewContains(Offset(center.dx, g.watchH * 0.4)), isFalse);

    final enemyHp = g.debugUnitHp(2);
    expect(g.castStrategyOnMap(inside), isTrue);
    expect(g.strategyPreviewVisible, isFalse, reason: 'cast clears the range ring');
    expect(g.debugStrategyBeamTo, inside);
    expect(g.matchMorale, bow.strategyMorale);
    expect(g.debugStrategyCastAt, inside);
    expect(g.debugStrategyBeamFrom, center);
    expect(g.debugHitLabel, isNot('雷擊'));
    expect(g.debugHitLabel, isNot('迎擊'));
    expect(g.debugUnitHp(2), enemyHp);

    expect(g.castStrategyFlick(), isFalse, reason: 'the ring stays down until another select');
    expect(g.matchMorale, bow.strategyMorale);

    g.selectOrDetailAt(g.tokenCenter(1));
    final bowCost = g.field[1].strategyMorale;
    expect(g.strategyPreviewVisible, isTrue);
    expect(g.strategyPreviewCaption, contains('士氣$bowCost'));
    expect(g.castStrategyFlick(), isTrue);
    expect(g.strategyPreviewVisible, isFalse);
    expect(g.matchMorale, 0);
    expect(g.debugStrategyCastAt, g.tokenCenter(1));
    expect(g.debugUnitHp(2), enemyHp);

    g.selectOrDetailAt(g.tokenCenter(0));
    expect(g.strategyPreviewVisible, isTrue);
    g.cancelStrategyPreview();
    expect(g.strategyPreviewVisible, isFalse);
    expect(g.castStrategyAtSelected(), isFalse);
    expect(g.matchMorale, 0);
    g.selectOrDetailAt(g.tokenCenter(0));
    expect(g.strategyPreviewVisible, isTrue);
    g.selectOrDetailAt(Offset(4, g.watchH + 4));
    expect(g.selectedIndex, isNull);
    expect(g.strategyPreviewVisible, isFalse);
  });

  test('M-02 a short pool refuses the cast and the seal is not FX-only', () {
    final g = readyGame();
    g.setupSession2Field();
    final cost = g.field[0].strategyMorale;
    expect(g.strategyPreviewVisible, isTrue);
    g.matchMorale = cost - 1;
    g.triggerStrategyFx(notifyTutorial: false);
    expect(g.matchMorale, cost - 1);
    expect(g.debugStrategyCastAt, isNull);
    expect(g.strategyPreviewVisible, isTrue, reason: 'a refused cast leaves the ring');

    final bare = readyGame();
    bare.triggerStrategyFx();
    expect(bare.debugStrategyCastAt, isNull);
    expect(bare.matchMorale, 0);

    g.matchMorale = cost;
    g.triggerStrategyFx(notifyTutorial: false);
    expect(g.matchMorale, 0);
    expect(g.debugStrategyCastAt, g.tokenCenter(0));
    expect(g.strategyPreviewVisible, isFalse);
    expect(g.strategyCastBlocksField, isFalse);
  });

  test('M-02 智力 stays a display field; 赤壁 does not apply a 6vs2 formula', () {
    final g = readyGame();
    final at = _fieldAt(g, 0.40, 0.60);
    final zhou = Cost6Roster.all.firstWhere((c) => c.id == 'zhouyu');
    g.field
      ..clear()
      ..add(zhou);
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
    g.selectOrDetailAt(at);
    _addEnemy(g, at + const Offset(40, -30));
    g.matchMorale = zhou.strategyMorale;
    final hp = g.debugUnitHp(1);
    expect(g.strategyPreviewCaption, contains('智力${zhou.intel}'));
    expect(g.castStrategyAtSelected(), isTrue);
    expect(g.debugUnitHp(1), hp);
    expect(g.debugHitLabel, isNot('雷擊'));
    expect(g.matchMorale, 0);
  });

  test('lesson rail reads the 英傑 stage names and bow drag still does not loose', () {
    final c = TutorialController()..resetToSession1();
    expect(c.lessons.map((l) => l.name).toList(), ['快馬突擊', '槍擊退敵', '遠攻削敵', '回城', '用計得宜']);
    expect(c.lessons.map((l) => l.id).toList(), ['charge', 'spear', 'bow', 'return', 'strategy']);

    c.resetToSession2();
    expect(c.tipText, contains('金光'));
    c.turnWindowOpen = true;
    c.s2 = S2Phase.waitTurn;
    c.onSpearAimedByMove();
    expect(c.tipText, contains('金光'));
    expect(c.s2, S2Phase.interceptHit);
    expect(c.bowLessonUnlocked, isFalse);

    c.interceptDone = true;
    c.s2 = S2Phase.returnCity;
    c.onStrategy();
    expect(c.tipText, contains('士氣'));
    expect(c.s2, S2Phase.returnCity, reason: '計略 does not replace 回城');
    expect(c.lessons.map((l) => l.name).toList(), ['快馬突擊', '槍擊退敵', '遠攻削敵', '回城', '用計得宜']);

    final moving = readyGame();
    final at = _fieldAt(moving, 0.30, 0.46);
    moving.debugRestageOwnEnemy(
      ownId: 'sunquan',
      ownAt: at,
      enemyAt: at + const Offset(120, -40),
    );
    moving.panStart(at);
    moving.panUpdate(at + const Offset(160, 0));
    for (var i = 0; i < 90; i++) {
      moving.debugStepPursuit(1 / 60);
    }
    expect(moving.dragging, isTrue);
    expect(moving.debugHitLabel, isNot('射'));
    expect(moving.debugUnitHp(1), TaisenGame.kRansenMaxHp);
    expect(moving.debugBowWinding, isFalse);
  });

  testWidgets('seal tap spends 士氣, opens no cut-in, and 用計得宜 waits locked as step 5', (tester) async {
    await tester.pumpWidget(const SangokushiApp());
    await tester.tap(find.text('輕觸繼續'));
    await tester.pump();
    await tester.tap(find.text('今場不用兵法'));
    await tester.pump();
    await tester.pump();

    final game = tester.widget<GameWidget<TaisenGame>>(find.byType(GameWidget<TaisenGame>)).game!;
    final own = game.tutorialOwnIndex!;
    game.selectOrDetailAt(game.tokenCenter(own));
    await tester.pump();

    expect(game.strategyPreviewVisible, isTrue);
    expect(find.byKey(const Key('match-morale')), findsOneWidget);
    expect(find.text('士氣 4'), findsOneWidget);
    expect(find.byKey(const Key('match-morale-pip')), findsNWidgets(4));
    final seal = tester.widget<Material>(find.byKey(const Key('soft-pass-strategy-seal')));
    expect(seal.color, FactionColors.lacquer);
    expect(find.text('快馬突擊'), findsOneWidget);
    expect(find.text('槍擊退敵'), findsOneWidget);
    expect(find.text('遠攻削敵'), findsOneWidget);
    expect(find.text('回城'), findsOneWidget);
    expect(find.byKey(const Key('tutorial-coach-tip')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('tutorial-lesson-charge')),
        matching: find.byKey(const Key('tutorial-handoff-hand')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('tutorial-lesson-return')),
        matching: find.byKey(const Key('tutorial-handoff-hand')),
      ),
      findsNothing,
    );
    expect(find.text('迎撃後開弓'), findsNothing);
    final rail = find.byKey(const Key('tutorial-lesson-rail'));
    expect(find.descendant(of: rail, matching: find.text('1')), findsOneWidget);
    expect(find.descendant(of: rail, matching: find.text('2')), findsOneWidget);
    expect(find.descendant(of: rail, matching: find.text('3')), findsOneWidget);
    expect(find.descendant(of: rail, matching: find.text('4')), findsOneWidget);
    expect(find.descendant(of: rail, matching: find.text('5')), findsOneWidget);
    expect(find.text('用計得宜'), findsOneWidget);
    expect(find.byKey(const Key('tutorial-lesson-lock-strategy')), findsOneWidget);

    await tester.tap(find.byKey(const Key('soft-pass-strategy-seal')));
    await tester.pump();

    expect(find.text('士氣 0'), findsOneWidget);
    expect(find.byKey(const Key('match-morale-pip')), findsNothing);
    expect(game.strategyPreviewVisible, isFalse);
    expect(game.matchMorale, 0);
    game.selectOrDetailAt(game.tokenCenter(own));
    expect(game.strategyPreviewVisible, isTrue);
    game.cancelStrategyPreview();
    expect(game.strategyPreviewVisible, isFalse);
    expect(game.matchMorale, 0);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('計略'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 2300));
  });
}

Offset _fieldAt(TaisenGame g, double xFrac, double yFrac) {
  return Offset(g.size.x * xFrac, g.watchH + g.fieldH * yFrac);
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

void _addOwn(TaisenGame g, Offset at, TroopType troop) {
  final card = Cost6Roster.all.firstWhere((c) => c.troop == troop && c.id != g.field.first.id);
  g.field.add(card);
  g.fieldIsEnemy.add(false);
  g.fieldInCastle.add(false);
  g.fieldPos.add(at);
}

Offset _enemyZoneAt(TaisenGame g) {
  final zone = g.enemyCastleZoneRect;
  return Offset(zone.center.dx, zone.top + zone.height * 0.45);
}

void _turnSpear(TaisenGame g, Offset at, Offset delta) {
  g.selectedIndex = 0;
  g.panStart(at);
  g.panEnd(at + delta);
  g.dragTo = null;
  g.dragging = false;
}
