import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/game/soft_pin_visual_verify.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SOFT_PIN_VISUAL_VERIFY is off unless the dart-define is set', () {
    expect(kSoftPinVisualVerify, isFalse);
  });

  test('release march dumps ① mid, ④ charge, ④ lit, ② arrive', () async {
    final g = TaisenGame();
    g.onGameResize(Vector2(390, 844));
    expect(g.tutorial, isNull);

    final shots = <SoftPinVisualShot>[];
    final script = SoftPinVisualVerify(
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

    expect(
      shots.map((s) => s.id).toList(),
      ['1-mid', '4-charge', '4-lit', '2-arrive'],
    );
    for (final shot in shots) {
      expect(shot.pass, isTrue, reason: '${shot.id} ${shot.caption}');
      expect(shot.dragging, isFalse, reason: '${shot.id} is a release, not a hold-drag');
      expect(shot.h0Pass, isTrue, reason: '${shot.id} H0 ruler');
      expect(shot.watchOfGame, inInclusiveRange(0.12, 0.13));
      expect(shot.fieldOfGame, greaterThanOrEqualTo(0.87));
      expect(shot.tokenOfField, closeTo(0.10, 0.001));
    }

    final mid = shots[0];
    expect(mid.pinned, isTrue);
    expect(mid.shadowOpacity, greaterThan(0.30));
    expect(mid.pinGap, greaterThan(80));
    expect(mid.rings, isFalse);
    expect(mid.aura, isFalse);
    expect(mid.caption, contains('①'));

    final charging = shots[1];
    expect(charging.rings, isFalse);
    expect(charging.aura, isFalse);
    expect(charging.pinned, isTrue);
    expect(charging.caption, contains('零青'));
    expect(charging.caption, contains('落點釘'));

    final lit = shots[2];
    expect(lit.aura, isTrue);
    expect(lit.rings, isTrue);
    expect(lit.ringOnShadow, isTrue);
    expect(lit.pinned, isTrue);
    expect(lit.pinGap, greaterThan(36));
    expect(lit.label, '氣勢');
    expect(lit.caption, contains('SNAP'));

    final arrived = shots[3];
    expect(arrived.pinned, isFalse);
    expect(arrived.shadowOpacity, 0);
    expect(arrived.pinGap, lessThan(0.5));
    expect(arrived.travel01, 0);
    expect(arrived.rings, isFalse);
    expect(arrived.caption, contains('部隊追いつき'));
    expect(g.tutorial, isNull);
    expect(g.dragTo, isNull);
    expect(g.pinnedCardAt(0), g.shadowAt(0));
    expect(g.watchBodyAt(0), g.tokenCenter(0));
  });
}
