import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/data/card_models.dart';
import 'package:sangokushi_taisen/game/fx_windows.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';
import 'package:sangokushi_taisen/game/unit_life.dart';

import 'feel_gates_test.dart' show readyGame;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('edge leave, cancel, and re-enter do not freeze the next drag', () {
    final g = readyGame();
    final start = Offset(g.size.x * 0.50, g.watchH + g.fieldH * 0.50);
    g.debugRestageOwnEnemy(
      ownId: 'zhangfei',
      ownAt: start,
      enemyAt: start + const Offset(0, -220),
    );

    g.panStart(start);
    g.panUpdate(const Offset(-80, 0));
    expect(g.dragging, isTrue);
    expect(g.dragTo!.dx, greaterThanOrEqualTo(36));
    expect(g.dragTo!.dx, lessThan(g.size.x - 30));
    g.panCancel();
    expect(g.dragging, isFalse, reason: 'bezel cancel must drop the finger-down latch');

    g.panStart(start);
    g.panUpdate(Offset(g.size.x + 140, start.dy));
    expect(g.dragging, isTrue);
    final back = Offset(g.size.x * 0.42, start.dy - 24);
    g.panUpdate(back);
    expect(g.dragging, isTrue);
    expect(g.dragTo!.dx, closeTo(back.dx, 1));
    g.panEnd(back);
    expect(g.dragging, isFalse);

    final before = g.tokenCenter(0);
    g.debugStepPursuit(1 / 60);
    expect((g.tokenCenter(0) - before).distance, greaterThan(0.2));

    g.debugForceHpZero(0);
    expect(g.debugUnitLife(0), UnitLife.retreating);
    g.panStart(g.tokenCenter(0));
    g.panUpdate(Offset(-30, g.tokenCenter(0).dy));
    g.panCancel();
    expect(g.dragging, isFalse);
    g.panStart(g.tokenCenter(0));
    expect(g.dragging, isTrue);
    expect(g.selectedIndex, 0);
  });

  test('cavalry short drag keeps the 突撃 wave until the pin overlaps the shadow', () {
    final g = readyGame();
    final start = Offset(g.size.x * 0.22, g.watchH + g.fieldH * 0.62);
    g.debugRestageOwnEnemy(
      ownId: 'zhaoyun',
      ownAt: start,
      enemyAt: start + const Offset(40, -260),
    );
    g.panStart(start);
    g.panEnd(start + const Offset(280, 0));
    const dt = 1 / 60.0;
    var guard = 0;
    while (!g.auraActive && g.dragTo != null && guard < 600) {
      g.debugStepPursuit(dt);
      guard++;
    }
    expect(g.auraActive, isTrue);
    expect(g.debugChargeWaveVisible, isTrue);

    final body = g.tokenCenter(0);
    g.panStart(body);
    g.panUpdate(body + const Offset(-210, 70));
    expect(g.dragging, isTrue);
    for (var i = 0; i < 36; i++) {
      g.debugStepPursuit(dt);
    }
    expect(g.pinnedMarchAt(0), isTrue);
    expect((g.fieldPos[0] - g.dragTo!).distance, greaterThan(g.meleeContactDist));
    expect(g.debugChargeWaveVisible, isTrue);
    expect(g.auraActive, isTrue);
    expect(g.debugHitLabel, isNot('突撃'));

    g.fieldPos[1] = g.fieldPos[0];
    g.dragTo = null;
    g.dragging = false;
    g.debugStepPursuit(dt);
    expect(g.debugHitLabel, '突撃');
  });

  test('a fresh cavalry drag still shows the wave after 0.5s with no pin overlap', () {
    final g = readyGame();
    final start = Offset(g.size.x * 0.28, g.watchH + g.fieldH * 0.58);
    g.debugRestageOwnEnemy(
      ownId: 'zhaoyun',
      ownAt: start,
      enemyAt: start + const Offset(0, -240),
    );
    g.panStart(start);
    g.panUpdate(start + const Offset(220, -10));
    const dt = 1 / 60.0;
    for (var i = 0; i < 36; i++) {
      g.debugStepPursuit(dt);
    }
    expect(g.dragging, isTrue);
    expect((g.fieldPos[0] - g.dragTo!).distance, greaterThan(g.meleeContactDist));
    expect(g.debugChargeWaveVisible, isTrue);
    expect(g.debugHitLabel, isNot('突撃'));
    final kept = g.debugTravel01;
    g.panUpdate(g.tokenCenter(0) + const Offset(-160, 90));
    g.debugStepPursuit(dt);
    expect(g.debugChargeWaveVisible, isTrue);
    expect(g.debugTravel01, greaterThan(kept - 0.02));
  });

  test('standing bow auto-fires in range; drag/move stays silent', () {
    final g = readyGame();
    final at = Offset(g.size.x * 0.30, g.watchH + g.fieldH * 0.46);
    g.debugRestageOwnEnemy(
      ownId: 'sunquan',
      ownAt: at,
      enemyAt: at + const Offset(120, -40),
    );
    const shot = TaisenGame.kBowShotBurstSec * TaisenGame.kRansenTickPerSec;
    final windupSec = FxWindows.toSeconds(FxWindows.bowStopBeforeShotC);
    // Stopped + in range → 蓄勢 → auto 射.
    var guard = 0;
    while (g.debugHitLabel != '射' && guard < 400) {
      g.debugStepPursuit(1 / 60);
      guard++;
    }
    expect(g.debugHitLabel, '射');
    expect(TaisenGame.kRansenMaxHp - g.debugUnitHp(1), closeTo(shot, 0.001));
    expect(guard / 60.0, greaterThan(windupSec * 0.8));

    // Drag / committed march must not fire (走射 OFF).
    final moving = readyGame();
    moving.debugRestageOwnEnemy(
      ownId: 'sunquan',
      ownAt: at,
      enemyAt: at + const Offset(120, -40),
    );
    moving.panStart(at);
    moving.panUpdate(at + const Offset(160, 0));
    for (var i = 0; i < 90; i++) {
      moving.debugStepPursuit(1 / 60);
    }
    expect(moving.dragging, isTrue);
    expect(moving.debugHitLabel, isNot('射'));
    expect(moving.debugUnitHp(1), TaisenGame.kRansenMaxHp);

    // Waypoint commit also silent until the body stops.
    final march = readyGame();
    march.debugRestageOwnEnemy(
      ownId: 'sunquan',
      ownAt: at,
      enemyAt: at + const Offset(120, -40),
    );
    march.panStart(at);
    march.panEnd(at + const Offset(180, 0));
    expect(march.debugHitLabel, isNot('射'));
    expect(march.debugBowWinding, isFalse);
  });

  test('enemy cards and enemy skulls are not draggable; own skull is', () {
    final g = readyGame();
    final ownAt = Offset(g.size.x * 0.40, g.watchH + g.fieldH * 0.45);
    final enemyAt = ownAt + const Offset(180, -40);
    g.debugRestageOwnEnemy(ownId: 'zhangfei', ownAt: ownAt, enemyAt: enemyAt);

    g.panStart(enemyAt);
    expect(g.dragging, isFalse);
    expect(g.fieldPos[1], enemyAt);
    expect(g.selectedIndex, isNot(1));

    g.debugForceHpZero(1);
    expect(g.debugUnitLife(1), UnitLife.retreating);
    expect(g.debugShowsSkull(1), isTrue);
    expect(g.debugLifeTipAt(1), isEmpty, reason: 'enemy skull has no 入城 hint');
    g.selectOrDetailAt(g.tokenCenter(1));
    expect(g.selectedIndex, isNot(1), reason: 'enemy skull takes no selection ring');
    final skullAt = g.tokenCenter(1);
    g.panStart(skullAt);
    expect(g.dragging, isFalse);
    expect(g.fieldPos[1], skullAt);
    expect(g.selectedIndex, isNot(1));

    g.debugForceHpZero(0);
    expect(g.debugUnitLife(0), UnitLife.retreating);
    g.panStart(g.tokenCenter(0));
    expect(g.dragging, isTrue);
    expect(g.selectedIndex, 0);
    final band = g.castleBandRect;
    g.panEnd(Offset(ownAt.dx, band.top + band.height * 0.72));
    expect(g.dragging, isFalse);
    expect(g.selectedIndex, 0);
    expect(g.dragTo, isNotNull);
    expect(g.fieldPos[1], skullAt);
    expect(g.debugLifeTipAt(0), '返城');
  });

  test('cavalry wave stays when the pin overlaps the body during the drag', () {
    final g = readyGame();
    final start = Offset(g.size.x * 0.30, g.watchH + g.fieldH * 0.55);
    g.debugRestageOwnEnemy(
      ownId: 'zhaoyun',
      ownAt: start,
      enemyAt: start + const Offset(0, -260),
    );
    g.panStart(start);
    g.panUpdate(start + const Offset(220, 0));
    const dt = 1 / 60.0;
    for (var i = 0; i < 40; i++) {
      g.debugStepPursuit(dt);
    }
    expect(g.debugChargeWaveVisible, isTrue);
    final kept = g.debugTravel01;
    final body = g.tokenCenter(0);
    g.panUpdate(body + const Offset(-6, 4));
    expect((g.fieldPos[0] - g.dragTo!).distance, lessThan(g.meleeContactDist));
    g.debugStepPursuit(dt);
    g.debugStepPursuit(dt);
    expect(g.dragging, isTrue);
    expect(g.debugChargeWaveVisible, isTrue);
    expect(g.debugTravel01, greaterThan(kept - 0.02));
    expect(g.debugHitLabel, isNot('突撃'));
  });

  test('a charging enemy closes on the spear and 迎擊 is the tip hit', () {
    final g = readyGame();
    g.setupMatchDemoField();
    int? spear;
    int? cav;
    for (var i = 0; i < g.field.length; i++) {
      if (spear == null &&
          !g.fieldIsEnemy[i] &&
          g.field[i].troop == TroopType.spear) {
        spear = i;
      }
      if (cav == null &&
          g.fieldIsEnemy[i] &&
          g.field[i].troop == TroopType.cavalry) {
        cav = i;
      }
    }
    expect(spear, isNotNull);
    expect(cav, isNotNull);
    expect(g.debugChargingEnemyIndex, cav);
    expect(g.debugSpearIndex, spear);
    // Soft Lock: face tip by MOVE toward the cav — idle auto-face is gone.
    final spearAt = g.fieldPos[spear!];
    final cavAt = g.fieldPos[cav!];
    final toward = cavAt - spearAt;
    final aim = spearAt + toward * (40 / toward.distance);
    g.panStart(spearAt);
    g.panEnd(aim);
    var settle = 0;
    while (g.dragTo != null && settle < 180) {
      g.debugStepPursuit(1 / 60);
      settle++;
    }
    expect(g.spearTipExtendedAt(spear), isTrue);
    final before = (g.fieldPos[cav] - g.fieldPos[spear]).distance;
    var guard = 0;
    while (g.debugRetreatCause(cav) != '迎擊' &&
        g.debugHitLabel != '迎擊' &&
        guard < 800) {
      g.debugStepPursuit(1 / 60);
      guard++;
    }
    expect((g.fieldPos[cav] - g.fieldPos[spear]).distance, lessThan(before - 10));
    expect(
      g.debugRetreatCause(cav) == '迎擊' || g.debugHitLabel == '迎擊',
      isTrue,
    );
    expect(g.inMeleeContact(g.tokenCenter(spear), g.tokenCenter(cav)), isFalse);
    expect(g.debugUnitHp(cav), 0);
  });

  test('moving bow does not pop 氣勢; stop then auto-fires', () {
    final g = readyGame();
    final at = Offset(g.size.x * 0.34, g.watchH + g.fieldH * 0.40);
    g.debugRestageOwnEnemy(
      ownId: 'sunquan',
      ownAt: at,
      // Off the march line: a bow that brushes the enemy is now chased into
      // 亂戰 once it stops (enemy_pursuit_test.dart), and 亂戰 holds the shot.
      enemyAt: at + const Offset(100, -90),
    );
    g.panStart(at);
    g.panUpdate(at + const Offset(180, 0));
    for (var i = 0; i < 60; i++) {
      g.debugStepPursuit(1 / 60);
    }
    expect(g.dragging, isTrue);
    expect(g.debugHitLabel, isNot('射'));
    expect(g.debugHitLabel, isNot('氣勢'));

    // Release far from enemy so march continues silent; then stop and shoot.
    g.panEnd(at + const Offset(40, 0));
    var settle = 0;
    while (g.dragTo != null && settle < 300) {
      g.debugStepPursuit(1 / 60);
      settle++;
    }
    expect(g.debugHitLabel, isNot('氣勢'));
    var guard = 0;
    while (g.debugHitLabel != '射' && guard < 400) {
      g.debugStepPursuit(1 / 60);
      guard++;
    }
    expect(g.debugHitLabel, '射');
  });

  test('clampPlayableCenter reaches 己城 enter depth for 歸城', () {
    final g = readyGame();
    final band = g.castleBandRect;
    final want = Offset(band.center.dx, band.top + band.height * TaisenGame.kCastleEnterDepth);
    final clamped = g.clampPlayableCenter(Offset(band.center.dx, g.size.y + 200));
    expect(clamped.dy, greaterThanOrEqualTo(want.dy - 0.5));
    expect(
      g.castleGateContains(clamped, currentlyIn: false),
      isTrue,
      reason: 'bottom clamp must allow park depth ≥ enter',
    );
  });
}
