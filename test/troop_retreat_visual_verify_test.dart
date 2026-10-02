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
}
