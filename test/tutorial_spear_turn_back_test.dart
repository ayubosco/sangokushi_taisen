import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/data/card_models.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';
import 'package:sangokushi_taisen/game/tutorial_controller.dart';
import 'package:sangokushi_taisen/game/unit_life.dart';

import 'feel_gates_test.dart' show readyGame;

/// 英傑 stage 3 槍擊退敵, beat two. Observed-from-英傑 (AUTH-GAP §1/§2): after
/// the first 迎擊 「更多的騎兵」 come, and the cue is 「回頭，讓他撞上槍擊自滅吧」.
/// A reserve enemy 騎兵 takes the existing 迎擊 lane. The spear turns back,
/// which re-arms the existing 槍擊 gold, and the 騎兵 crashes into it. Same
/// lane, tip reach, stub damage, and 「迎擊」 fly. No number is invented.
/// Not a Feel Pass.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TutorialController aimedCoach() {
    final c = TutorialController()..resetToSession2();
    c.tick(0.4 * 3.03);
    c.tick(0.3 * 3.03);
    c.tick(1.0 * 3.03);
    c.onSpearAimedByMove();
    expect(c.s2, S2Phase.interceptHit);
    return c;
  }

  group('controller', () {
    test('the first 迎擊 opens 回頭, not 遠攻削敵', () {
      final c = aimedCoach()..onAutoIntercept(facingWasCorrect: true);
      expect(c.spearFirstHit, isTrue);
      expect(c.s2, S2Phase.turnBack);
      expect(c.interceptDone, isFalse);
      expect(c.facingCorrect, isFalse, reason: 'the first aim does not carry over');
      expect(c.bowLessonUnlocked, isFalse);
      expect(c.tipText, contains('更多的騎兵'));
      expect(c.tipText, contains('回頭'));
      expect(c.tipText, contains('槍擊自滅'));
      expect(c.lessons.firstWhere((l) => l.id == 'spear').gate, TutorialLessonGate.current);
      expect(c.lessons.firstWhere((l) => l.id == 'bow').gate, TutorialLessonGate.locked);
      c.skipTip();
      expect(c.s2, S2Phase.turnBack, reason: '回頭 cannot be tipped past');
    });

    test('回頭 clears only on a hit after the turn back', () {
      final c = aimedCoach()..onAutoIntercept(facingWasCorrect: true);
      c.onTurnBackHit();
      expect(c.s2, S2Phase.turnBack, reason: 'no turn yet');
      c.onSpearAimedByMove();
      expect(c.facingCorrect, isTrue);
      expect(c.tipText, contains('金光'));
      c.onTurnBackHit();
      expect(c.interceptDone, isTrue);
      expect(c.s2, S2Phase.bowTeach);
      expect(c.tipText, contains('遠攻削敵'));
      expect(c.lessons.firstWhere((l) => l.id == 'spear').gate, TutorialLessonGate.done);
    });

    test('a stage reset clears the first hit; no reserve lets the first 迎擊 stand', () {
      final c = aimedCoach()..onAutoIntercept(facingWasCorrect: true);
      c.resetToSession2();
      expect(c.spearFirstHit, isFalse);
      expect(c.s2, S2Phase.spearGlow);

      final bare = aimedCoach()..onAutoIntercept(facingWasCorrect: true);
      bare.onTurnBackUnavailable();
      expect(bare.interceptDone, isTrue);
      expect(bare.s2, S2Phase.bowTeach);
    });
  });

  group('live 場2', () {
    test('場2 seats a reserve 騎兵 off the first lane', () {
      final g = readyGame();
      g.setupSession2Field();
      final r = g.debugTurnBackCavIndex!;
      expect(r, g.field.length - 1);
      expect(g.fieldIsEnemy[r], isTrue);
      expect(g.field[r].troop, TroopType.cavalry);
      expect(g.field[r].id, isNot(g.field[2].id));
      // Off the first lane: a spear aimed at the first 騎兵 is not aimed here.
      final spear = g.tokenCenter(0);
      final first = g.tokenCenter(2) - spear;
      final reserve = g.tokenCenter(r) - spear;
      final cos = (first.dx * reserve.dx + first.dy * reserve.dy) /
          (first.distance * reserve.distance);
      expect(cos, lessThan(0.2));
    });

    test('the reserve 騎兵 waits, and a gold tip does not spend it before 回頭', () {
      final coach = aimedCoach();
      final g = readyGame(tutorial: coach);
      g.setupSession2Field();
      final r = g.debugTurnBackCavIndex!;
      final at = g.fieldPos[r];
      for (var i = 0; i < 120; i++) {
        g.debugStepPursuit(1 / 60);
      }
      expect(g.fieldPos[r], at, reason: 'no charge before the first 迎擊');

      // Turn the spear toward the reserve so the tip is gold, then put the
      // reserve, facing the spear, right on that tip. It is still held.
      final spear = g.tokenCenter(0);
      final dir = g.tokenCenter(r) - spear;
      g.selectedIndex = 0;
      g.panStart(spear);
      g.panUpdate(spear + dir / dir.distance * 12);
      g.panEnd(spear + dir / dir.distance * 12);
      expect(g.spearQiangjiGoldAt(0), isTrue);
      g.fieldPos[r] = g.spearTipAt(0);
      g.debugLockCardFacing(r, math.pi / 2);
      g.debugStepPursuit(1 / 60);
      expect(coach.s2, isNot(S2Phase.turnBack));
      expect(coach.interceptDone, isFalse);
      expect(g.debugUnitLife(r), UnitLife.alive);
      expect(g.debugRetreatCause(r), isNot('迎擊'));
    });

    test('first 迎擊 → 更多的騎兵 charges → 回頭 into gold 槍擊 → 遠攻削敵', () {
      final coach = aimedCoach();
      final g = readyGame(tutorial: coach);
      g.setupSession2Field();
      final first = g.tutorialEnemyIndex!;
      final r = g.debugTurnBackCavIndex!;

      _firstIntercept(g, first);
      expect(coach.s2, S2Phase.turnBack);
      expect(g.debugRetreatCause(first), '迎擊');
      expect(g.tutorialEnemyIndex, r, reason: 'the Watch follows the reserve');
      expect(g.debugChargingEnemyIndex, r);
      expect(g.spearQiangjiGoldAt(0), isFalse, reason: 'the first hit spent the gold');

      // The reserve walks the existing lane and stands off at tip reach. The
      // tip still points at the first lane, so nothing fires.
      final start = g.fieldPos[r];
      for (var i = 0; i < 600; i++) {
        g.debugStepPursuit(1 / 60);
        expect(coach.s2, S2Phase.turnBack, reason: 'frame $i');
      }
      expect(g.fieldPos[r], isNot(start));
      expect(g.dragTo, isNull, reason: 'the first march has settled');
      // The full frame, not only the pursuit step, owns the idle miss pose.
      g.update(1 / 60);
      expect(g.tipFacingAt(0), isNot(closeTo(TaisenGame.kSpearIdleMissFacing, 0.01)),
          reason: '回頭 starts from the first 迎擊 facing, not the idle miss pose');
      final gap = (g.tokenCenter(r) - g.tokenCenter(0)).distance;
      expect(gap, closeTo(TaisenGame.kSpearTipReach, TaisenGame.kSpearTipHitR));
      expect(g.debugUnitLife(r), UnitLife.alive);

      // 回頭: turn the spear onto the reserve. The turn re-arms gold.
      _turnSpearInto(g, r);
      expect(coach.interceptDone, isTrue);
      expect(coach.s2, S2Phase.bowTeach);
      expect(g.debugHitLabel, '迎擊');
      expect(g.debugRetreatCause(r), '迎擊');
      expect(coach.bowLessonUnlocked, isTrue);
    });

    test('an early 回頭 stays aimed while the charging reserve closes in', () {
      final coach = aimedCoach();
      final g = readyGame(tutorial: coach);
      g.setupSession2Field();
      final r = g.debugTurnBackCavIndex!;
      _firstIntercept(g, g.tutorialEnemyIndex!);
      final far = (g.tokenCenter(r) - g.tokenCenter(0)).distance;
      expect(far, greaterThan(TaisenGame.kSpearTipReach + TaisenGame.kSpearTipHitR));

      // Turn while the reserve is still far off: gold arms, nothing to hit yet.
      final spear = g.tokenCenter(0);
      final dir = g.tokenCenter(r) - spear;
      g.selectedIndex = 0;
      g.panStart(spear);
      g.panEnd(spear + dir / dir.distance * 36);
      g.debugStepPursuit(1 / 60);
      expect(g.spearQiangjiGoldAt(0), isTrue);
      expect(coach.s2, S2Phase.turnBack);

      expect(coach.facingCorrect, isTrue, reason: 'the gold turn is the 回頭 aim');

      var frames = 0;
      while (!coach.interceptDone && frames < 900) {
        g.debugStepPursuit(1 / 60);
        frames++;
      }
      expect(frames, greaterThan(10), reason: 'the reserve had to close in first');
      expect(coach.s2, S2Phase.bowTeach);
      expect(g.debugRetreatCause(r), '迎擊');
      expect(g.spearQiangjiGoldAt(0), isFalse, reason: 'a tip touch spends the gold');
    });

    test('a spear that never turns back keeps 槍擊退敵 open', () {
      final coach = aimedCoach();
      final g = readyGame(tutorial: coach);
      g.setupSession2Field();
      final r = g.debugTurnBackCavIndex!;
      _firstIntercept(g, g.tutorialEnemyIndex!);
      for (var i = 0; i < 60 * 8; i++) {
        g.debugStepPursuit(1 / 60);
      }
      expect(coach.s2, S2Phase.turnBack);
      expect(coach.interceptDone, isFalse);
      expect(g.debugUnitLife(r), UnitLife.alive);
    });

    test('an aim with no gold turn is not 回頭', () {
      final coach = aimedCoach();
      final g = readyGame(tutorial: coach);
      g.setupSession2Field();
      final r = g.debugTurnBackCavIndex!;
      _firstIntercept(g, g.tutorialEnemyIndex!);
      for (var i = 0; i < 900 && g.dragTo != null; i++) {
        g.debugStepPursuit(1 / 60);
      }
      expect(g.dragTo, isNull, reason: 'the first march has settled');
      expect(coach.s2, S2Phase.turnBack);
      // A card rotate swings the tip onto the reserve without arming 槍擊.
      final spear = g.tokenCenter(0);
      final dir = g.tokenCenter(r) - spear;
      g.debugLockCardFacing(0, math.atan2(dir.dx, -dir.dy));
      // A march straight along that facing is no direction change either.
      g.selectedIndex = 0;
      g.panStart(spear);
      g.panEnd(spear + dir / dir.distance * 36);
      for (var i = 0; i < 600; i++) {
        g.debugStepPursuit(1 / 60);
      }
      expect(g.spearQiangjiGoldAt(0), isFalse);
      expect(coach.facingCorrect, isFalse);
      expect(coach.s2, S2Phase.turnBack);
      expect(g.debugUnitLife(r), UnitLife.alive);
    });

    test('the reserve on a tip that never turned back is held', () {
      final coach = aimedCoach();
      final g = readyGame(tutorial: coach);
      g.setupSession2Field();
      final r = g.debugTurnBackCavIndex!;
      _firstIntercept(g, g.tutorialEnemyIndex!);
      expect(coach.facingCorrect, isFalse);
      expect(g.spearQiangjiGoldAt(0), isFalse);
      // Slide the lit reserve onto the old tip. No 回頭, so it is not spent.
      g.fieldPos[r] = g.spearTipAt(0);
      g.enemyFacing = math.pi;
      g.debugStepPursuit(1 / 60);
      expect(coach.s2, S2Phase.turnBack);
      expect(g.debugUnitLife(r), UnitLife.alive);
      expect(g.debugRetreatCause(r), isNot('迎擊'));
    });
  });
}

/// The live first 迎擊: march the spear at the first 騎兵 and meet it on the tip.
void _firstIntercept(TaisenGame g, int foe) {
  g.panStart(g.tokenCenter(0));
  g.panUpdate(g.tokenCenter(foe));
  g.panEnd(g.tokenCenter(foe));
  g.fieldPos[foe] = g.spearTipAt(0);
  g.enemyFacing = math.pi;
  g.debugStepPursuit(1 / 60);
}

/// A short drag from the spear toward [target]: the direction change.
void _turnSpearInto(TaisenGame g, int target) {
  final spear = g.tokenCenter(0);
  final dir = g.tokenCenter(target) - spear;
  g.selectedIndex = 0;
  g.panStart(spear);
  g.panEnd(spear + dir / dir.distance * 36);
  for (var i = 0; i < 30; i++) {
    g.debugStepPursuit(1 / 60);
  }
}
