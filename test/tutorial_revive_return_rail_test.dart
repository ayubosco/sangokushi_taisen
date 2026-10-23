import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';
import 'package:sangokushi_taisen/game/tutorial_controller.dart';
import 'package:sangokushi_taisen/game/unit_life.dart';

import 'feel_gates_test.dart' show readyGame;
import 'tutorial_return_rail_test.dart'
    show parkOwnBody, sortieOwnBody, stepUntil;

/// Soft Lock revive-path 回城, after the living 歸城 → 回血 → 出陣 rail (#37).
/// A retreated body that enters 己城 is the 歸城 beat. The existing revive
/// countdown refills HP, so its end is the 回血 beat. The existing 出城準備
/// is 出陣. No new heal rate, revive time, prep time, or exit line. No enemy
/// pursuit. Not a Feel Pass.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TutorialController returnCoach() {
    final c = TutorialController()..resetToSession2();
    c.interceptDone = true;
    c.s2 = S2Phase.returnCity;
    return c;
  }

  group('controller', () {
    test('revive 歸城 starts the loop and points at the countdown', () {
      final c = returnCoach()..onReturnReviving(2);
      expect(c.returnParked, isTrue);
      expect(c.returnBody, 2);
      expect(c.returnHealed, isFalse);
      expect(c.s2, S2Phase.returnCity);
      expect(c.tipText, contains('復活'));
      c
        ..onReturnHealed(2)
        ..onReturnSortied(2);
      expect(c.s2, S2Phase.strategyTeach);
    });

    test('revive 歸城 does nothing outside 回城 or on the shot either/or', () {
      final bow = TutorialController()..resetToSession2();
      bow.interceptDone = true;
      bow.s2 = S2Phase.bowTeach;
      bow.onReturnReviving(1);
      expect(bow.returnParked, isFalse);

      final shot = TutorialController()..forceSession2Coach();
      shot.onReturnReviving(1);
      expect(shot.s2, S2Phase.strategyOrReturn,
          reason: 'only a living park closes the shot either/or');
    });

    test('a living park and a revive take the loop over from each other', () {
      final c = returnCoach()..onReturnCity(1);
      c.onReturnReviving(3);
      expect(c.returnBody, 3);
      c.onReturnHealed(1);
      expect(c.returnHealed, isFalse);
      c.onReturnCity(1);
      expect(c.returnBody, 1);
      c.onReturnHealed(3);
      expect(c.returnHealed, isFalse);
    });
  });

  group('live field', () {
    ({TaisenGame g, TutorialController c}) returnField() {
      final c = returnCoach();
      final g = readyGame(tutorial: c);
      g.setupSession2Field();
      return (g: g, c: c);
    }

    test('a retreated bow revives in castle and drives the rail to 用計得宜',
        () {
      final f = returnField();
      final g = f.g, c = f.c;
      const i = 1;
      g.debugForceHpZero(i);
      expect(g.debugUnitLife(i), UnitLife.retreating);
      final revive = g.debugReviveLeft(i);
      expect(revive, greaterThan(0));

      parkOwnBody(g, i);
      expect(g.debugUnitLife(i), UnitLife.inCastleReviving);
      expect(c.returnParked, isTrue);
      expect(c.returnBody, i);
      expect(c.returnHealed, isFalse);
      expect(c.tipText, contains('復活'));

      // The existing countdown is the heal. 回血 waits for it to end.
      g.debugStepPursuit(1.0);
      expect(g.debugReviveLeft(i), lessThan(revive));
      expect(c.returnHealed, isFalse);
      stepUntil(g, () => c.returnHealed, guard: 3000);
      expect(g.debugUnitLife(i), UnitLife.readyRedeploy);
      expect(g.debugUnitHp(i), TaisenGame.kRansenMaxHp);
      expect(c.s2, S2Phase.returnCity, reason: 'revived still owes 出陣');

      g.matchMorale = 0;
      sortieOwnBody(g, i);
      expect(g.debugSortiePrepVisible(i), isTrue);
      expect(c.s2, S2Phase.returnCity, reason: '出城準備 is still running');
      stepUntil(g, () => !g.debugSortiePrepVisible(i));
      expect(g.debugUnitLife(i), UnitLife.alive);
      expect(c.s2, S2Phase.strategyTeach);
      expect(g.matchMorale, greaterThan(0),
          reason: '用計得宜 opens on the printed-cost lesson pool');
    });

    test('a reviving body sent out early drops the loop; re-entry restarts it',
        () {
      final f = returnField();
      final g = f.g, c = f.c;
      const i = 1;
      g.debugForceHpZero(i);
      parkOwnBody(g, i);
      expect(c.returnParked, isTrue);

      sortieOwnBody(g, i);
      expect(c.returnParked, isFalse);
      expect(c.tipText, contains('未回滿血'));
      stepUntil(g, () => !g.debugSortiePrepVisible(i));
      expect(g.debugUnitLife(i), UnitLife.inCastleReviving,
          reason: 'leaving does not finish the revive');
      expect(c.s2, S2Phase.returnCity);

      parkOwnBody(g, i);
      expect(c.returnParked, isTrue, reason: 'entering 己城 again is 歸城');
      expect(c.returnBody, i);
      stepUntil(g, () => c.returnHealed, guard: 3000);
      sortieOwnBody(g, i);
      stepUntil(g, () => !g.debugSortiePrepVisible(i));
      expect(c.s2, S2Phase.strategyTeach);
    });

    test('a body reviving in castle does not steal a later living park', () {
      final f = returnField();
      final g = f.g, c = f.c;
      g.debugForceHpZero(1);
      parkOwnBody(g, 1);
      expect(c.returnBody, 1);

      parkOwnBody(g, 4);
      expect(c.returnBody, 4);
      for (var n = 0; n < 60; n++) {
        g.debugStepPursuit(1 / 30);
      }
      expect(c.returnBody, 4, reason: 'revive 歸城 fires on entry only');
      stepUntil(g, () => g.debugUnitLife(1) == UnitLife.readyRedeploy,
          guard: 3000);
      expect(c.returnBody, 4);
      sortieOwnBody(g, 1);
      stepUntil(g, () => !g.debugSortiePrepVisible(1));
      expect(c.s2, S2Phase.returnCity, reason: 'body 1 lost the loop');
    });
  });
}
