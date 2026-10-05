import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';
import 'package:sangokushi_taisen/game/troop_retreat_visual_verify.dart';
import 'package:sangokushi_taisen/game/unit_life.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TROOP_RETREAT_VISUAL_VERIFY is off unless the dart-define is set', () {
    expect(kTroopRetreatVisualVerify, isFalse);
  });

  test('free-match paths keep a readable cause when retreat fires', () async {
    final g = TaisenGame();
    g.onGameResize(Vector2(390, 844));
    expect(g.tutorial, isNull);

    final shots = <TroopRetreatVisualShot>[];
    final script = TroopRetreatVisualVerify(
      game: g,
      step: () async {
        g.debugStepPursuit(1 / 60);
      },
      hold: (shot) async {
        shots.add(shot);
      },
    );
    await script.run();

    expect(shots.map((s) => s.id).toList(), ['CAV', 'CAVK', 'SPEAR', 'BOW', 'INF', 'SIEGE']);
    for (final shot in shots) {
      expect(shot.pass, isTrue, reason: '${shot.id} ${shot.caption} cause=${shot.cause} label=${shot.label}');
    }

    final drop = shots[0];
    expect(drop.label, '突撃');
    expect(drop.dropped, greaterThan(TaisenGame.kRansenTickPerSec));
    expect(drop.enemyLife, UnitLife.alive);
    expect(drop.allyRansen, isTrue);
    expect(drop.enemyRansen, isTrue);

    final kill = shots[1];
    expect(kill.cause, '突撃');
    expect(kill.label, '撤退');
    expect(kill.enemyLife, UnitLife.retreating);
    expect(kill.enemyHp, 0);

    final spear = shots[2];
    expect(spear.cause, '迎擊');
    expect(spear.allyRansen, isFalse);
    expect(spear.enemyLife, UnitLife.retreating);

    final bow = shots[3];
    expect(bow.cause, '射');
    expect(bow.movingSilent, isTrue);
    expect(bow.scrambleSilent, isTrue);
    expect(bow.lowHpSame, isTrue);
    expect(bow.ownHp, 8);
    expect(bow.enemyLife, UnitLife.retreating);

    final infantry = shots[4];
    expect(infantry.cause, '亂戰');
    expect(infantry.label, isNot('突撃'));
    expect(infantry.enemyLife, UnitLife.retreating);

    final siege = shots[5];
    expect(siege.dropped, lessThan(TaisenGame.kRansenTickPerSec * 0.5));
    expect(siege.chipAlive, isTrue);
    expect(siege.cause, '城傷');
    expect(siege.ownLife, UnitLife.inCastleReviving);
    expect(siege.enemyHp, TaisenGame.kRansenMaxHp);
    expect(g.tutorial, isNull);
  });

  test('CAV hold waits through a missed engine tick for 突撃 contact', () async {
    final g = TaisenGame();
    g.onGameResize(Vector2(390, 844));
    var skippedOverlap = false;
    final shots = <TroopRetreatVisualShot>[];
    final script = TroopRetreatVisualVerify(
      game: g,
      step: () async {
        final overlapped = g.fieldPos.length > 1 &&
            (g.fieldPos[0] - g.fieldPos[1]).distance < 1 &&
            g.debugUnitHp(1) >= TaisenGame.kRansenMaxHp - 0.01 &&
            g.debugHitLabel == '氣勢';
        if (overlapped && !skippedOverlap) {
          skippedOverlap = true;
          return;
        }
        g.debugStepPursuit(1 / 60);
      },
      hold: (shot) async {
        shots.add(shot);
      },
    );
    await script.run();

    expect(skippedOverlap, isTrue, reason: 'the missed tick must happen on the 氣勢 overlap');
    final drop = shots.firstWhere((s) => s.id == 'CAV');
    expect(drop.pass, isTrue, reason: 'label=${drop.label} dropped=${drop.dropped}');
    expect(drop.label, '突撃');
    expect(drop.dropped, greaterThan(TaisenGame.kRansenTickPerSec));
    for (final shot in shots) {
      expect(shot.pass, isTrue, reason: shot.id);
    }
  });
}
