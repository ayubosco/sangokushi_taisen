import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/data/card_models.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';
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
    expect(g.matchMorale, bow.strategyMorale);
    expect(g.debugStrategyCastAt, inside);
    expect(g.debugStrategyBeamFrom, center);
    expect(g.debugStrategyBeamTo, inside);
    expect(g.debugHitLabel, isNot('雷擊'));
    expect(g.debugHitLabel, isNot('迎擊'));
    expect(g.debugUnitHp(2), enemyHp);

    g.selectedIndex = 1;
    final bowCost = g.field[1].strategyMorale;
    expect(g.castStrategyFlick(), isTrue);
    expect(g.matchMorale, 0);
    expect(g.debugStrategyCastAt, g.tokenCenter(1));
    expect(g.strategyPreviewCaption, contains('士氣$bowCost'));
    expect(g.castStrategyAtSelected(), isFalse);
    expect(g.matchMorale, 0);
    expect(g.debugUnitHp(2), enemyHp);
  });

  test('M-02 a short pool refuses the cast and the seal is not FX-only', () {
    final g = readyGame();
    g.setupSession2Field();
    final cost = g.field[0].strategyMorale;
    g.matchMorale = cost - 1;
    g.triggerStrategyFx(notifyTutorial: false);
    expect(g.matchMorale, cost - 1);
    expect(g.debugStrategyCastAt, isNull);

    g.matchMorale = cost;
    g.triggerStrategyFx(notifyTutorial: false);
    expect(g.matchMorale, 0);
    expect(g.debugStrategyCastAt, g.tokenCenter(0));
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
    _addEnemy(g, at + const Offset(40, -30));
    g.matchMorale = zhou.strategyMorale;
    final hp = g.debugUnitHp(1);
    expect(g.strategyPreviewCaption, contains('智力${zhou.intel}'));
    expect(g.castStrategyAtSelected(), isTrue);
    expect(g.debugUnitHp(1), hp);
    expect(g.debugHitLabel, isNot('雷擊'));
    expect(g.matchMorale, 0);
  });

  test('lesson rail stays the Soft Lock 4-step and bow drag still does not loose', () {
    final c = TutorialController()..resetToSession1();
    expect(c.lessons.map((l) => l.name).toList(), ['騎突擊', '槍迎撃', '弓教學', '回城']);
    expect(c.lessons.map((l) => l.id).toList(), ['charge', 'spear', 'bow', 'return']);

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
    expect(c.lessons.map((l) => l.name).toList(), ['騎突擊', '槍迎撃', '弓教學', '回城']);

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

  testWidgets('seal tap spends 士氣 and does not open a cut-in or a fifth lesson', (tester) async {
    await tester.pumpWidget(const SangokushiApp());
    await tester.tap(find.text('輕觸繼續'));
    await tester.pump();
    await tester.tap(find.text('今場不用兵法'));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('match-morale')), findsOneWidget);
    expect(find.text('士氣 4'), findsOneWidget);
    expect(find.text('騎突擊'), findsOneWidget);
    expect(find.text('槍迎撃'), findsOneWidget);
    expect(find.text('弓教學'), findsOneWidget);
    expect(find.text('回城'), findsOneWidget);
    expect(find.text('用計得宜'), findsNothing);
    expect(find.text('槍擊退敵'), findsNothing);

    await tester.tap(find.byKey(const Key('soft-pass-strategy-seal')));
    await tester.pump();

    expect(find.text('士氣 0'), findsOneWidget);
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

void _turnSpear(TaisenGame g, Offset at, Offset delta) {
  g.selectedIndex = 0;
  g.panStart(at);
  g.panEnd(at + delta);
  g.dragTo = null;
  g.dragging = false;
}
