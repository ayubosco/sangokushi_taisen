import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';
import 'package:sangokushi_taisen/game/tutorial_controller.dart';

TaisenGame readyGame({TutorialController? tutorial}) {
  final g = TaisenGame(tutorial: tutorial);
  g.onGameResize(Vector2(390, 844));
  return g;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('waypoint: panUpdate does not teleport body; pursuit lags gold landing', () {
    final g = readyGame();
    g.setupSession1Field();
    final start = g.tokenCenter(0);
    g.panStart(start);
    expect(g.dragging, isTrue);

    final landing = Offset(start.dx + 150, start.dy - 90);
    g.panUpdate(landing);

    expect(g.tokenCenter(0), start);
    expect(g.debugWaypointLagPx, greaterThan(80));

    g.debugStepPursuit(1 / 60);
    final after = g.tokenCenter(0);
    final stepped = (after - start).distance;
    expect(stepped, greaterThan(0.2));
    expect(stepped, lessThan(12), reason: 'one frame must not consume the waypoint');
    expect(g.debugWaypointLagPx, greaterThan(70));
    expect((g.dragTo! - after).distance, greaterThan(70));
  });

  test('watch live-sync: mapped token moves when field body moves', () {
    final g = readyGame();
    g.setupSession1Field();
    const band = Rect.fromLTWH(0, 0, 390, 80);
    final before = g.mapFieldToWatch(g.tokenCenter(0), band);

    g.fieldPos[0] = Offset(g.fieldPos[0].dx + 40, g.fieldPos[0].dy - 70);
    final after = g.mapFieldToWatch(g.tokenCenter(0), band);

    expect(after.dx, isNot(closeTo(before.dx, 0.5)));
    expect(after.dy, lessThan(before.dy), reason: 'walking toward enemy = toward Watch horizon');
  });

  test('BINARY: mid charging has zero cyan; full travel is lit', () {
    final mid = readyGame();
    mid.setupChargeAuraLivePose();
    expect(mid.debugTravel01, closeTo(0.45, 0.02));
    expect(mid.auraActive, isFalse);
    expect(mid.showChargeCyanRings, isFalse);
    expect(mid.debugChargeFeel, 'charging');

    final lit = readyGame();
    lit.setupChargeAuraHitPose();
    expect(lit.auraActive, isTrue);
    expect(lit.showChargeCyanRings, isTrue);
    expect(lit.debugChargeFeel, 'lit');
    expect(lit.debugHitLabel, '突撃');
  });

  test('BINARY: aura snap flashes 氣勢, not 突撃, when no contact', () {
    final coach = TutorialController()..resetToSession1();
    final g = readyGame(tutorial: coach);
    g.setupSession1Field();
    coach.onSelectOwnCavalry();
    final start = g.tokenCenter(0);
    g.panStart(start);
    // Walk away from the enemy so travel fills without melee contact.
    g.panUpdate(Offset(40, start.dy + 160));
    var flipped = false;
    for (var i = 0; i < 80; i++) {
      g.debugStepPursuit(0.05);
      if (g.auraActive) {
        flipped = true;
        break;
      }
    }
    expect(flipped, isTrue);
    expect(g.showChargeCyanRings, isTrue);
    expect(g.debugHitLabel, '氣勢');
  });
}
