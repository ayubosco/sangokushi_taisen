import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/data/card_models.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';
import 'package:sangokushi_taisen/game/tutorial_controller.dart';

import 'feel_gates_test.dart' show readyGame;

/// Soft Lock 回城 rail, after 遠攻削敵 clears. Design lock (Bosco, castle band
/// note):「要知回城回血再出」. The step clears on that loop on one body:
/// 歸城 (park in 歸城區) → 回血 (back to full HP on the existing in-castle
/// heal) → 出陣 (drag out past the exit line and finish the existing 出城準備).
/// A touch on 歸城區 alone no longer clears it. No new heal rate, prep time,
/// or exit line. No enemy pursuit. Not a Feel Pass.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TutorialController returnCoach() {
    final c = TutorialController()..resetToSession2();
    c.interceptDone = true;
    c.s2 = S2Phase.returnCity;
    return c;
  }

  TutorialLessonGate gateOf(TutorialController c, String id) =>
      c.lessons.firstWhere((l) => l.id == id).gate;

  group('controller', () {
    test('歸城 alone keeps 回城 current and points at the heal', () {
      final c = returnCoach()..onReturnCity(1);
      expect(c.returnParked, isTrue);
      expect(c.returnBody, 1);
      expect(c.s2, S2Phase.returnCity);
      expect(gateOf(c, 'return'), TutorialLessonGate.current);
      expect(gateOf(c, 'strategy'), TutorialLessonGate.locked);
      expect(c.tipText, contains('回血'));
    });

    test('歸城 → 回血 → 出陣 on one body clears to 用計得宜', () {
      final c = returnCoach()..onReturnCity(1);
      c.onReturnHealed(1);
      expect(c.returnHealed, isTrue);
      expect(c.s2, S2Phase.returnCity, reason: '回血 still owes 出陣');
      expect(c.tipText, contains('出陣'));
      c.onReturnSortied(1);
      expect(c.s2, S2Phase.strategyTeach);
      expect(c.strategyOrReturnDone, isTrue);
      expect(gateOf(c, 'return'), TutorialLessonGate.done);
      expect(gateOf(c, 'strategy'), TutorialLessonGate.current);
    });

    test('出陣 before 回血 does not clear; leaving early drops back to 歸城', () {
      final c = returnCoach()..onReturnCity(1);
      c.onReturnSortied(1);
      expect(c.s2, S2Phase.returnCity);
      c.onReturnLeftCastle(1);
      expect(c.returnParked, isFalse);
      expect(c.returnBody, isNull);
      expect(c.tipText, contains('未回滿血'));
      // A heal on a body that is no longer parked is not the beat.
      c.onReturnHealed(1);
      expect(c.returnHealed, isFalse);
    });

    test('a healed body leaving the castle keeps the loop', () {
      final c = returnCoach()
        ..onReturnCity(1)
        ..onReturnHealed(1)
        ..onReturnLeftCastle(1);
      expect(c.returnHealed, isTrue);
      c.onReturnSortied(1);
      expect(c.s2, S2Phase.strategyTeach);
    });

    test('another body cannot finish the loop; the latest park takes it over',
        () {
      final c = returnCoach()
        ..onReturnCity(1)
        ..onReturnHealed(1);
      c.onReturnSortied(4);
      expect(c.s2, S2Phase.returnCity);
      c.onReturnCity(4);
      expect(c.returnBody, 4);
      expect(c.returnHealed, isFalse, reason: 'the new body owes its own 回血');
      c.onReturnHealed(1);
      expect(c.returnHealed, isFalse);
      c.onReturnHealed(4);
      c.onReturnSortied(4);
      expect(c.s2, S2Phase.strategyTeach);
    });

    test('beats outside 回城 do nothing; the session reset clears them', () {
      final bow = TutorialController()..resetToSession2();
      bow.interceptDone = true;
      bow.s2 = S2Phase.bowTeach;
      bow
        ..onReturnCity(1)
        ..onReturnHealed(1)
        ..onReturnSortied(1);
      expect(bow.returnParked, isFalse);
      expect(bow.s2, S2Phase.bowTeach);

      final c = returnCoach()
        ..onReturnCity(1)
        ..onReturnHealed(1);
      c.resetToSession2();
      expect(c.returnParked, isFalse);
      expect(c.returnHealed, isFalse);
      expect(c.returnBody, isNull);
    });

    test('shot either/or close still clears on the park alone', () {
      final c = TutorialController()..forceSession2Coach();
      c.onReturnCity(1);
      expect(c.s2, S2Phase.tipDone);
    });
  });

  group('live field', () {
    ({TaisenGame g, TutorialController c}) returnField() {
      final c = returnCoach();
      final g = readyGame(tutorial: c);
      g.setupSession2Field();
      return (g: g, c: c);
    }

    test('a wounded bow walks the full loop and opens 用計得宜', () {
      final f = returnField();
      final g = f.g, c = f.c;
      const i = 1;
      expect(g.field[i].troop, TroopType.bow);
      g.debugSetUnitHp(i, TaisenGame.kRansenMaxHp * 0.4);

      parkOwnBody(g, i);
      expect(g.fieldInCastle[i], isTrue);
      expect(c.returnParked, isTrue);
      expect(c.returnBody, i);
      expect(c.returnHealed, isFalse, reason: 'still wounded on arrival');
      expect(c.s2, S2Phase.returnCity, reason: 'a touch on 歸城區 is not 回城');

      // Heal on the existing in-castle path. The beat waits for a full bar.
      g.debugStepPursuit(0.1);
      expect(g.debugUnitHp(i), lessThan(TaisenGame.kRansenMaxHp));
      expect(c.returnHealed, isFalse);
      stepUntil(g, () => c.returnHealed);
      expect(c.returnHealed, isTrue);
      expect(g.debugUnitHp(i), TaisenGame.kRansenMaxHp);
      expect(c.s2, S2Phase.returnCity, reason: '回血 still owes 出陣');

      g.matchMorale = 0;
      sortieOwnBody(g, i);
      expect(g.debugSortiePrepVisible(i), isTrue);
      expect(g.fieldInCastle[i], isFalse);
      expect(c.s2, S2Phase.returnCity, reason: '出城準備 is still running');

      stepUntil(g, () => !g.debugSortiePrepVisible(i));
      expect(c.s2, S2Phase.strategyTeach);
      expect(c.lessons.firstWhere((l) => l.id == 'strategy').current, isTrue);
      expect(g.matchMorale, greaterThan(0),
          reason: '用計得宜 opens on the printed-cost lesson pool');
    });

    test('a wounded body sent out early drops back to 歸城 and must heal', () {
      final f = returnField();
      final g = f.g, c = f.c;
      const i = 1;
      g.debugSetUnitHp(i, TaisenGame.kRansenMaxHp * 0.2);
      parkOwnBody(g, i);
      expect(c.returnParked, isTrue);

      sortieOwnBody(g, i);
      expect(g.debugSortiePrepVisible(i), isTrue);
      expect(c.returnParked, isFalse);
      expect(c.tipText, contains('未回滿血'));
      stepUntil(g, () => !g.debugSortiePrepVisible(i));
      expect(c.s2, S2Phase.returnCity, reason: 'unhealed 出陣 does not clear');
    });

    test('a full-HP body still has to go back out; 歸城 alone holds the step',
        () {
      final f = returnField();
      final g = f.g, c = f.c;
      const i = 4;
      expect(g.debugUnitHp(i), TaisenGame.kRansenMaxHp);
      parkOwnBody(g, i);
      g.debugStepPursuit(1 / 30);
      expect(c.returnHealed, isTrue, reason: 'already full: 回血 lands on park');
      for (var n = 0; n < 120; n++) {
        g.debugStepPursuit(1 / 30);
      }
      expect(c.s2, S2Phase.returnCity, reason: 'parked forever is not 出陣');
      sortieOwnBody(g, i);
      stepUntil(g, () => !g.debugSortiePrepVisible(i));
      expect(c.s2, S2Phase.strategyTeach);
    });
  });
}

