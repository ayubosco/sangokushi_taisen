import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/data/card_models.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';
import 'package:sangokushi_taisen/game/tutorial_controller.dart';

import 'feel_gates_test.dart' show readyGame;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mid-march redirect keeps the charge meter, including a lit aura', () {
    final g = readyGame();
    final start = Offset(g.size.x * 0.20, g.watchH + g.fieldH * 0.72);
    _placeOwn(g, start, TroopType.cavalry);
    final landing = Offset(start.dx + 240, start.dy);
    g.panStart(start);
    g.panEnd(landing);

    const dt = 1 / 60;
    var guard = 0;
    while (g.debugTravel01 < 0.40 && g.dragTo != null && guard < 500) {
      g.debugStepPursuit(dt);
      guard++;
    }
    expect(g.dragTo, isNotNull, reason: 'still marching when we retarget');
    expect(g.auraActive, isFalse);
    final partial = g.debugTravel01;
    expect(partial, greaterThan(0.40));

    final body = g.tokenCenter(0);
    final nudged = Offset(body.dx + 150, body.dy - 18);
    g.panStart(body);
    g.panUpdate(nudged);
    g.panEnd(nudged);

    expect(g.debugTravel01, closeTo(partial, 0.001));
    expect(g.auraActive, isFalse);
    expect(g.dragTo, isNotNull);

    for (var i = 0; i < 8; i++) {
      g.debugStepPursuit(dt);
    }
    expect(g.debugTravel01, greaterThan(partial));
    expect(g.debugTravel01, lessThan(1.0),
        reason: 'retarget must not re-store a full meter');

    guard = 0;
    while (!g.auraActive && g.dragTo != null && guard < 500) {
      g.debugStepPursuit(dt);
      guard++;
    }
    expect(g.auraActive, isTrue);
    final lit = g.debugTravel01;
    final litBody = g.tokenCenter(0);
    final stillAhead = Offset(litBody.dx + 80, litBody.dy - 8);
    g.panStart(litBody);
    g.panUpdate(stillAhead);
    g.panEnd(stillAhead);
    expect(g.auraActive, isTrue);
    expect(g.debugTravel01, closeTo(lit, 0.001));
    expect(g.debugHitLabel, isNot('突撃'));
  });

  test('a sharp turn still clears; a full stop drains the meter', () {
    final g = readyGame();
    final start = Offset(g.size.x * 0.55, g.watchH + g.fieldH * 0.60);
    _placeOwn(g, start, TroopType.cavalry);
    g.panStart(start);
    g.panEnd(Offset(start.dx + 200, start.dy));
    const dt = 1 / 60;
    var guard = 0;
    while (g.debugTravel01 < 0.35 && g.dragTo != null && guard < 500) {
      g.debugStepPursuit(dt);
      guard++;
    }
    expect(g.debugTravel01, greaterThan(0.35));
    final body = g.tokenCenter(0);
    final back = Offset(body.dx - 160, body.dy);
    g.panStart(body);
    g.panUpdate(back);
    g.panEnd(back);
    g.debugStepPursuit(dt);
    expect(g.debugTravel01, lessThan(0.12),
        reason: 'about-face still drops travel');

    final stop = readyGame();
    final from = Offset(stop.size.x * 0.30, stop.watchH + stop.fieldH * 0.62);
    _placeOwn(stop, from, TroopType.infantry);
    stop.panStart(from);
    stop.panEnd(Offset(from.dx + 80, from.dy));
    guard = 0;
    while (stop.dragTo != null && guard < 500) {
      stop.debugStepPursuit(dt);
      guard++;
    }
    expect(stop.dragTo, isNull);
    expect(stop.debugTravel01, 0, reason: 'arrive clears the meter to 0');
    expect(stop.auraActive, isFalse);
    stop.debugDecayStoppedCharge(dt);
    expect(stop.debugTravel01, 0);

    stop.panStart(stop.tokenCenter(0));
    stop.panEnd(Offset(stop.tokenCenter(0).dx + 160, stop.tokenCenter(0).dy));
    stop.debugStepPursuit(dt);
    expect(stop.dragTo, isNotNull);
    expect(stop.debugTravel01, greaterThan(0),
        reason: 'aura rebuilds only after he moves again');
  });

  test('no-aura overlap is 亂戰 with mutual damage and no 突撃', () {
    final g = readyGame();
    final at = Offset(g.size.x * 0.40, g.watchH + g.fieldH * 0.50);
    _placeOwn(g, at, TroopType.infantry);
    _addEnemy(g, at);
    expect(g.inMeleeContact(g.tokenCenter(0), g.tokenCenter(1)), isTrue);

    g.debugStepPursuit(0.5);
    expect(g.debugInRansen(0), isTrue);
    expect(g.debugInRansen(1), isTrue);
    expect(g.debugHitLabel, isNot('突撃'));
    expect(g.debugHitLabel, isEmpty);
    expect(g.auraActive, isFalse);
    expect(g.debugUnitHp(0), lessThan(TaisenGame.kRansenMaxHp));
    expect(g.debugUnitHp(1), lessThan(TaisenGame.kRansenMaxHp));
    final ally = g.debugUnitHp(0);
    final enemy = g.debugUnitHp(1);

    g.fieldPos[1] = g.fieldPos[0] + const Offset(280, 0);
    g.debugStepPursuit(0.5);
    expect(g.debugInRansen(0), isFalse);
    expect(g.debugInRansen(1), isFalse);
    expect(g.debugUnitHp(0), ally);
    expect(g.debugUnitHp(1), enemy);
    expect(g.debugHitLabel, isNot('突撃'));
  });

  test('aura contact fires 突撃 once, clears the meter, then stays in 亂戰', () {
    final g = readyGame();
    final start = Offset(g.size.x * 0.18, g.watchH + g.fieldH * 0.70);
    _placeOwn(g, start, TroopType.cavalry);
    _addEnemy(g, Offset(start.dx + 280, start.dy - 220));
    g.panStart(start);
    g.panEnd(Offset(start.dx + 260, start.dy));
    const dt = 1 / 60;
    var guard = 0;
    while (!g.auraActive && g.dragTo != null && guard < 600) {
      g.debugStepPursuit(dt);
      guard++;
    }
    expect(g.auraActive, isTrue);
    expect(g.inMeleeContact(g.tokenCenter(0), g.tokenCenter(1)), isFalse);

    g.dragTo = null;
    g.fieldPos[1] = g.fieldPos[0];
    g.debugStepPursuit(dt);
    expect(g.debugHitLabel, '突撃');
    expect(TaisenGame.kChargeFlashSec, lessThanOrEqualTo(1.0));
    expect(g.debugTravel01, 0);
    expect(g.auraActive, isFalse);
    expect(g.debugInRansen(0), isTrue);
    expect(g.debugInRansen(1), isTrue);
    expect(g.debugUnitHp(0), lessThan(TaisenGame.kRansenMaxHp));
    expect(g.debugUnitHp(1), lessThan(TaisenGame.kRansenMaxHp));

    g.debugDecayCombatFx(TaisenGame.kChargeFlashSec);
    expect(g.debugHitLabel, isEmpty);
    expect(g.debugInRansen(0), isTrue, reason: 'overlap has no fixed duration');
    g.debugStepPursuit(0.4);
    expect(g.debugHitLabel, isNot('突撃'));
    expect(g.auraActive, isFalse);
    expect(g.debugTravel01, 0);
  });

  test('亂戰 retracts the spear, stops the bow, and does not build cavalry aura',
      () {
    const dt = 1 / 60;
    final spear = readyGame();
    final at = Offset(spear.size.x * 0.42, spear.watchH + spear.fieldH * 0.48);
    _placeOwn(spear, at, TroopType.spear);
    _addEnemy(spear, at + const Offset(220, 0));
    expect(spear.spearTipExtendedAt(0), isTrue);
    spear.fieldPos[1] = spear.fieldPos[0];
    spear.debugStepPursuit(dt);
    expect(spear.debugInRansen(0), isTrue);
    expect(spear.spearTipExtendedAt(0), isFalse);
    expect(spear.debugHitLabel, isNot('突撃'));
    spear.fieldPos[1] = spear.fieldPos[0] + const Offset(240, 0);
    spear.debugStepPursuit(dt);
    expect(spear.spearTipExtendedAt(0), isTrue);

    final bow = readyGame();
    final bowAt = Offset(bow.size.x * 0.42, bow.watchH + bow.fieldH * 0.48);
    _placeOwn(bow, bowAt, TroopType.bow);
    _addEnemy(bow, bowAt);
    bow.debugStepPursuit(dt);
    expect(bow.debugInRansen(0), isTrue);
    bow.selectOrDetailAt(bowAt);
    expect(bow.debugBowWinding, isFalse);
    bow.debugStepPursuit(4.0);
    expect(bow.debugBowWinding, isFalse);
    expect(bow.debugHitLabel, isNot('突撃'));

    final cav = readyGame();
    final cavAt = Offset(cav.size.x * 0.22, cav.watchH + cav.fieldH * 0.62);
    _placeOwn(cav, cavAt, TroopType.cavalry);
    _addEnemy(cav, cavAt + const Offset(300, -180));
    cav.panStart(cavAt);
    cav.panEnd(Offset(cavAt.dx + 220, cavAt.dy));
    var guard = 0;
    while (cav.debugTravel01 < 0.45 && cav.dragTo != null && guard < 500) {
      cav.debugStepPursuit(dt);
      guard++;
    }
    expect(cav.auraActive, isFalse);
    final kept = cav.debugTravel01;
    expect(kept, greaterThan(0.45));
    for (var i = 0; i < 25; i++) {
      cav.fieldPos[1] = cav.fieldPos[0];
      cav.debugStepPursuit(dt);
    }
    expect(cav.debugInRansen(0), isTrue);
    expect(cav.auraActive, isFalse);
    expect(cav.debugHitLabel, isNot('突撃'));
    expect(cav.debugTravel01, greaterThan(kept - 0.001));
    expect(cav.debugTravel01, lessThan(kept + 0.08),
        reason: 'no aura build while overlapping');
  });

  test('tutorial retarget keeps travel instead of rebuilding from 0%', () {
    final coach = TutorialController()..resetToSession1();
    final g = readyGame(tutorial: coach);
    g.setupSession1Field();
    coach.onSelectOwnCavalry();
    final start = g.tokenCenter(0);
    g.panStart(start);
    g.panEnd(Offset(start.dx + 200, start.dy));
    const dt = 1 / 60;
    var guard = 0;
    while (g.debugTravel01 < 0.25 && g.dragTo != null && guard < 500) {
      g.debugStepPursuit(dt);
      guard++;
    }
    final kept = g.debugTravel01;
    expect(kept, greaterThan(0.25));
    final body = g.tokenCenter(0);
    g.panStart(body);
    g.panUpdate(Offset(body.dx + 120, body.dy - 10));
    g.panEnd(Offset(body.dx + 120, body.dy - 10));
    expect(g.debugTravel01, closeTo(kept, 0.001));
    expect(coach.tipText, isNot('蓄緊 0% — 跟住手指拖行，未亮唔好撞'));
    expect(coach.auraReady, isFalse);
  });

  test('亂戰 slows the march but a drag can still leave', () {
    const dt = 1 / 60;
    double secondStep({required bool scramble}) {
      final g = readyGame();
      final start = Offset(g.size.x * 0.24, g.watchH + g.fieldH * 0.55);
      _placeOwn(g, start, TroopType.cavalry);
      if (scramble) _addEnemy(g, start);
      g.panStart(start);
      g.panEnd(Offset(start.dx + 220, start.dy));
      g.debugStepPursuit(dt);
      final before = g.tokenCenter(0);
      g.debugStepPursuit(dt);
      return (g.tokenCenter(0) - before).distance;
    }

    final free = secondStep(scramble: false);
    final slow = secondStep(scramble: true);
    expect(TaisenGame.kRansenMul, inInclusiveRange(0.55, 0.65));
    expect(free, greaterThan(1));
    expect(slow / free, closeTo(TaisenGame.kRansenMul, 0.05));

    final g = readyGame();
    final start = Offset(g.size.x * 0.30, g.watchH + g.fieldH * 0.55);
    _placeOwn(g, start, TroopType.cavalry);
    _addEnemy(g, start + const Offset(220, 0));
    final openAlly = g.debugWorldSpeedPx(0);
    final openEnemy = g.debugWorldSpeedPx(1);
    expect(openAlly, greaterThan(1));
    expect(openEnemy, greaterThan(1));
    g.fieldPos[1] = g.fieldPos[0];
    g.debugStepPursuit(dt);
    expect(g.debugInRansen(0), isTrue);
    expect(g.debugInRansen(1), isTrue);
    expect(g.debugWorldSpeedPx(0), closeTo(openAlly * TaisenGame.kRansenMul, 0.01));
    expect(g.debugWorldSpeedPx(1), closeTo(openEnemy * TaisenGame.kRansenMul, 0.01));

    // Grab the enemy card (drawn on top of the stack) and drag clear of the overlap.
    final stacked = g.tokenCenter(1);
    g.panStart(stacked);
    expect(g.selectedIndex, 0, reason: 'enemy card in 亂戰 still steers the ally');
    expect(g.dragTo, isNotNull);
    final away = stacked + Offset(g.meleeContactDist + g.tokenCardSize.width + 24, 0);
    g.panUpdate(away);
    g.panEnd(away);
    final before = g.tokenCenter(0);
    g.debugStepPursuit(dt);
    expect((g.tokenCenter(0) - before).distance, greaterThan(0.2),
        reason: 'waypoint velocity is not frozen in 亂戰');
    var guard = 0;
    while (g.debugInRansen(0) && guard < 120) {
      g.debugStepPursuit(dt);
      guard++;
    }
    expect(g.debugInRansen(0), isFalse, reason: 'focused drag peels within 2s');
    expect(g.debugInRansen(1), isFalse);
    expect(g.dragTo, isNotNull);
    expect(g.debugWorldSpeedPx(0), closeTo(openAlly, 0.01),
        reason: 'open speed returns once the bodies separate');
    expect(g.debugWorldSpeedPx(1), closeTo(openEnemy, 0.01));
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

void _addEnemy(TaisenGame g, Offset at) {
  final card = Cost6Roster.all.firstWhere((c) => c.id == 'caocao');
  g.field.add(card);
  g.fieldIsEnemy.add(true);
  g.fieldInCastle.add(false);
  g.fieldPos.add(at);
  g.tutorialEnemyIndex = g.field.length - 1;
}
