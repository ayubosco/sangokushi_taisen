import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';
import 'package:sangokushi_taisen/game/unit_life.dart';

import 'feel_gates_test.dart' show readyGame;

/// Enemy pursuit / chase AI (Soft Lock leftover). An enemy that met an own
/// body in 亂戰 walks after it once contact breaks: it trails while the target
/// marches and closes back into 亂戰 when it stops. No new speed or reach.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const dt = 1 / 60;

  /// Own [ownId] stacked on enemy [enemyId] so the first step pairs them in 亂戰.
  TaisenGame engaged({required String ownId, required String enemyId}) {
    final g = readyGame();
    final at = Offset(g.size.x * 0.50, g.watchH + g.fieldH * 0.40);
    g.debugRestageOwnEnemy(ownId: ownId, ownAt: at, enemyAt: at, enemyId: enemyId);
    g.debugStepPursuit(dt);
    expect(g.debugInRansen(0), isTrue);
    expect(g.debugPursuitTargetOf(1), 0);
    return g;
  }

  void marchOwnTo(TaisenGame g, Offset to) {
    g.panStart(g.tokenCenter(0));
    g.panUpdate(to);
    g.panEnd(to);
  }

  double gap(TaisenGame g) => (g.tokenCenter(0) - g.tokenCenter(1)).distance;

  test('an enemy that never met an own body stays put', () {
    final g = readyGame();
    final at = Offset(g.size.x * 0.30, g.watchH + g.fieldH * 0.40);
    final foe = at + const Offset(160, -120);
    g.debugRestageOwnEnemy(ownId: 'zhangliang', ownAt: at, enemyAt: foe);
    marchOwnTo(g, at + const Offset(0, 120));
    for (var i = 0; i < 120; i++) {
      g.debugStepPursuit(dt);
    }
    expect(g.debugPursuitTargetOf(1), isNull);
    expect(g.tokenCenter(1), foe);
  });

  test('a peeling body is trailed outside contact, then caught when it stops', () {
    // Enemy 騎 (wiki 1.1) after own 歩 (0.9): faster, so it keeps up.
    final g = engaged(ownId: 'zhangliang', enemyId: 'caocao');
    final start = g.tokenCenter(1);
    marchOwnTo(g, g.tokenCenter(0) + const Offset(0, 200));
    var steps = 0;
    var peeled = false;
    while (g.dragTo != null && steps < 600) {
      g.debugStepPursuit(dt);
      steps++;
      if (!g.debugInRansen(0)) peeled = true;
      if (peeled) {
        // The drag can always leave: no re-pair while the target marches.
        expect(g.debugInRansen(0), isFalse, reason: 'step $steps');
        expect(gap(g), lessThanOrEqualTo(g.meleeContactDist + TaisenGame.kArrivalEpsilon + 0.01));
      }
    }
    expect(peeled, isTrue);
    expect(g.dragTo, isNull);
    expect((g.tokenCenter(1) - start).distance, greaterThan(150), reason: 'the enemy followed');

    for (var i = 0; i < 30 && !g.debugInRansen(0); i++) {
      g.debugStepPursuit(dt);
    }
    expect(g.debugInRansen(0), isTrue, reason: 'stopped target is caught');
    expect(g.debugInRansen(1), isTrue);
    expect(g.debugPursuitTargetOf(1), 0);
  });

  test('the chase walks at the existing wiki speed and faces its travel', () {
    final g = engaged(ownId: 'zhaoyun', enemyId: 'zhangliang');
    marchOwnTo(g, g.tokenCenter(0) + const Offset(0, 220));
    while (g.debugInRansen(0)) {
      g.debugStepPursuit(dt);
    }
    // A few open steps so the 騎 opens a gap the 歩 has to walk.
    for (var i = 0; i < 10; i++) {
      g.debugStepPursuit(dt);
    }
    final before = g.tokenCenter(1);
    final speed = g.debugWorldSpeedPx(1);
    g.debugStepPursuit(dt);
    final moved = g.tokenCenter(1) - before;
    expect(moved.distance, closeTo(speed * dt, 1e-6));
    expect(moved.dy, greaterThan(0), reason: 'toward the own body below');
    expect(g.tipFacingAt(1), closeTo(math.pi, 0.2), reason: 'faces down-field');
  });

  test('a faster body outruns the chase while it marches', () {
    // Own 騎 (1.1) away from enemy 歩 (0.9).
    final g = engaged(ownId: 'zhaoyun', enemyId: 'zhangliang');
    marchOwnTo(g, g.tokenCenter(0) + const Offset(0, 260));
    while (g.debugInRansen(0)) {
      g.debugStepPursuit(dt);
    }
    final early = gap(g);
    for (var i = 0; i < 60 && g.dragTo != null; i++) {
      g.debugStepPursuit(dt);
    }
    expect(gap(g), greaterThan(early + 10));
    expect(g.debugPursuitTargetOf(1), 0, reason: 'still chasing, just slower');
  });

  test('歸城 drops the chase; the enemy does not follow into the own castle', () {
    final g = engaged(ownId: 'zhangliang', enemyId: 'caocao');
    final band = g.castleBandRect;
    final home = g.clampPlayableCenter(
      Offset(g.tokenCenter(0).dx, band.top + band.height * TaisenGame.kCastleEnterDepth),
    );
    marchOwnTo(g, home);
    for (var i = 0; i < 60 * 20 && g.debugPursuitTargetOf(1) != null; i++) {
      g.debugStepPursuit(dt);
    }
    expect(g.debugPursuitTargetOf(1), isNull);
    expect(g.inCastleBand(g.tokenCenter(0)), isTrue);
    final parked = g.tokenCenter(1);
    for (var i = 0; i < 120; i++) {
      g.debugStepPursuit(dt);
    }
    expect(g.tokenCenter(1), parked);
    expect(g.inCastleBand(parked), isFalse);
  });

  test('a routed target drops the chase', () {
    final g = engaged(ownId: 'zhangliang', enemyId: 'caocao');
    marchOwnTo(g, g.tokenCenter(0) + const Offset(0, 200));
    while (g.debugInRansen(0)) {
      g.debugStepPursuit(dt);
    }
    g.debugForceHpZero(0);
    g.debugStepPursuit(dt);
    expect(g.debugUnitLife(0), isNot(UnitLife.alive));
    expect(g.debugPursuitTargetOf(1), isNull);
    final held = g.tokenCenter(1);
    for (var i = 0; i < 60; i++) {
      g.debugStepPursuit(dt);
    }
    expect(g.tokenCenter(1), held);
  });

  test('the 迎擊 lane cavalry keeps its lane and never pursues', () {
    final g = engaged(ownId: 'zhangliang', enemyId: 'caocao');
    g.debugArmEnemyChargeAura();
    expect(g.debugChargingEnemyIndex, 1);
    final held = g.tokenCenter(1);
    marchOwnTo(g, g.tokenCenter(0) + const Offset(0, 200));
    for (var i = 0; i < 120; i++) {
      g.debugStepPursuit(dt);
    }
    expect(g.tokenCenter(1), held, reason: 'no spear lane, and no pursuit either');
  });

  test('a bow that brushed the enemy on its march is caught and holds its shot', () {
    // feel_soft_lock_test's old line: the march passes 30px off the enemy.
    final g = readyGame();
    final at = Offset(g.size.x * 0.34, g.watchH + g.fieldH * 0.40);
    g.debugRestageOwnEnemy(ownId: 'sunquan', ownAt: at, enemyAt: at + const Offset(100, -30));
    g.panStart(at);
    g.panUpdate(at + const Offset(180, 0));
    for (var i = 0; i < 60; i++) {
      g.debugStepPursuit(dt);
    }
    expect(g.debugPursuitTargetOf(1), 0, reason: 'the brush was 亂戰 contact');
    g.panEnd(at + const Offset(40, 0));
    for (var i = 0; i < 300 && g.dragTo != null; i++) {
      g.debugStepPursuit(dt);
    }
    var caught = false;
    for (var i = 0; i < 400; i++) {
      g.debugStepPursuit(dt);
      if (g.debugInRansen(0)) caught = true;
      expect(g.debugHitLabel, isNot('射'), reason: 'step $i');
    }
    expect(caught, isTrue);
  });

  test('a fresh field clears the chase', () {
    final g = engaged(ownId: 'zhangliang', enemyId: 'caocao');
    final at = Offset(g.size.x * 0.30, g.watchH + g.fieldH * 0.40);
    final foe = at + const Offset(160, -120);
    g.debugRestageOwnEnemy(ownId: 'zhangliang', ownAt: at, enemyAt: foe);
    expect(g.debugPursuitTargetOf(1), isNull);
    marchOwnTo(g, at + const Offset(0, 120));
    for (var i = 0; i < 60; i++) {
      g.debugStepPursuit(dt);
    }
    expect(g.tokenCenter(1), foe);
  });
}
