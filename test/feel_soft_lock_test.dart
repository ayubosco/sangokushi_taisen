import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/data/card_models.dart';
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

  test('bow drag hits the nearest enemy in the aim cone and misses off-aim', () {
    final g = readyGame();
    final at = Offset(g.size.x * 0.30, g.watchH + g.fieldH * 0.46);
    g.debugRestageOwnEnemy(
      ownId: 'sunquan',
      ownAt: at,
      enemyAt: at + const Offset(220, 0),
    );
    final off = Cost6Roster.all.firstWhere((c) => c.id == 'caocao');
    g.field.add(off);
    g.fieldIsEnemy.add(true);
    g.fieldInCastle.add(false);
    g.fieldPos.add(at + const Offset(36, 120));
    expect((g.tokenCenter(2) - at).distance, lessThan((g.tokenCenter(1) - at).distance));

    g.panStart(at);
    g.panEnd(at + const Offset(180, 0));
    const shot = TaisenGame.kBowShotBurstSec * TaisenGame.kRansenTickPerSec;
    expect(g.debugHitLabel, '射');
    expect(TaisenGame.kRansenMaxHp - g.debugUnitHp(1), closeTo(shot, 0.001));
    expect(g.debugUnitHp(2), TaisenGame.kRansenMaxHp);

    final away = readyGame();
    away.debugRestageOwnEnemy(
      ownId: 'sunquan',
      ownAt: at,
      enemyAt: at + const Offset(220, 0),
    );
    away.panStart(at);
    away.panEnd(at + const Offset(0, 150));
    expect(away.debugHitLabel, isNot('射'));
    expect(away.debugUnitHp(1), TaisenGame.kRansenMaxHp);

    final held = readyGame();
    held.debugRestageOwnEnemy(
      ownId: 'sunquan',
      ownAt: at,
      enemyAt: at + const Offset(200, 0),
    );
    held.panStart(at);
    held.panUpdate(at + const Offset(160, 0));
    held.debugStepPursuit(TaisenGame.kBowQuickAimSec);
    expect(held.dragging, isTrue);
    expect(held.debugHitLabel, '射');
    expect(
      TaisenGame.kRansenMaxHp - held.debugUnitHp(1),
      closeTo(shot, 0.001),
    );
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
    g.panEnd(Offset(ownAt.dx, band.top + band.height * 0.45));
    expect(g.dragging, isFalse);
    expect(g.selectedIndex, 0);
    expect(g.dragTo, isNotNull);
    expect(g.fieldPos[1], skullAt);
    expect(g.debugLifeTipAt(0), '散咗拖返城先復活');
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
    final before = (g.fieldPos[cav!] - g.fieldPos[spear!]).distance;
    var guard = 0;
    while (g.debugRetreatCause(cav) != '迎擊' &&
        g.debugHitLabel != '迎擊' &&
        guard < 500) {
      g.debugStepPursuit(1 / 60);
      guard++;
    }
    expect((g.fieldPos[cav] - g.fieldPos[spear]).distance, lessThan(before - 30));
    expect(
      g.debugRetreatCause(cav) == '迎擊' || g.debugHitLabel == '迎擊',
      isTrue,
    );
    expect(g.inMeleeContact(g.tokenCenter(spear), g.tokenCenter(cav)), isFalse);
    expect(g.debugUnitHp(cav), 0);
  });

  test('bow aim follows the touch and a moving archer does not pop 氣勢', () {
    final g = readyGame();
    final at = Offset(g.size.x * 0.34, g.watchH + g.fieldH * 0.40);
    g.debugRestageOwnEnemy(
      ownId: 'sunquan',
      ownAt: at,
      enemyAt: at + const Offset(210, 0),
    );
    final below = Cost6Roster.all.firstWhere((c) => c.id == 'caocao');
    g.field.add(below);
    g.fieldIsEnemy.add(true);
    g.fieldInCastle.add(false);
    g.fieldPos.add(at + const Offset(0, 200));

    g.panStart(at);
    g.panUpdate(at + const Offset(180, 0));
    g.debugStepPursuit(1 / 60);
    const shot = TaisenGame.kBowShotBurstSec * TaisenGame.kRansenTickPerSec;
    expect(g.debugHitLabel, '射');
    expect(TaisenGame.kRansenMaxHp - g.debugUnitHp(1), closeTo(shot, 0.001));
    expect(g.debugUnitHp(2), TaisenGame.kRansenMaxHp);

    g.debugSetUnitHp(1, TaisenGame.kRansenMaxHp);
    g.panUpdate(at + const Offset(0, 190));
    g.debugStepPursuit(TaisenGame.kBowAimRepeatSec);
    expect(TaisenGame.kRansenMaxHp - g.debugUnitHp(2), closeTo(shot, 0.001));
    expect(g.debugUnitHp(1), TaisenGame.kRansenMaxHp);
    expect(g.debugHitLabel, isNot('氣勢'));

    final march = readyGame();
    final from = Offset(march.size.x * 0.25, march.watchH + march.fieldH * 0.50);
    march.debugRestageOwnEnemy(
      ownId: 'sunquan',
      ownAt: from,
      enemyAt: from + const Offset(0, -240),
    );
    march.panStart(from);
    march.panEnd(from + const Offset(260, 0));
    var guard = 0;
    while (!march.auraActive && march.dragTo != null && guard < 500) {
      march.debugStepPursuit(1 / 60);
      guard++;
    }
    expect(march.auraActive, isTrue);
    expect(march.debugHitLabel, isNot('氣勢'));
  });
}
