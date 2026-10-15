import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/data/card_models.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';
import 'package:sangokushi_taisen/game/tutorial_controller.dart';
import 'package:sangokushi_taisen/game/unit_life.dart';

import 'feel_gates_test.dart' show readyGame;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('GAP-SPR-TIP: tip overlap ticks without 迎撃 or 亂戰; gates still own the big hit', () {
    final slow = _spearVersusCav(aura: false);
    slow.g.fieldPos[1] = slow.g.spearTipAt(0);
    slow.g.enemyFacing = math.pi;
    slow.g.debugSetMoveSpeed(1, 1.1);
    slow.g.debugStepPursuit(1 / 60);

    expect(slow.g.debugInRansen(0), isFalse);
    expect(slow.g.debugInRansen(1), isFalse);
    expect(slow.g.debugHitLabel, isNot('迎撃'));
    expect(slow.g.debugHitLabel, isNot('迎擊'));
    expect(slow.g.debugTipScrapeArmed, isFalse);
    expect(
      slow.g.debugUnitHp(1),
      closeTo(TaisenGame.kRansenMaxHp - TaisenGame.kRansenTickPerSec, 0.01),
    );
    expect(slow.g.debugUnitLife(1), UnitLife.alive);

    final rear = _spearVersusCav(aura: true);
    rear.g.fieldPos[1] = rear.g.spearTipAt(0) + const Offset(0, -12);
    rear.g.enemyFacing = 0;
    rear.g.debugStepPursuit(1 / 60);
    expect(rear.g.debugHitLabel, isNot('迎擊'));
    expect(rear.g.debugTipScrapeArmed, isFalse);
    expect(rear.g.debugInRansen(0), isFalse);
    expect(rear.g.debugUnitHp(1), lessThan(TaisenGame.kRansenMaxHp));
    expect(rear.g.debugUnitLife(1), UnitLife.alive);

    final away = _spearVersusCav(aura: true);
    away.g.ownFacing = math.pi;
    away.g.fieldPos[1] = away.g.tokenCenter(0) + const Offset(0, -160);
    away.g.debugStepPursuit(1 / 60);
    expect(away.g.debugUnitHp(1), TaisenGame.kRansenMaxHp);
    expect(away.g.debugHitLabel, isNot('迎擊'));
    expect(away.g.debugTipScrapeArmed, isFalse);

    final front = _spearVersusCav(aura: true);
    front.g.fieldPos[1] = front.g.spearTipAt(0);
    front.g.enemyFacing = math.pi;
    front.g.debugStepPursuit(1 / 60);
    expect(front.g.debugTipScrapeArmed, isTrue);
    expect(front.g.debugHitLabel, '迎擊');
    expect(front.g.debugInRansen(0), isFalse);
    expect(front.g.debugUnitLife(1), UnitLife.retreating);
    expect(front.g.spearTipExtendedAt(0), isTrue);
  });

  test('GAP-SORTIE: 出城 prep is visible, speed-scaled, and not an instant march', () {
    expect(TaisenGame.kSortiePrepBaseC, 2.5);
    final spearSec = _prepSeconds(TroopType.spear);
    final cavSec = _prepSeconds(TroopType.cavalry);
    expect(cavSec, lessThan(spearSec));
    expect(cavSec, greaterThan(0));

    final hold = _parkedAtExit(TroopType.spear, pastExit: false);
    hold.g.debugStepPursuit(0.5);
    expect(hold.g.debugSortiePrepVisible(0), isFalse);
    expect(hold.g.fieldInCastle[0], isTrue);

    final exiting = _parkedAtExit(TroopType.spear, pastExit: true);
    final origin = exiting.g.tokenCenter(0);
    final outside = Offset(origin.dx, exiting.g.castleBandRect.top - 180);
    exiting.g.panStart(origin);
    exiting.g.panEnd(outside);
    expect(exiting.g.debugSortiePrepVisible(0), isTrue);
    expect(exiting.g.debugSortiePrepCaption(0), TaisenGame.kSortiePrepCaption);
    expect(exiting.g.debugSortiePrepCaption(0), contains('出城'));
    expect(exiting.g.debugSortiePrepCaption(0), contains('出征'));
    expect(exiting.g.fieldInCastle[0], isFalse);
    final left = exiting.g.debugSortiePrepLeft(0);
    expect(left, closeTo(spearSec, 0.05));

    exiting.g.panStart(exiting.g.tokenCenter(0));
    exiting.g.panUpdate(Offset(outside.dx + 30, outside.dy));
    exiting.g.panEnd(Offset(outside.dx + 40, outside.dy - 20));
    exiting.g.debugStepPursuit(0.25);
    expect(exiting.g.debugSortiePrepLeft(0), closeTo(left - 0.25, 0.04));
    expect(exiting.g.debugSortiePrepLeft(0), lessThan(left));
    expect(exiting.g.tokenCenter(0).dy, closeTo(origin.dy, 1.5));

    final beforeMarch = exiting.g.tokenCenter(0);
    final remain = exiting.g.debugSortiePrepLeft(0);
    exiting.g.debugStepPursuit(remain);
    final stepped = (exiting.g.tokenCenter(0) - beforeMarch).distance;
    expect(exiting.g.debugSortiePrepVisible(0), isFalse);
    expect(stepped, greaterThan(0.2));
    expect(stepped, lessThan(40), reason: 'prep end is a troop step, not a teleport');
    expect((exiting.g.tokenCenter(0) - outside).distance, greaterThan(80));
    expect(exiting.g.auraActive, isFalse);
    expect(exiting.g.debugHitLabel, isNot('突撃'));

    final idle = _parkedAtExit(TroopType.cavalry, pastExit: true);
    idle.g.fieldInCastle[0] = true;
    final stayed = idle.g.tokenCenter(0);
    idle.g.debugStepPursuit(0.05);
    expect(idle.g.debugSortiePrepVisible(0), isTrue);
    idle.g.dragTo = null;
    idle.g.debugStepPursuit(idle.g.debugSortiePrepLeft(0) + 0.2);
    expect(idle.g.tokenCenter(0), stayed);
    expect(idle.g.auraActive, isFalse);
    expect(idle.g.debugHitLabel, isNot('突撃'));
  });

  test('GAP-SORTIE: revive ready does not snap alive or auto-charge before prep', () {
    final g = readyGame();
    final at = Offset(g.size.x * 0.40, g.watchH + g.fieldH * 0.45);
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
    g.debugForceHpZero(0);
    final band = g.castleBandRect;
    g.fieldPos[0] = Offset(band.center.dx, band.top + band.height * 0.72);
    g.debugStepPursuit(g.debugReviveLeft(0) + 1);
    expect(g.debugUnitLife(0), UnitLife.readyRedeploy);

    final body = g.tokenCenter(0);
    g.panStart(body);
    g.panEnd(Offset(body.dx, band.top - 120));
    g.debugStepPursuit(0.2);
    expect(g.debugUnitLife(0), isNot(UnitLife.alive));
    expect(g.auraActive, isFalse);
    expect(g.debugHitLabel, isNot('突撃'));

    var guard = 0;
    while (!g.debugSortiePrepVisible(0) && guard < 400) {
      g.debugStepPursuit(1 / 60);
      guard++;
    }
    expect(g.debugSortiePrepVisible(0), isTrue);
    expect(g.debugUnitLife(0), UnitLife.readyRedeploy);
    expect(g.auraActive, isFalse);
  });

  test('GAP-TUT-HANDOFF: one aimed 迎撃 unlocks 弓 without 回城; idle does not', () {
    final idle = TutorialController()..resetToSession2();
    final idleGame = readyGame(tutorial: idle);
    idleGame.setupSession2Field();
    _openSpearWindow(idle);
    expect(idle.facingCorrect, isFalse);
    final enemy = idleGame.tutorialEnemyIndex!;
    idleGame.fieldPos[enemy] = idleGame.spearTipAt(0);
    idleGame.debugStepPursuit(1 / 60);
    expect(idle.s2, isNot(S2Phase.bowTeach));
    expect(idle.interceptDone, isFalse);
    expect(idle.bowLessonUnlocked, isFalse);
    expect(idle.lessons.firstWhere((l) => l.id == 'bow').name, '弓教學');
    expect(idle.lessons.firstWhere((l) => l.id == 'bow').gate, TutorialLessonGate.locked);
    expect(idleGame.debugUnitLife(enemy), UnitLife.alive);

    for (var i = 0; i < 40; i++) {
      idleGame.debugStepPursuit(1 / 60);
    }
    expect(idle.s2, isNot(S2Phase.bowTeach));

    final coach = TutorialController()..resetToSession2();
    final g = readyGame(tutorial: coach);
    g.setupSession2Field();
    _openSpearWindow(coach);
    final spearAt = g.tokenCenter(0);
    final foe = g.tutorialEnemyIndex!;
    g.panStart(spearAt);
    g.panUpdate(g.tokenCenter(foe));
    g.panEnd(g.tokenCenter(foe));
    g.fieldPos[foe] = g.spearTipAt(0);
    g.enemyFacing = math.pi;
    g.debugStepPursuit(1 / 60);

    expect(coach.interceptDone, isTrue);
    expect(coach.s2, S2Phase.bowTeach);
    expect(coach.bowLessonUnlocked, isTrue);
    expect(coach.bowLessonLive, isTrue);
    expect(coach.lessons.firstWhere((l) => l.id == 'bow').gate, TutorialLessonGate.current);
    expect(coach.lessons.firstWhere((l) => l.id == 'return').gate, TutorialLessonGate.locked);
    expect(coach.s2, isNot(S2Phase.returnCity));
    expect(coach.strategyOrReturnDone, isFalse);
    expect(g.debugHitLabel, '迎擊');
    expect(coach.tipText, contains('弓'));
    expect(coach.tipSkippable, isFalse);
  });
}

