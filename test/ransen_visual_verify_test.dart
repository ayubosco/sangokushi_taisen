import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/game/ransen_visual_verify.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('RANSEN_VISUAL_VERIFY is off unless the dart-define is set', () {
    expect(kRansenVisualVerify, isFalse);
  });

  test('free-match visual sequence hits A keep, B 亂戰, C 突撃 then clear, D gone', () async {
    final g = TaisenGame();
    g.onGameResize(Vector2(390, 844));
    expect(g.tutorial, isNull);

    final shots = <RansenVisualShot>[];
    final script = RansenVisualVerify(
      game: g,
      step: () async {
        g.debugStepPursuit(1 / 60);
        g.debugDecayCombatFx(1 / 60);
      },
      hold: (shot) async {
        shots.add(shot);
      },
    );
    await script.run();

    expect(shots.map((s) => s.id).toList(), ['A', 'B', 'C1', 'C', 'D']);
    for (final shot in shots) {
      expect(shot.pass, isTrue, reason: '${shot.id} ${shot.caption}');
    }

    final keep = shots[0];
    expect(keep.travel01, greaterThan(0.30));
    expect(keep.travel01, lessThan(0.85));
    expect(keep.aura, isFalse);
    expect(keep.rings, isFalse);
    expect(keep.caption, contains('KEEP'));

    final scramble = shots[1];
    expect(scramble.allyRansen, isTrue);
    expect(scramble.label, isNot('突撃'));
    expect(scramble.caption, contains('亂戰'));
    expect(scramble.allyHp, lessThan(TaisenGame.kRansenMaxHp));

    final flash = shots[2];
    expect(flash.label, '突撃');
    expect(flash.aura, isFalse);
    expect(flash.travel01, 0);

    final after = shots[3];
    expect(after.label, isEmpty);
    expect(after.allyRansen, isTrue);
    expect(after.aura, isFalse);

    final gone = shots[4];
    expect(gone.allyRansen, isFalse);
    expect(gone.enemyRansen, isFalse);
    expect(g.tutorial, isNull);
  });
}
