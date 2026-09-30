import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/data/card_models.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';
import 'package:sangokushi_taisen/game/unit_life.dart';

import 'feel_gates_test.dart' show readyGame;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('locked revive constants: 15s base, 活 ×2/3, morale cost 0', () {
    expect(TaisenGame.kReviveBaseSec, 15);
    expect(TaisenGame.kReviveSkillMul, closeTo(2 / 3, 1e-9));
    expect(TaisenGame.kRetreatMoraleCost, 0);
    expect(TaisenGame.kRetreatSplashSec, lessThanOrEqualTo(1));
    expect(
      reviveSeconds(skilled: false, baseSec: TaisenGame.kReviveBaseSec, skillMul: TaisenGame.kReviveSkillMul),
      15,
    );
    expect(
      reviveSeconds(skilled: true, baseSec: TaisenGame.kReviveBaseSec, skillMul: TaisenGame.kReviveSkillMul),
      closeTo(10, 0.001),
    );
  });

  test('HP 0 retreats, countdown stays frozen outside the castle', () {
    final g = readyGame();
    final at = Offset(g.size.x * 0.40, g.watchH + g.fieldH * 0.45);
    _place(g, 'zhaoyun', at);
    g.matchMorale = 5;
    g.debugForceHpZero(0);

    expect(g.debugUnitLife(0), UnitLife.retreating);
    expect(g.debugUnitHp(0), 0);
    expect(g.debugShowsSkull(0), isTrue);
    expect(g.debugHitLabel, '撤退');
    expect(g.debugLifeTipAt(0), '散咗拖返城先復活');
    expect(g.matchMorale, 5);
    expect(g.debugReviveLeft(0), closeTo(15, 0.001));
    expect(g.dragTo, isNull);

    g.debugStepPursuit(3);
    expect(g.debugUnitLife(0), UnitLife.retreating);
    expect(g.debugReviveLeft(0), closeTo(15, 0.001));
    expect(g.debugShowsSkull(0), isTrue);
  });

  test('castle band runs the countdown, then the body can march out', () {
    final g = readyGame();
    final at = Offset(g.size.x * 0.40, g.watchH + g.fieldH * 0.45);
    _place(g, 'zhaoyun', at);
    g.debugForceHpZero(0);
    final frozen = g.debugReviveLeft(0);

    final band = g.castleBandRect;
    g.fieldPos[0] = Offset(band.center.dx, band.top + band.height * 0.5);
    g.debugStepPursuit(1);
    expect(g.debugUnitLife(0), UnitLife.inCastleReviving);
    expect(g.debugReviveLeft(0), closeTo(frozen - 1, 0.05));
    expect(g.debugShowsSkull(0), isTrue);
    expect(g.debugHitLabel, isNot('復活'));

    final left = g.debugReviveLeft(0);
    g.debugStepPursuit(left);
    expect(g.debugUnitLife(0), UnitLife.readyRedeploy);
    expect(g.debugUnitHp(0), TaisenGame.kRansenMaxHp);
    expect(g.debugReviveLeft(0), 0);

    final body = g.tokenCenter(0);
    final out = Offset(body.dx, band.top - 90);
    g.panStart(body);
    g.panEnd(out);
    expect(g.dragTo, isNotNull, reason: 'ready body keeps the waypoint out of 己城');
    var guard = 0;
    while (g.debugUnitLife(0) != UnitLife.alive && guard < 700) {
      g.debugStepPursuit(1 / 60);
      guard++;
    }
    expect(g.debugUnitLife(0), UnitLife.alive);
    expect(g.debugShowsSkull(0), isFalse);
    expect(g.debugUnitHp(0), TaisenGame.kRansenMaxHp);
  });

  test('活 shortens the frozen countdown; a card without it stays at 15s', () {
    final skilled = readyGame();
    _place(skilled, 'liubei', Offset(skilled.size.x * 0.4, skilled.watchH + 200));
    skilled.debugForceHpZero(0);
    expect(skilled.debugReviveLeft(0), closeTo(10, 0.001));

    final plain = readyGame();
    _place(plain, 'zhaoyun', Offset(plain.size.x * 0.4, plain.watchH + 200));
    plain.debugForceHpZero(0);
    expect(plain.debugReviveLeft(0), closeTo(15, 0.001));
  });

  test('alive return heals in castle with no skull and no revive bell', () {
    final g = readyGame();
    final band = g.castleBandRect;
    final at = Offset(band.center.dx, band.top + band.height * 0.4);
    _place(g, 'zhaoyun', at);
    g.debugSetUnitHp(0, 40);
    g.panStart(at);
    g.panEnd(at);

    expect(g.fieldInCastle[0], isTrue);
    expect(g.debugUnitLife(0), UnitLife.alive);
    expect(g.debugShowsSkull(0), isFalse);
    expect(g.debugHitLabel, isNot('復活'));
    expect(g.debugHitLabel, isNot('撤退'));
    expect(g.debugLifeTipAt(0), '返城回血');
    expect(g.debugReviveLeft(0), 0);

    g.debugStepPursuit(1);
    expect(g.debugUnitHp(0), closeTo(46, 0.05));
    expect(g.debugUnitLife(0), UnitLife.alive);
    expect(g.debugShowsSkull(0), isFalse);
    expect(g.debugReviveLeft(0), 0);
  });
}

void _place(TaisenGame g, String id, Offset at) {
  final card = Cost6Roster.all.firstWhere((c) => c.id == id);
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
  g.dragTo = null;
  g.dragging = false;
}
