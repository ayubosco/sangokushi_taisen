import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/data/card_models.dart';
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

  test('waypoint speed: same distance, cavalry arrives well before spear', () {
    const sampleFrames = 42; // 0.70s at 60fps — mid-frame, cavalry still short of 落點
    const dt = 1 / 60;

    ({double eta, double gone}) measure(TroopType troop) {
      final g = readyGame();
      final lag = g.debugArmSpeedCompare(troop);
      expect(g.dragging, isTrue, reason: '${troop.name} drag must start');
      expect(lag, greaterThan(100), reason: '${troop.name} landing must lead the body');
      final start = g.tokenCenter(0);
      expect(g.dragTo, isNotNull);
      expect((g.dragTo! - start).distance, closeTo(lag, 0.5));

      g.debugStepPursuit(dt);
      final first = (g.tokenCenter(0) - start).distance;
      expect(first, greaterThan(0.05), reason: '${troop.name} must step');
      expect(first, lessThan(12), reason: '${troop.name} must not consume the waypoint in one frame');

      var frames = 1;
      while (frames < sampleFrames) {
        g.debugStepPursuit(dt);
        frames++;
      }
      final gone = (g.tokenCenter(0) - start).distance;
      while (g.debugWaypointLagPx > 3 && frames < 60 * 25) {
        g.debugStepPursuit(dt);
        frames++;
      }
      expect(g.debugWaypointLagPx, lessThanOrEqualTo(3), reason: '${troop.name} reaches 落點');
      return (eta: frames / 60.0, gone: gone);
    }

    final cav = measure(TroopType.cavalry);
    final bow = measure(TroopType.bow);
    final spear = measure(TroopType.spear);
    final foot = measure(TroopType.infantry);
    final siege = measure(TroopType.siege);

    final gap = cav.gone - spear.gone;
    // ignore: avoid_print
    print(
      'SPEED_COMPARE MID t=0.70s cavGone=${cav.gone.toStringAsFixed(1)} '
      'bowGone=${bow.gone.toStringAsFixed(1)} spearGone=${spear.gone.toStringAsFixed(1)} '
      'footGone=${foot.gone.toStringAsFixed(1)} siegeGone=${siege.gone.toStringAsFixed(1)} '
      'cavAheadOfSpear=${gap.toStringAsFixed(1)}',
    );
    // ignore: avoid_print
    print(
      'SPEED_COMPARE SUMMARY cavEta=${cav.eta.toStringAsFixed(2)} '
      'bowEta=${bow.eta.toStringAsFixed(2)} spearEta=${spear.eta.toStringAsFixed(2)} '
      'infantryEta=${foot.eta.toStringAsFixed(2)} siegeEta=${siege.eta.toStringAsFixed(2)} '
      'spearOverCav=${(spear.eta / cav.eta).toStringAsFixed(2)}',
    );

    expect(TaisenGame.pursuitRelToCavalry(TroopType.cavalry), 1.0);
    expect(TaisenGame.pursuitRelToCavalry(TroopType.bow), lessThan(1.0));
    expect(
      TaisenGame.pursuitRelToCavalry(TroopType.spear),
      lessThan(TaisenGame.pursuitRelToCavalry(TroopType.bow)),
    );
    expect(
      TaisenGame.pursuitRelToCavalry(TroopType.infantry),
      lessThan(TaisenGame.pursuitRelToCavalry(TroopType.spear)),
    );
    expect(
      TaisenGame.pursuitRelToCavalry(TroopType.siege),
      lessThan(TaisenGame.pursuitRelToCavalry(TroopType.infantry)),
    );

    // Mid-frame: cavalry body is clearly ahead of spear (more than one token width).
    expect(gap, greaterThan(55));
    expect(spear.gone / cav.gone, lessThan(0.35));
    expect(cav.gone, greaterThan(bow.gone));
    expect(bow.gone, greaterThan(spear.gone));
    expect(spear.gone, greaterThan(foot.gone));
    expect(foot.gone, greaterThan(siege.gone));

    expect(spear.eta / cav.eta, greaterThan(3.5));
    expect(bow.eta, greaterThan(cav.eta * 1.5));
    expect(bow.eta, lessThan(spear.eta));
    expect(foot.eta, greaterThan(spear.eta * 1.3));
    expect(siege.eta, greaterThan(foot.eta * 1.3));
  });
}