void _openSpearWindow(TutorialController coach) {
  coach.tick(0.4 * 3.03);
  coach.tick(0.3 * 3.03);
  coach.tick(1.0 * 3.03);
  expect(coach.turnWindowOpen, isTrue);
  expect(coach.s2, S2Phase.waitTurn);
}

double _prepSeconds(TroopType troop) {
  final g = _parkedAtExit(troop, pastExit: true);
  final at = g.g.tokenCenter(0);
  g.g.panStart(at);
  g.g.panEnd(Offset(at.dx, g.g.castleBandRect.top - 160));
  return g.g.debugSortiePrepLeft(0);
}

({TaisenGame g}) _parkedAtExit(TroopType troop, {required bool pastExit}) {
  final g = readyGame();
  final card = Cost6Roster.all.firstWhere((c) => c.troop == troop);
  final band = g.castleBandRect;
  final depth = pastExit ? TaisenGame.kCastleExitDepth : TaisenGame.kCastleExitDepth + (1 / band.height);
  final at = Offset(band.center.dx, band.top + band.height * depth);
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
    ..add(true);
  g.selectedIndex = 0;
  g.dragging = false;
  g.dragTo = null;
  return (g: g);
}

({TaisenGame g}) _spearVersusCav({required bool aura}) {
  final g = readyGame();
  final at = Offset(g.size.x * 0.42, g.watchH + g.fieldH * 0.55);
  final spear = Cost6Roster.all.firstWhere((c) => c.troop == TroopType.spear);
  final cav = Cost6Roster.all.firstWhere((c) => c.id == 'caocao');
  g.field
    ..clear()
    ..add(spear)
    ..add(cav);
  g.fieldPos
    ..clear()
    ..add(at)
    ..add(at + const Offset(0, -220));
  g.fieldIsEnemy
    ..clear()
    ..add(false)
    ..add(true);
  g.fieldInCastle
    ..clear()
    ..add(false)
    ..add(false);
  g.selectedIndex = 0;
  g.ownFacing = 0;
  if (aura) g.debugArmEnemyChargeAura();
  return (g: g);
}