Offset _gateDrop(TaisenGame g) {
  final band = g.castleBandRect;
  return Offset(band.center.dx, band.top + band.height * 0.8);
}

void stepUntil(TaisenGame g, bool Function() until, {int guard = 1200}) {
  var n = 0;
  while (!until() && n++ < guard) {
    g.debugStepPursuit(1 / 30);
  }
}

/// Drag own body [i] into 歸城區 and let it march until it parks.
void parkOwnBody(TaisenGame g, int i) {
  final drop = _gateDrop(g);
  g.panStart(g.tokenCenter(i));
  g.panUpdate(drop);
  g.panEnd(drop);
  stepUntil(g, () => g.fieldInCastle.length > i && g.fieldInCastle[i]);
}

/// Drag a parked body out past the exit line; finger stays down until
/// 出城準備 starts, as in the gate deploy flow.
void sortieOwnBody(TaisenGame g, int i) {
  final from = g.tokenCenter(i);
  final out = Offset(from.dx, g.castleBandRect.top - 160);
  g.panStart(from);
  g.panUpdate(out);
  stepUntil(g, () => g.debugSortiePrepVisible(i));
  g.panEnd(out);
}

/// 歸城 → 回血 → 出陣 on own body [i] through the live gestures.
void walkReturnLoop(TaisenGame g, int i) {
  parkOwnBody(g, i);
  stepUntil(g, () => g.debugUnitHp(i) >= TaisenGame.kRansenMaxHp);
  sortieOwnBody(g, i);
  stepUntil(g, () => !g.debugSortiePrepVisible(i));
}
