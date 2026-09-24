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

  test('waypoint speed: same distance, cavalry arrives before foot', () {
    const sampleFrames = 30; // 0.50s — both still short of a 96px 落點, aura still off
    const dt = 1 / 60;
    const wikiCavOverFoot = 1.1 / 0.9;

    ({double eta, double gone, bool aura}) measure(TroopType troop) {
      final g = readyGame();
      final lag = g.debugArmSpeedCompare(troop);
      expect(g.dragging, isTrue, reason: '${troop.name} drag must start');
      expect(lag, greaterThan(80), reason: '${troop.name} landing must lead the body');
      expect(lag, lessThan(TaisenGame.kChargeTravelNeed), reason: 'base compare stays under aura distance');
      final start = g.tokenCenter(0);
      expect(g.dragTo, isNotNull);
      expect((g.dragTo! - start).distance, closeTo(lag, 0.5));

      g.debugStepPursuit(dt);
      final first = (g.tokenCenter(0) - start).distance;
      expect(first, greaterThan(0.05), reason: '${troop.name} must step');
      expect(first, lessThan(12), reason: '${troop.name} must not consume the waypoint in one frame');
      expect(g.auraActive, isFalse);
      expect(g.showChargeCyanRings, isFalse);

      var frames = 1;
      while (frames < sampleFrames) {
        g.debugStepPursuit(dt);
        frames++;
      }
      final gone = (g.tokenCenter(0) - start).distance;
      expect(g.auraActive, isFalse, reason: '${troop.name} base march must not light aura');
      while (g.debugWaypointLagPx > 3 && frames < 60 * 8) {
        g.debugStepPursuit(dt);
        frames++;
      }
      expect(g.debugWaypointLagPx, lessThanOrEqualTo(3), reason: '${troop.name} reaches 落點');
      expect(g.auraActive, isFalse);
      return (eta: frames / 60.0, gone: gone, aura: g.auraActive);
    }

    expect(TaisenGame.pursuitWikiBase(TroopType.cavalry), 1.1);
    expect(TaisenGame.pursuitWikiBase(TroopType.infantry), 0.9);
    expect(TaisenGame.pursuitWikiBase(TroopType.bow), 0.8);
    expect(TaisenGame.pursuitWikiBase(TroopType.spear), 0.7);
    expect(TaisenGame.pursuitWikiBase(TroopType.siege), 0.5);
    expect(TaisenGame.kCavalryAuraSpeed, 1.32);
    expect(TaisenGame.pursuitWikiCap(TroopType.cavalry), 3.3);
    expect(TaisenGame.pursuitWikiCap(TroopType.infantry), 2.7);
    expect(TaisenGame.pursuitWikiCap(TroopType.bow), 2.4);
    expect(TaisenGame.pursuitWikiCap(TroopType.spear), 2.1);
    expect(TaisenGame.pursuitWikiCap(TroopType.siege), 2.0);

    final cav = measure(TroopType.cavalry);
    final foot = measure(TroopType.infantry);
    final bow = measure(TroopType.bow);
    final spear = measure(TroopType.spear);
    final siege = measure(TroopType.siege);

    // ignore: avoid_print
    print(
      'SPEED_COMPARE MID t=0.50s cavGone=${cav.gone.toStringAsFixed(1)} '
      'footGone=${foot.gone.toStringAsFixed(1)} bowGone=${bow.gone.toStringAsFixed(1)} '
      'spearGone=${spear.gone.toStringAsFixed(1)} siegeGone=${siege.gone.toStringAsFixed(1)} '
      'cavOverFoot=${(cav.gone / foot.gone).toStringAsFixed(3)}',
    );
    // ignore: avoid_print
    print(
      'SPEED_COMPARE SUMMARY cavEta=${cav.eta.toStringAsFixed(2)} '
      'footEta=${foot.eta.toStringAsFixed(2)} bowEta=${bow.eta.toStringAsFixed(2)} '
      'spearEta=${spear.eta.toStringAsFixed(2)} siegeEta=${siege.eta.toStringAsFixed(2)} '
      'footOverCav=${(foot.eta / cav.eta).toStringAsFixed(3)}',
    );

    expect(cav.eta, lessThan(foot.eta));
    expect(foot.eta / cav.eta, closeTo(wikiCavOverFoot, 0.04));
    expect(cav.gone / foot.gone, closeTo(wikiCavOverFoot, 0.02));
    // Wiki order: 騎 > 歩 > 弓 > 槍 > 攻城. Not 騎>弓>歩＝槍.
    expect(cav.gone, greaterThan(foot.gone));
    expect(foot.gone, greaterThan(bow.gone));
    expect(bow.gone, greaterThan(spear.gone));
    expect(spear.gone, greaterThan(siege.gone));
    expect(cav.aura, isFalse);
    expect(foot.aura, isFalse);
  });

  test('cavalry aura speed is 1.32 only while auraActive', () {
    const dt = 1 / 60;
    final cav = readyGame();
    cav.debugArmSpeedCompare(TroopType.cavalry, distancePx: 240);
    final cavStart = cav.tokenCenter(0);
    cav.debugStepPursuit(dt);
    final baseStep = (cav.tokenCenter(0) - cavStart).distance;
    expect(cav.auraActive, isFalse);
    expect(cav.showChargeCyanRings, isFalse);

    var guard = 0;
    while (!cav.auraActive && guard < 400) {
      cav.debugStepPursuit(dt);
      guard++;
    }
    expect(cav.auraActive, isTrue);
    expect(cav.showChargeCyanRings, isTrue);
    expect(cav.debugHitLabel, '氣勢');
    final litAt = cav.tokenCenter(0);
    cav.debugStepPursuit(dt);
    final auraStep = (cav.tokenCenter(0) - litAt).distance;
    expect(auraStep / baseStep, closeTo(1.32 / 1.1, 0.02));

    final foot = readyGame();
    foot.debugArmSpeedCompare(TroopType.infantry, distancePx: 240);
    final footStart = foot.tokenCenter(0);
    foot.debugStepPursuit(dt);
    final footBase = (foot.tokenCenter(0) - footStart).distance;
    guard = 0;
    while (!foot.auraActive && guard < 400) {
      foot.debugStepPursuit(dt);
      guard++;
    }
    expect(foot.auraActive, isTrue);
    final footAt = foot.tokenCenter(0);
    foot.debugStepPursuit(dt);
    final footLater = (foot.tokenCenter(0) - footAt).distance;
    expect(footLater, closeTo(footBase, 0.05), reason: 'foot has no aura speed boost');
  });

  test('release commits dragTo: body marches closer and does not freeze or teleport', () {
    final g = readyGame();
    final start = Offset(g.size.x * 0.30, g.watchH + g.fieldH * 0.62);
    _placeOwn(g, start, TroopType.cavalry);
    g.panStart(start);
    final landing = Offset(start.dx + 180, start.dy - 30);
    g.dragTo = landing;
    expect((g.dragTo! - g.tokenCenter(0)).distance, greaterThan(140));

    g.panEnd(landing);

    expect(g.dragging, isFalse);
    expect(g.dragTo, isNotNull);
    expect(g.tokenCenter(0), start, reason: 'release must not teleport the body to the finger');
    final committed = g.dragTo!;
    final releasePos = g.tokenCenter(0);
    expect((committed - releasePos).distance, greaterThan(140));

    for (var i = 0; i < 24; i++) {
      g.debugStepPursuit(1 / 60);
    }
    final after = g.tokenCenter(0);
    expect((after - releasePos).distance, greaterThan(8), reason: 'not frozen at the release pose');
    expect(
      (committed - after).distance,
      lessThan((committed - releasePos).distance - 8),
      reason: 'closer to the committed target',
    );
    expect((after - landing).distance, greaterThan(40), reason: 'still in transit, body ≠ 落點');
    expect(g.dragTo, isNotNull, reason: 'waypoint stays until arrival');
  });

  test('arrival rests the body on the target and clears the waypoint', () {
    final g = readyGame();
    final start = Offset(g.size.x * 0.30, g.watchH + g.fieldH * 0.62);
    _placeOwn(g, start, TroopType.infantry);
    final landing = Offset(start.dx + 70, start.dy);
    g.panStart(start);
    g.panEnd(landing);
    expect(g.tokenCenter(0), start);

    const dt = 1 / 60;
    var frames = 0;
    while (g.dragTo != null && frames < 60 * 8) {
      g.debugStepPursuit(dt);
      frames++;
    }
    expect(g.dragTo, isNull);
    expect(g.dragging, isFalse);
    expect((g.tokenCenter(0) - landing).distance, lessThanOrEqualTo(TaisenGame.kArrivalEpsilon));
    expect(frames, greaterThan(5), reason: 'arrival is a march, not a release snap');
  });

  test('castle band parks only when the body is already inside it', () {
    final g = readyGame();
    final band = g.castleBandRect;
    final outside = Offset(g.size.x * 0.42, band.top - 90);
    final inBand = Offset(outside.dx, band.top + band.height * 0.45);
    _placeOwn(g, outside, TroopType.cavalry);
    g.panStart(outside);
    g.panEnd(inBand);
    expect(g.dragging, isFalse);
    expect(g.dragTo, isNotNull, reason: 'destination in 己城 still commits the march');
    expect(g.tokenCenter(0).dy, closeTo(outside.dy, 0.5));
    expect(g.fieldInCastle[0], isFalse);

    final parked = readyGame();
    final parkedBand = parked.castleBandRect;
    final alreadyIn = Offset(parked.size.x * 0.42, parkedBand.top + parkedBand.height * 0.4);
    _placeOwn(parked, alreadyIn, TroopType.cavalry);
    parked.panStart(alreadyIn);
    parked.panEnd(Offset(alreadyIn.dx + 12, alreadyIn.dy));
    expect(parked.dragTo, isNull);
    expect(parked.fieldInCastle[0], isTrue);
    expect(parked.tokenCenter(0).dy, greaterThan(parkedBand.top));
  });

  test('cavalry half-field straight run is 1.5–3.0s; aura stays distance-gated', () {
    final g = readyGame();
    expect(TaisenGame.kWatchFractionOfGame, lessThanOrEqualTo(0.18));
    expect(TaisenGame.kTokenWidthFracOfField, closeTo(0.10, 0.001));
    final half = g.fieldH * 0.5;
    final landing = Offset(g.size.x * 0.50, g.watchH + 40);
    final start = Offset(landing.dx, landing.dy + half);
    expect(start.dy, lessThan(g.castleBandRect.top));
    _placeOwn(g, start, TroopType.cavalry);
    g.panStart(start);
    g.panUpdate(landing);
    g.panEnd(landing);
    expect(g.dragging, isFalse);
    expect(g.auraActive, isFalse, reason: 'aura is not a release timer');
    expect(g.debugTravel01, 0);
    expect((g.tokenCenter(0) - landing).distance, closeTo(half, 1));

    const dt = 1 / 60;
    var frames = 0;
    var auraFrame = -1;
    while (g.dragTo != null && frames < 60 * 8) {
      g.debugStepPursuit(dt);
      frames++;
      if (auraFrame < 0 && g.auraActive) auraFrame = frames;
    }
    final sec = frames / 60.0;
    // ignore: avoid_print
    print(
      'HALF_FIELD cavSec=${sec.toStringAsFixed(3)} halfPx=${half.toStringAsFixed(1)} '
      'auraAtSec=${auraFrame < 0 ? -1 : (auraFrame / 60).toStringAsFixed(3)} '
      'watch=${TaisenGame.kWatchFractionOfGame} tokenW=${TaisenGame.kTokenWidthFracOfField}',
    );
    expect(g.dragTo, isNull);
    expect((g.tokenCenter(0) - landing).distance, lessThanOrEqualTo(TaisenGame.kArrivalEpsilon));
    expect(sec, inInclusiveRange(1.5, 3.0));
    expect(auraFrame, greaterThan(0), reason: '120px travel still lights the aura on a long march');
    expect(auraFrame / 60.0, greaterThan(0.4), reason: 'aura is not instant on finger-up');
    expect(g.debugTravel01, 1.0);
  });
}

void _placeOwn(TaisenGame g, Offset at, TroopType troop) {
  final card = Cost6Roster.all.firstWhere((c) => c.troop == troop);
  g.field.clear();
  g.fieldPos.clear();
  g.fieldIsEnemy.clear();
  g.fieldInCastle.clear();
  g.field.add(card);
  g.fieldIsEnemy.add(false);
  g.fieldInCastle.add(false);
  g.fieldPos.add(at);
  g.selectedIndex = 0;
  g.tutorialOwnIndex = 0;
  g.tutorialEnemyIndex = null;
  g.dragging = false;
  g.dragFrom = null;
  g.dragTo = null;
}
