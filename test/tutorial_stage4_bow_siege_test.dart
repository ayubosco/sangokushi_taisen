import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/data/card_models.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';
import 'package:sangokushi_taisen/game/tutorial_controller.dart';

import 'feel_gates_test.dart' show readyGame;

/// 英傑 stage 4 遠攻削敵 lesson flow. Observed-from-英傑 (AUTH-GAP §3): the
/// stage cues are「速派單一弓兵攻城」— one archer on the enemy gate shows
/// 「攻城中」+ countdown — and「另一弓兵從後支援」— a second archer shoots from
/// the back rank while the first holds the gate. The lesson clears on a
/// standing shot, that siege beat, and the support shot, in any order. The
/// siege reuses the existing gauge, fill rate, and gate nick; the support shot
/// reuses the existing standing shot and range. No bow number is invented.
/// Not a Feel Pass.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TutorialController bowCoach() {
    final c = TutorialController()..resetToSession2();
    c.interceptDone = true;
    c.s2 = S2Phase.bowTeach;
    return c;
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

    test('shot then siege waits for 另一弓兵從後支援, then clears to 回城', () {
      final c = bowCoach()
        ..onBowShot()
        ..onBowSiegeLanded();
      expect(c.s2, S2Phase.bowTeach);
      expect(c.tipText, contains('另一弓兵從後支援'));
      c.onBowSupportShot();
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
      expect(c.s2, S2Phase.returnCity);
    });

    test('support then siege clears; the support shot also counts as the shot', () {
      final c = bowCoach()..onBowSupportShot();
      expect(c.bowShotLanded, isTrue);
      expect(c.bowSupportLanded, isTrue);
      expect(c.s2, S2Phase.bowTeach);
      expect(c.tipText, contains('攻城中'));
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

    test('the stage intro names all three 遠攻削敵 cues', () {
      final c = TutorialController()..resetToSession2();
      c.s2 = S2Phase.interceptHit;
      c.turnWindowOpen = true;
      c.facingCorrect = true;
      c.onAutoIntercept(facingWasCorrect: true);
      expect(c.s2, S2Phase.bowTeach);
      expect(c.tipText, contains('停穩自動射'));
      expect(c.tipText, contains('速派單一弓兵攻城'));
      expect(c.tipText, contains('另一弓兵從後支援'));
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
      expect(c.bowShotLanded, isFalse);
      expect(c.bowSiegeLanded, isFalse);
      expect(c.bowSupportLanded, isFalse);
      expect(c.s2, S2Phase.bowTeach);
    });

    test('a stage reset clears both beats', () {
      final c = bowCoach()
        ..onBowSupportShot()
        ..onBowSiegeLanded();
      c.resetToSession2();
      expect(c.bowShotLanded, isFalse);
      expect(c.bowSiegeLanded, isFalse);
      expect(c.bowSupportLanded, isFalse);
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
      final support = g.field.length - 1;
      expect(support, 4);
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
      g.setupSession2Field();
      _dropEnemy(g, 2); // the charging cavalry; the foot stays as the target
      final shooters = <int>{};
      _stepUntil(g, () {
        final a = g.debugBowAttackIndex;
        if (a != null) shooters.add(a);
        return shooters.length >= 2;
      }, max: 1200);
      expect(shooters, {1, 3}, reason: 'both own bows loose arrows');
    });

    test('one bow on the gate, the back-rank bow shoots: 遠攻削敵 clears', () {
      final coach = bowCoach();
      final g = readyGame(tutorial: coach);
      g.setupSession2Field();
      _dropEnemy(g, 2); // the charging cavalry; the foot stays as the target
      const gateBow = 1;
      final supportBow = g.field.length - 1;
      _parkAt(g, gateBow, _enemyGate(g));
      g.selectedIndex = null;

      _stepUntil(g, () => coach.bowSupportLanded, max: 600);
      expect(coach.bowSupportLanded, isTrue);
      expect(coach.bowShotLanded, isTrue);
      expect(g.inEnemyCastleZone(supportBow), isFalse);

      _stepUntil(g, () => coach.s2 != S2Phase.bowTeach);
      expect(coach.bowSiegeLanded, isTrue);
      expect(coach.s2, S2Phase.returnCity);
    });

    test('a shot with no own bow in the enemy castle is not the support beat', () {
      final coach = bowCoach();
      final g = readyGame(tutorial: coach);
      g.setupSession2Field();
      _dropEnemy(g, 2);
      _stepUntil(g, () => coach.bowShotLanded, max: 600);
      expect(coach.bowShotLanded, isTrue);
      expect(coach.bowSupportLanded, isFalse);
      expect(coach.s2, S2Phase.bowTeach);
    });

    test('a spear in the enemy zone is not the siege beat', () {
      final coach = bowCoach()..onBowShot();
      final g = readyGame(tutorial: coach);
      g.setupSession2Field();
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
      g.setupSession2Field();
      final bow = _ownBow(g);
      _clearEnemies(g);
      _parkAt(g, bow, _enemyGate(g));
      _stepUntil(g, () => false, max: 360);
      expect(coach.bowSiegeLanded, isFalse);
      expect(coach.s2, S2Phase.bowTeach);
    });

    test('outside the tutorial a bow siege still nicks and touches no coach', () {
      final g = readyGame();
      g.setupSession2Field();
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

int _stepUntil(TaisenGame g, bool Function() done, {int max = 600}) {
  var n = 0;
  while (!done() && n < max) {
    g.debugStepPursuit(1 / 60);
    n++;
  }
  return n;
}
