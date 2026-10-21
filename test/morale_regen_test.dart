import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/game/c_clock.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';
import 'package:sangokushi_taisen/game/tutorial_controller.dart';

import 'feel_gates_test.dart' show readyGame;

/// AUTH-GAP §4: 「士氣值會隨時間回復」. Locks existence only. The rate is an
/// Adapted stub, not the foil ~6→~2 still and not a teaching-card 6/2.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// One regen point, in seconds of the C clock.
  const pointSec = TaisenGame.kMoraleRegenCPerPoint * CClock.secondsPerC;

  TaisenGame castOnce({TutorialController? tutorial}) {
    final g = readyGame(tutorial: tutorial);
    g.setupSession2Field();
    final inside = g.strategyPreviewCenter! + Offset(g.strategyPreviewRadius * 0.3, 0);
    expect(g.castStrategyOnMap(inside), isTrue);
    return g;
  }

  test('seed path is unchanged and sets the regen ceiling', () {
    final g = readyGame();
    g.setupSession2Field();
    final printed = g.field[0].strategyMorale + g.field[1].strategyMorale;
    expect(g.matchMorale, printed);
    expect(g.matchMoraleCap, printed);
  });

  test('士氣 recovers over time after a cast spend', () {
    final g = castOnce();
    final cap = g.matchMoraleCap;
    final spent = g.matchMorale;
    expect(spent, lessThan(cap));

    g.debugAdvanceMoraleRegen(pointSec * 0.5);
    expect(g.matchMorale, spent, reason: 'a partial point does not round up');
    g.debugAdvanceMoraleRegen(pointSec * 0.5 + 0.001);
    expect(g.matchMorale, spent + 1);
  });

  test('the frame loop drives regen', () {
    final g = castOnce();
    final spent = g.matchMorale;
    for (var t = 0.0; t < pointSec + 0.1; t += 1 / 60) {
      g.update(1 / 60);
    }
    expect(g.matchMorale, greaterThan(spent));
  });

  test('regen stops at the printed-cost ceiling', () {
    final g = castOnce();
    final cap = g.matchMoraleCap;
    g.debugAdvanceMoraleRegen(pointSec * (cap + 5));
    expect(g.matchMorale, cap);
    g.debugAdvanceMoraleRegen(pointSec * 3);
    expect(g.matchMorale, cap, reason: 'a full pool does not bank time');
  });

  test('regen holds while the C clock is stopped and in shot modes', () {
    final paused = castOnce();
    final pool = paused.matchMorale;
    paused.clock.pause();
    paused.debugAdvanceMoraleRegen(pointSec * 4);
    expect(paused.matchMorale, pool);

    final coach = TutorialController()..shotPassMode = true;
    final shot = castOnce(tutorial: coach);
    final shotPool = shot.matchMorale;
    shot.debugAdvanceMoraleRegen(pointSec * 4);
    expect(shot.matchMorale, shotPool);
  });

  test('no seed means no regen', () {
    final g = readyGame();
    expect(g.matchMoraleCap, 0);
    g.debugAdvanceMoraleRegen(pointSec * 4);
    expect(g.matchMorale, 0);
  });

  test('the rate stays an Adapted stub, not a foil readout', () {
    // The ~6→~2 still is one cast, not a rate. 3450 is not a morale figure.
    expect(TaisenGame.kMoraleRegenCPerPoint, 3.0);
    expect(TaisenGame.kRetreatMoraleCost, 0);
  });
}
