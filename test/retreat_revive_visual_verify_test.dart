import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/game/retreat_revive_visual_verify.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';
import 'package:sangokushi_taisen/game/unit_life.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('RETREAT_REVIVE_VISUAL_VERIFY is off unless the dart-define is set', () {
    expect(kRetreatReviveVisualVerify, isFalse);
  });

  test('free-match sequence hits frozen retreat, castle tick, redeploy, alive heal', () async {
    final g = TaisenGame();
    g.onGameResize(Vector2(390, 844));
    expect(g.tutorial, isNull);

    final shots = <RetreatReviveVisualShot>[];
    final script = RetreatReviveVisualVerify(
      game: g,
      step: () async {
        g.debugStepPursuit(1 / 60);
      },
      hold: (shot) async {
        shots.add(shot);
      },
    );
    await script.run();

    expect(shots.map((s) => s.id).toList(), ['R1', 'R2', 'R3', 'R4']);
    for (final shot in shots) {
      expect(shot.pass, isTrue, reason: '${shot.id} ${shot.caption} life=${shot.life} splash=${shot.splash}');
    }

    final frozen = shots[0];
    expect(frozen.life, UnitLife.retreating);
    expect(frozen.skull, isTrue);
    expect(frozen.splash, '撤退');
    expect(frozen.hp, 0);
    expect(frozen.reviveLeft, closeTo(frozen.reviveMark, 0.05));
    expect(frozen.reviveMark, closeTo(TaisenGame.kReviveBaseSec, 0.001));
    expect(frozen.tip, '散咗拖返城先復活');
    expect(frozen.morale, frozen.moraleMark);

    final ticking = shots[1];
    expect(ticking.life, UnitLife.inCastleReviving);
    expect(ticking.skull, isTrue);
    expect(ticking.reviveLeft, lessThan(ticking.reviveMark - 0.10));
    expect(ticking.splash, isNot('復活'));

    final redeploy = shots[2];
    expect(redeploy.ready, isTrue);
    expect(redeploy.hp, TaisenGame.kRansenMaxHp);
    expect(redeploy.exitArmed, isTrue);
    expect(redeploy.leftCastle, isTrue);
    expect(redeploy.life, UnitLife.alive);
    expect(redeploy.skull, isFalse);
    expect(redeploy.splash, isNot('復活'));

    final heal = shots[3];
    expect(heal.life, UnitLife.alive);
    expect(heal.skull, isFalse);
    expect(heal.tip, '返城回血');
    expect(heal.splash, isNot('復活'));
    expect(heal.splash, isNot('撤退'));
    expect(heal.reviveLeft, 0);
    expect(heal.hp, greaterThan(heal.hpMark));
    expect(g.tutorial, isNull);
  });

  test('R1 hold keeps 撤退 after the freeze wait, R2 counts only inside 己城', () async {
    final g = TaisenGame();
    g.onGameResize(Vector2(390, 844));
    final shots = <RetreatReviveVisualShot>[];
    final script = RetreatReviveVisualVerify(
      game: g,
      step: () async {
        g.debugStepPursuit(1 / 60);
        g.debugDecayCombatFx(1 / 60);
      },
      hold: (shot) async {
        shots.add(shot);
        if (shot.id == 'R1') {
          expect(g.debugHitLabel, '撤退');
          expect(g.castleBandRect.contains(g.tokenCenter(0)), isFalse);
        }
        if (shot.id == 'R2') {
          expect(g.debugUnitLife(0), UnitLife.inCastleReviving);
          expect(
            g.fieldInCastle[0] || g.castleBandRect.contains(g.tokenCenter(0)),
            isTrue,
            reason: 'countdown hold stays in 歸城區',
          );
          expect(g.debugReviveLeft(0), greaterThan(0));
          expect(g.debugReviveLeft(0), lessThanOrEqualTo(TaisenGame.kReviveBaseSec));
        }
        if (shot.id == 'R4') {
          expect(g.debugLifeTipAt(0), '返城回血');
          expect(g.debugUnitHp(0), greaterThan(shot.hpMark));
          expect(g.debugUnitHp(0), lessThan(TaisenGame.kRansenMaxHp));
        }
      },
    );
    await script.run();
    for (final shot in shots) {
      expect(shot.pass, isTrue, reason: '${shot.id} splash=${shot.splash}');
    }
  });
}
