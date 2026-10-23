import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/data/card_models.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';
import 'package:sangokushi_taisen/game/tutorial_controller.dart';

import 'feel_gates_test.dart' show readyGame;

/// 英傑 stage 4 遠攻削敵 lesson flow. Observed-from-英傑 (AUTH-GAP §3): the
/// stage cue is「速派單一弓兵攻城」— one archer on the enemy gate shows
/// 「攻城中」+ countdown. The lesson clears on a standing shot plus that siege
/// beat, in either order. The siege reuses the existing gauge, fill rate, and
/// gate nick. No bow siege number is invented. Not a Feel Pass.
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

    test('shot then siege clears to 回城', () {
      final c = bowCoach()
        ..onBowShot()
        ..onBowSiegeLanded();
      expect(c.s2, S2Phase.returnCity);
      expect(c.lessons.firstWhere((l) => l.id == 'bow').gate,
          TutorialLessonGate.done);
    });

    test('siege then shot also clears; either beat alone does not', () {
      final c = bowCoach()..onBowSiegeLanded();
      expect(c.s2, S2Phase.bowTeach);
      expect(c.tipText, contains('射'));
      c.onBowShot();
      expect(c.s2, S2Phase.returnCity);
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
      expect(c.bowShotLanded, isFalse);
      expect(c.bowSiegeLanded, isFalse);
      expect(c.s2, S2Phase.bowTeach);
    });

    test('a stage reset clears both beats', () {
      final c = bowCoach()
        ..onBowShot()
        ..onBowSiegeLanded();
      c.resetToSession2();
      expect(c.bowShotLanded, isFalse);
      expect(c.bowSiegeLanded, isFalse);
    });
  });

  group('game loop', () {
    test('own bow on the enemy gate runs 攻城中, then the countdown clears the stage', () {
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

      final guard = _stepUntil(g, () => coach.s2 != S2Phase.bowTeach);
      expect(coach.s2, S2Phase.returnCity);
      expect(coach.bowSiegeLanded, isTrue);
      expect(g.enemyCastle, closeTo(castle - TaisenGame.kSiegeGateNick, 1e-6));
      // Same fill rate as 攻城. No bow-only siege time.
      expect(guard / 60.0,
          closeTo(1 / TaisenGame.kSiegePrepFillPerSec, 2 / 60.0));
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
