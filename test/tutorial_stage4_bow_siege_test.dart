import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/data/card_models.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';
import 'package:sangokushi_taisen/game/tutorial_controller.dart';

import 'feel_gates_test.dart' show readyGame;

/// 英傑 stage 4 遠攻削敵 lesson flow. Observed-from-英傑 (AUTH-GAP §3): the
/// stage cues are「速派單一弓兵攻城」— one archer on the enemy gate shows
/// 「攻城中」+ countdown — and「另一弓兵從後支援」— a second archer shoots from
/// the back rank while the first holds the gate — and「輪流走位牽制」— the two
/// archers take turns on the move while the other keeps shooting. The lesson
/// clears on a standing shot, that siege beat, the support shot, and both 走位
/// turns, in any order. The siege reuses the existing gauge, fill rate, and
/// gate nick; the support and kite shots reuse the existing standing shot and
/// range. No bow number is invented. Not a Feel Pass.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TutorialController bowCoach() {
    final c = TutorialController()..resetToSession2();
    c.interceptDone = true;
    c.s2 = S2Phase.bowTeach;
    return c;
  }

  /// Both own bows take their 走位 turn (場2 slots 1 and 4).
  void kite(TutorialController c) {
    c.onBowKiteShot(mover: 1);
    c.onBowKiteShot(mover: 4);
  }

  group('controller', () {
    test('a shot alone keeps 遠攻削敵 current and points at the gate', () {
      final c = bowCoach();
      c.onBowShot();
      expect(c.bowShotLanded, isTrue);
      expect(c.s2, S2Phase.bowTeach);
      expect(c.bowLessonLive, isTrue);
      expect(c.tipText, contains('速派單一弓兵攻城'));
      expect(c.lessons.firstWhere((l) => l.id == 'bow').current, isTrue);
      expect(c.lessons.firstWhere((l) => l.id == 'return').gate,
          TutorialLessonGate.locked);
    });

    test('攻城中 swaps the tip once; it does not clear the stage', () {
      final c = bowCoach()..onBowShot();
      var notes = 0;
      c.addListener(() => notes++);
      c.onBowSieging();
      c.onBowSieging();
      expect(notes, 1);
      expect(c.tipText, contains('攻城中'));
      expect(c.s2, S2Phase.bowTeach);
    });

    test('shot, siege, support wait for 輪流走位牽制, then clear to 回城', () {
      final c = bowCoach()
        ..onBowShot()
        ..onBowSiegeLanded();
      expect(c.s2, S2Phase.bowTeach);
      expect(c.tipText, contains('另一弓兵從後支援'));
      c.onBowSupportShot();
      expect(c.s2, S2Phase.bowTeach);
      expect(c.tipText, contains('輪流走位牽制'));
      kite(c);
      expect(c.s2, S2Phase.returnCity);
      expect(c.lessons.firstWhere((l) => l.id == 'bow').gate,
          TutorialLessonGate.done);
    });

    test('siege then a plain shot does not clear; the support shot does', () {
      final c = bowCoach()..onBowSiegeLanded();
      expect(c.s2, S2Phase.bowTeach);
      expect(c.tipText, contains('射'));
      c.onBowShot();
      expect(c.s2, S2Phase.bowTeach);
      c.onBowSupportShot();
      expect(c.s2, S2Phase.bowTeach);
      kite(c);
      expect(c.s2, S2Phase.returnCity);
    });

    test('support then siege clears; the support shot also counts as the shot', () {
      final c = bowCoach()..onBowSupportShot();
      expect(c.bowShotLanded, isTrue);
      expect(c.bowSupportLanded, isTrue);
      expect(c.s2, S2Phase.bowTeach);
      expect(c.tipText, contains('攻城中'));
      c.onBowSiegeLanded();
      expect(c.s2, S2Phase.bowTeach);
      kite(c);
      expect(c.s2, S2Phase.returnCity);
    });

    test('one 走位 turn is not the beat; the other bow must take its turn', () {
      final c = bowCoach();
      c.onBowKiteShot(mover: 1);
      expect(c.bowKiteTurns, 1);
      expect(c.bowKiteLanded, isFalse);
      expect(c.bowShotLanded, isTrue, reason: 'a kite shot is a landed shot');
      expect(c.tipText, contains('換另一弓兵走位'));
      var notes = 0;
      c.addListener(() => notes++);
      c.onBowKiteShot(mover: 1);
      expect(c.bowKiteTurns, 1, reason: 'the same bow moving again is no rotation');
      expect(c.bowKiteLanded, isFalse);
      expect(notes, 0);
      c.onBowKiteShot(mover: 4);
      expect(c.bowKiteTurns, 2);
      expect(c.bowKiteLanded, isTrue);
      expect(c.s2, S2Phase.bowTeach);
    });

    test('kite first, then siege and support clear in any order', () {
      final c = bowCoach();
      kite(c);
      expect(c.bowKiteLanded, isTrue);
      expect(c.tipText, contains('速派單一弓兵攻城'));
      c.onBowSupportShot();
      expect(c.s2, S2Phase.bowTeach);
      c.onBowSiegeLanded();
      expect(c.s2, S2Phase.returnCity);
    });

    test('攻城中 asks for the support bow until it has shot', () {
      final c = bowCoach()..onBowShot();
      c.onBowSieging();
      expect(c.tipText, contains('另一弓兵從後支援'));
      c.onBowSupportShot();
      c.onBowSieging();
      expect(c.tipText, isNot(contains('另一弓兵從後支援')));
      expect(c.tipText, contains('攻城中'));
    });

    test('the stage intro names all four 遠攻削敵 cues', () {
      final c = TutorialController()..resetToSession2();
      c.s2 = S2Phase.interceptHit;
      c.turnWindowOpen = true;
      c.facingCorrect = true;
      c.onAutoIntercept(facingWasCorrect: true);
      expect(c.s2, S2Phase.turnBack, reason: '更多的騎兵 before 遠攻削敵');
      c.onSpearAimedByMove();
      c.onTurnBackHit();
      expect(c.s2, S2Phase.bowTeach);
      expect(c.tipText, contains('停穩自動射'));
      expect(c.tipText, contains('速派單一弓兵攻城'));
      expect(c.tipText, contains('另一弓兵從後支援'));
      expect(c.tipText, contains('輪流走位牽制'));
    });

    test('selecting the bow after the shot keeps the siege tip', () {
      final c = bowCoach()..onBowShot();
      final tip = c.tipText;
      c.onSelectBow();
      expect(c.tipText, tip);
    });

    test('behind 章節選擇 neither beat counts', () {
      final c = bowCoach()..chapterSelectOpen = true;
      c.onBowShot();
      c.onBowSiegeLanded();
      c.onBowSupportShot();
      kite(c);
      expect(c.bowShotLanded, isFalse);
      expect(c.bowSiegeLanded, isFalse);
      expect(c.bowSupportLanded, isFalse);
      expect(c.bowKiteTurns, 0);
      expect(c.bowKiteLanded, isFalse);
      expect(c.s2, S2Phase.bowTeach);
    });

    test('a stage reset clears every beat', () {
      final c = bowCoach()
        ..onBowSupportShot()
        ..onBowSiegeLanded()
        ..onBowKiteShot(mover: 1);
      c.resetToSession2();
      expect(c.bowShotLanded, isFalse);
      expect(c.bowSiegeLanded, isFalse);
      expect(c.bowSupportLanded, isFalse);
      expect(c.bowKiteTurns, 0);
      expect(c.bowKiteLanded, isFalse);
    });
  });

  group('game loop', () {
    test('own bow on the enemy gate runs 攻城中, then the countdown lands the siege beat', () {
      final coach = bowCoach()..onBowShot();
      final g = readyGame(tutorial: coach);
      g.setupSession2Field();
      final bow = _ownBow(g);
      _clearEnemies(g);
      final castle = g.enemyCastle;
      _parkAt(g, bow, _enemyGate(g));

      g.debugStepPursuit(1 / 60);
      expect(g.debugSiegeCaption(bow), TaisenGame.kSiegingCaption);
      expect(g.debugSiegeFace(bow), 'gate');
      expect(coach.tipText, contains('攻城中'));
      expect(coach.s2, S2Phase.bowTeach);

      final guard = _stepUntil(g, () => coach.bowSiegeLanded);
      expect(coach.bowSiegeLanded, isTrue);
      expect(coach.s2, S2Phase.bowTeach, reason: 'no support shot yet');
      expect(coach.tipText, contains('另一弓兵從後支援'));
      expect(g.enemyCastle, closeTo(castle - TaisenGame.kSiegeGateNick, 1e-6));
      // Same fill rate as 攻城. No bow-only siege time.
      expect(guard / 60.0,
          closeTo(1 / TaisenGame.kSiegePrepFillPerSec, 2 / 60.0));
    });

    test('場2 seats a second own bow behind the first; slots keep their indices', () {
      final g = readyGame();
      g.setupSession2Field();
      expect(g.field[0].troop, TroopType.spear);
      expect(g.field[1].troop, TroopType.bow);
      expect(g.fieldIsEnemy.sublist(0, 4), [false, false, true, true]);
      expect(g.tutorialEnemyIndex, 2);
      const support = 4;
      // 槍擊退敵's reserve 騎兵 sits after the support bow.
      expect(g.debugTurnBackCavIndex, 5);
      expect(g.fieldIsEnemy[5], isTrue);
      expect(g.field[5].troop, TroopType.cavalry);
      expect(g.fieldIsEnemy[support], isFalse);
      expect(g.field[support].troop, TroopType.bow);
      expect(g.field[support].id, isNot(g.field[1].id));
      // Back rank: nearer the own castle than the first bow, outside its band.
      expect(g.fieldPos[support].dy, greaterThan(g.fieldPos[1].dy));
      expect(g.inCastleBand(g.fieldPos[support]), isFalse);
      expect(g.inEnemyCastleZone(support), isFalse);
    });

    test('two standing bows take turns instead of resetting each other', () {
      final g = readyGame();
      _bowField(g);
      _dropEnemy(g, 2); // the charging cavalry; the foot stays as the target
      final shooters = <int>{};
      _stepUntil(g, () {
        final a = g.debugBowAttackIndex;
        if (a != null) shooters.add(a);
        return shooters.length >= 2;
      }, max: 1200);
      expect(shooters, {1, 3}, reason: 'both own bows loose arrows');
    });

    test('one bow on the gate, the back-rank bow shoots: siege and support land', () {
      final coach = bowCoach();
      final g = readyGame(tutorial: coach);
      _bowField(g);
      _dropEnemy(g, 2); // the charging cavalry; the foot stays as the target
      const gateBow = 1;
      final supportBow = g.field.length - 1;
      _parkAt(g, gateBow, _enemyGate(g));
      g.selectedIndex = null;

      _stepUntil(g, () => coach.bowSupportLanded, max: 600);
      expect(coach.bowSupportLanded, isTrue);
      expect(coach.bowShotLanded, isTrue);
      expect(g.inEnemyCastleZone(supportBow), isFalse);

      _stepUntil(g, () => coach.bowSiegeLanded);
      expect(coach.bowSiegeLanded, isTrue);
      expect(coach.s2, S2Phase.bowTeach, reason: 'no 走位 turn yet');
      expect(coach.tipText, contains('輪流走位牽制'));
    });

    test('a shot while the other bow is on the move is a 走位 turn for the mover', () {
      final coach = bowCoach();
      final g = readyGame(tutorial: coach);
      _bowField(g);
      _dropEnemy(g, 2); // the charging cavalry; the foot stays as the target
      const front = 1;
      final back = g.field.length - 1;
      _moveBow(g, front);

      _stepUntil(g, () => coach.bowKiteTurns > 0, max: 600);
      expect(coach.bowKiteTurns, 1);
      expect(g.debugBowAttackIndex, back, reason: 'the standing bow looses');
      expect(coach.bowKiteLanded, isFalse);
      expect(coach.tipText, contains('換另一弓兵走位'));
    });

    test('輪流走位牽制: each bow moves while the other shoots, then 遠攻削敵 clears', () {
      final coach = bowCoach();
      final g = readyGame(tutorial: coach);
      _bowField(g);
      _dropEnemy(g, 2);
      const front = 1;
      final back = g.field.length - 1;

      // Turn one: the front bow repositions; the back-rank bow keeps shooting.
      _moveBow(g, front);
      _stepUntil(g, () => coach.bowKiteTurns == 1, max: 600);
      expect(coach.bowKiteTurns, 1);

      // Turn two: swap. The back-rank bow moves; the front bow shoots.
      _moveBow(g, back);
      _stepUntil(g, () => coach.bowKiteLanded, max: 600);
      expect(coach.bowKiteLanded, isTrue);
      expect(g.debugBowAttackIndex, front);
      expect(coach.s2, S2Phase.bowTeach, reason: 'siege and support still open');

      // The gate and support beats finish the stage.
      _parkAt(g, front, _enemyGate(g));
      g.selectedIndex = null;
      _stepUntil(g, () => coach.s2 != S2Phase.bowTeach, max: 900);
      expect(coach.bowSupportLanded, isTrue);
      expect(coach.bowSiegeLanded, isTrue);
      expect(coach.s2, S2Phase.returnCity);
    });

    test('a moving bow does not shoot, and a moving spear is no 走位 turn', () {
      final coach = bowCoach();
      final g = readyGame(tutorial: coach);
      _bowField(g);
      _dropEnemy(g, 2);
      final spear = g.tutorialOwnIndex!;
      expect(g.field[spear].troop, TroopType.spear);
      g.selectedIndex = spear;
      g.dragging = true;
      _stepUntil(g, () => false, max: 900);
      expect(coach.bowShotLanded, isTrue);
      expect(coach.bowKiteTurns, 0);

      // A bow held on the move never looses while it moves.
      final coach2 = bowCoach();
      final g2 = readyGame(tutorial: coach2);
      _bowField(g2);
      _dropEnemy(g2, 2);
      final back = g2.field.length - 1;
      _moveBow(g2, 1);
      final moverShots = <int>{};
      _stepUntil(g2, () {
        final a = g2.debugBowAttackIndex;
        if (a != null) moverShots.add(a);
        return false;
      }, max: 900);
      expect(moverShots, {back});
    });

    test('a shot with no own bow in the enemy castle is not the support beat', () {
      final coach = bowCoach();
      final g = readyGame(tutorial: coach);
      _bowField(g);
      _dropEnemy(g, 2);
      _stepUntil(g, () => coach.bowShotLanded, max: 600);
      expect(coach.bowShotLanded, isTrue);
      expect(coach.bowSupportLanded, isFalse);
      expect(coach.s2, S2Phase.bowTeach);
    });

    test('a spear in the enemy zone is not the siege beat', () {
      final coach = bowCoach()..onBowShot();
      final g = readyGame(tutorial: coach);
      _bowField(g);
      final spear = g.tutorialOwnIndex!;
      expect(g.field[spear].troop, TroopType.spear);
      _clearEnemies(g);
      _parkAt(g, spear, _enemyGate(g));
      _stepUntil(g, () => false, max: 360);
      expect(coach.bowSiegeLanded, isFalse);
      expect(coach.s2, S2Phase.bowTeach);
    });

    test('the siege beat waits for 開始 behind 章節選擇', () {
      final coach = bowCoach()
        ..onBowShot()
        ..chapterSelectOpen = true;
      final g = readyGame(tutorial: coach);
      _bowField(g);
      final bow = _ownBow(g);
      _clearEnemies(g);
      _parkAt(g, bow, _enemyGate(g));
      _stepUntil(g, () => false, max: 360);
      expect(coach.bowSiegeLanded, isFalse);
      expect(coach.s2, S2Phase.bowTeach);
    });

    test('outside the tutorial a bow siege still nicks and touches no coach', () {
      final g = readyGame();
      _bowField(g);
      final bow = _ownBow(g);
      _clearEnemies(g);
      final castle = g.enemyCastle;
      _parkAt(g, bow, _enemyGate(g));
      _stepUntil(g, () => g.enemyCastle < castle);
      expect(g.enemyCastle, closeTo(castle - TaisenGame.kSiegeGateNick, 1e-6));
    });
  });
}

int _ownBow(TaisenGame g) {
  for (var i = 0; i < g.field.length; i++) {
    if (!g.fieldIsEnemy[i] && g.field[i].troop == TroopType.bow) return i;
  }
  throw StateError('no own bow on the 場2 field');
}

/// 場2 as 遠攻削敵 finds it: the reserve 騎兵 was spent on 槍擊退敵's 回頭,
/// so the support bow is the last slot again.
void _bowField(TaisenGame g) {
  g.setupSession2Field();
  _dropEnemy(g, g.debugTurnBackCavIndex!);
}

void _dropEnemy(TaisenGame g, int i) {
  assert(g.fieldIsEnemy[i]);
  g.field.removeAt(i);
  g.fieldPos.removeAt(i);
  g.fieldIsEnemy.removeAt(i);
  g.fieldInCastle.removeAt(i);
}

/// Drop the enemy bodies so no shot, 亂戰, or opposing bow muddies the beat.
void _clearEnemies(TaisenGame g) {
  for (var i = g.field.length - 1; i >= 0; i--) {
    if (!g.fieldIsEnemy[i]) continue;
    g.field.removeAt(i);
    g.fieldPos.removeAt(i);
    g.fieldIsEnemy.removeAt(i);
    g.fieldInCastle.removeAt(i);
  }
}

Offset _enemyGate(TaisenGame g) {
  final zone = g.enemyCastleZoneRect;
  return Offset(zone.center.dx, zone.top + zone.height * 0.45);
}

void _parkAt(TaisenGame g, int i, Offset at) {
  g.fieldPos[i] = at;
  g.selectedIndex = i;
  g.dragging = false;
  g.dragTo = null;
}

/// Hold bow [i] on the move: selected and mid-drag, so it cannot 蓄勢.
void _moveBow(TaisenGame g, int i) {
  g.selectedIndex = i;
  g.dragging = true;
  g.dragTo = null;
}

int _stepUntil(TaisenGame g, bool Function() done, {int max = 600}) {
  var n = 0;
  while (!done() && n < max) {
    g.debugStepPursuit(1 / 60);
    n++;
  }
  return n;
}
