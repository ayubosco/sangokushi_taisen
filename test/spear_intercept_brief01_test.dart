import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/data/card_models.dart';
import 'package:sangokushi_taisen/game/fx_windows.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';
import 'package:sangokushi_taisen/game/unit_life.dart';

import 'feel_gates_test.dart' show readyGame;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tip is ahead of the body before any hit, and there is no 迎撃 button', () {
    final g = readyGame();
    final at = _fieldAt(g, 0.42, 0.55);
    _placeOwn(g, at, TroopType.spear);
    g.ownFacing = 0;
    expect(g.spearTipExtendedAt(0), isTrue);
    expect(g.debugHitLabel, isNot('迎擊'));
    expect(g.debugTipScrapeArmed, isFalse);
    final tip = g.spearTipAt(0);
    final center = g.tokenCenter(0);
    expect((tip - center).distance, closeTo(TaisenGame.kSpearTipReach, 0.01));
    expect(tip.dy, lessThan(center.dy), reason: 'facing 0 puts the tip up-field of the body');
    expect(g.inMeleeContact(center, tip), isFalse);
    expect(TaisenGame.kSpearTipReach, closeTo(48 * 1.28, 0.001));
    expect(TaisenGame.kSpearTipHitR, 18);
    expect(g.floatingActionHitRect('迎撃'), Rect.zero);
    expect(g.floatingActionHitRect('迎擊'), Rect.zero);
    expect(g.floatingActionHitRect('計略'), Rect.zero);
  });

  test('idle tip aimed away does not 迎撃; a march that tracks the cav does', () {
    final g = readyGame();
    g.setupSession2Field();
    expect(g.spearTipExtendedAt(0), isTrue);
    expect(g.tipFacingAt(0), closeTo(TaisenGame.kSpearIdleMissFacing, 0.001));
    g.debugArmEnemyChargeAura();
    for (var i = 0; i < 60 * 4; i++) {
      g.debugStepPursuit(1 / 60);
      expect(g.debugHitLabel, isNot('迎擊'), reason: 'frame $i');
    }
    expect(g.debugTipScrapeArmed, isFalse);
    expect(g.debugGaritsuArmed, isFalse);
    expect(g.debugInterceptDouble, isFalse);
    expect(g.spearTipExtendedAt(0), isTrue);
    expect(g.debugInRansen(0), isFalse);
    expect(g.debugInRansen(2), isFalse);
    final gap = (g.tokenCenter(2) - g.tokenCenter(0)).distance;
    expect(gap, greaterThan(g.meleeContactDist));
    expect(gap, closeTo(TaisenGame.kSpearTipReach, TaisenGame.kSpearTipHitR));
    expect(
      (g.spearTipAt(0) - g.tokenCenter(2)).distance,
      greaterThan(TaisenGame.kSpearTipHitR),
    );

    final spear = g.tokenCenter(0);
    final enemy = g.tokenCenter(2);
    final dir = enemy - spear;
    g.selectedIndex = 0;
    g.panStart(spear);
    g.panEnd(spear + dir / dir.distance * 36);
    g.debugStepPursuit(1 / 60);
    expect(g.debugHitLabel, '迎擊');
    expect(g.debugTipScrapeArmed, isTrue);
    expect(g.debugGaritsuArmed, isTrue);
    expect(g.debugInterceptDouble, isFalse, reason: 'aura 1.32 is not 二倍');
    expect(g.debugGeigekiReadScale, 1);
    expect(g.debugHitFlashLeft, lessThanOrEqualTo(FxWindows.toSeconds(0.3) + 1e-9));
    expect(g.debugTipScrapeLeft, lessThanOrEqualTo(FxWindows.toSeconds(0.3) + 1e-9));
    expect(g.debugRetreatCause(2), '迎擊');
    expect(g.spearTipExtendedAt(0), isTrue);
  });

  test('card rotate while marching does not swing the tip onto the cav', () {
    final g = readyGame();
    final at = _fieldAt(g, 0.40, 0.50);
    _placeOwn(g, at, TroopType.spear);
    g.debugLockCardFacing(0, 0);
    g.panStart(at);
    g.panEnd(at + const Offset(0, 90));
    g.debugStepPursuit(1 / 60);
    expect(g.tipFacingAt(0), closeTo(math.pi, 0.25));
    expect(g.cardFacingAt(0), closeTo(0, 0.05));
    final cardTip = g.tokenCenter(0) + const Offset(0, -TaisenGame.kSpearTipReach);
    _addEnemy(g, cardTip);
    g.enemyFacing = math.pi;
    g.debugArmEnemyChargeAura();
    g.debugStepPursuit(1 / 60);
    expect(g.debugHitLabel, isNot('迎擊'));
    expect(g.debugGaritsuArmed, isFalse);
    expect(
      (g.spearTipAt(0) - g.tokenCenter(1)).distance,
      greaterThan(TaisenGame.kSpearTipHitR),
    );

    g.fieldPos[1] = g.tokenCenter(0) + const Offset(280, 0);
    var frames = 0;
    while (g.dragTo != null && frames < 400) {
      g.debugStepPursuit(1 / 60);
      frames++;
    }
    expect(g.dragTo, isNull);
    expect(g.tipFacingAt(0), closeTo(0, 0.05), reason: 'settle uses the card, not the travel');
    expect(g.debugHitLabel, isNot('迎擊'));
  });

  test('a second idle spear does not inherit the mover facing', () {
    final g = readyGame();
    final at = _fieldAt(g, 0.30, 0.55);
    _placeOwn(g, at, TroopType.spear);
    g.ownFacing = 0;
    _addOwn(g, at + const Offset(90, 0), TroopType.spear);
    g.selectedIndex = 0;
    g.panStart(at);
    g.panEnd(at + const Offset(0, 80));
    g.debugStepPursuit(1 / 60);
    expect(g.tipFacingAt(0), closeTo(math.pi, 0.25));
    expect(g.tipFacingAt(1), closeTo(0, 0.05));
    expect(g.spearTipExtendedAt(0), isTrue);
    expect(g.spearTipExtendedAt(1), isTrue);
  });

  test('front 180° 迎撃; rear chase and open 1.1 cav do not', () {
    final rear = readyGame();
    final at = _fieldAt(rear, 0.42, 0.55);
    _placeOwn(rear, at, TroopType.spear);
    rear.ownFacing = 0;
    _addEnemy(rear, rear.spearTipAt(0) + const Offset(0, -12));
    rear.enemyFacing = 0;
    rear.debugArmEnemyChargeAura();
    rear.debugStepPursuit(1 / 60);
    expect(rear.debugHitLabel, isNot('迎擊'));
    expect(rear.debugTipScrapeArmed, isFalse);
    // Rear overlap is a light tip tick, not 迎撃 and not 亂戰.
    expect(
      rear.debugUnitHp(1),
      closeTo(TaisenGame.kRansenMaxHp - TaisenGame.kRansenTickPerSec, 0.01),
    );

    final front = readyGame();
    _placeOwn(front, at, TroopType.spear);
    front.ownFacing = 0;
    _addEnemy(front, front.spearTipAt(0));
    front.enemyFacing = math.pi;
    front.debugArmEnemyChargeAura();
    front.debugStepPursuit(1 / 60);
    expect(front.debugHitLabel, '迎擊');
    expect(front.debugGaritsuArmed, isTrue);
    expect(front.debugInterceptDouble, isFalse);
    expect(front.debugInRansen(0), isFalse);

    final slow = readyGame();
    _placeOwn(slow, at, TroopType.spear);
    slow.ownFacing = 0;
    _addEnemy(slow, slow.spearTipAt(0));
    slow.enemyFacing = math.pi;
    expect(slow.debugInterceptMoveSpeedForTest(1), closeTo(1.1, 0.001));
    slow.debugStepPursuit(1 / 60);
    expect(slow.debugHitLabel, isNot('迎擊'));
    expect(slow.debugGaritsuArmed, isFalse);
    expect(slow.debugTipScrapeArmed, isFalse);
    expect(
      slow.debugUnitHp(1),
      closeTo(TaisenGame.kRansenMaxHp - TaisenGame.kRansenTickPerSec, 0.01),
    );
    expect(slow.spearTipExtendedAt(0), isTrue);
  });

  test('speed > 1.3 without aura 迎撃; 1.3 does not; ≥2.0 is the 二倍 read', () {
    final at = _fieldAt(readyGame(), 0.42, 0.50);

    final edge = readyGame();
    _placeOwn(edge, at, TroopType.spear);
    edge.ownFacing = 0;
    _addTroop(edge, edge.spearTipAt(0), TroopType.infantry, enemy: true);
    edge.enemyFacing = math.pi;
    edge.debugSetMoveSpeed(1, 1.3);
    edge.debugStepPursuit(1 / 60);
    expect(edge.debugHitLabel, isNot('迎擊'));
    expect(
      edge.debugUnitHp(1),
      closeTo(TaisenGame.kRansenMaxHp - TaisenGame.kRansenTickPerSec, 0.01),
    );

    final fast = readyGame();
    _placeOwn(fast, at, TroopType.spear);
    fast.ownFacing = 0;
    _addTroop(fast, fast.spearTipAt(0), TroopType.infantry, enemy: true);
    fast.enemyFacing = math.pi;
    fast.debugSetMoveSpeed(1, 1.31);
    final before = fast.debugUnitHp(1);
    fast.debugStepPursuit(1 / 60);
    expect(fast.debugHitLabel, '迎擊');
    expect(fast.debugInterceptDouble, isFalse);
    expect(fast.debugGeigekiReadScale, 1);
    expect(fast.debugGaritsuArmed, isTrue);
    expect(before - fast.debugUnitHp(1), closeTo(TaisenGame.kRansenTickPerSec, 0.001));
    expect(fast.debugUnitLife(1), UnitLife.alive);

    final doubled = readyGame();
    _placeOwn(doubled, at, TroopType.spear);
    doubled.ownFacing = 0;
    _addTroop(doubled, doubled.spearTipAt(0), TroopType.infantry, enemy: true);
    doubled.enemyFacing = math.pi;
    doubled.debugSetMoveSpeed(1, TaisenGame.kDoubleInterceptSpeed);
    final hp = doubled.debugUnitHp(1);
    doubled.debugStepPursuit(1 / 60);
    expect(doubled.debugHitLabel, '迎擊');
    expect(doubled.debugInterceptDouble, isTrue);
    expect(doubled.debugGeigekiReadScale, TaisenGame.kDoubleInterceptReadScale);
    expect(doubled.debugGaritsuArmed, isTrue);
    // Existing playtest stub doubled. Not the wiki +40.
    expect(hp - doubled.debugUnitHp(1), closeTo(TaisenGame.kRansenTickPerSec * 2, 0.001));
    expect(hp - doubled.debugUnitHp(1), isNot(closeTo(40, 0.1)));
    expect(doubled.debugHitFlashLeft, lessThanOrEqualTo(FxWindows.toSeconds(0.3) + 1e-9));
  });

  test('approach scrape inside the hit radius but short of the tip does not 迎撃', () {
    final g = readyGame();
    final at = _fieldAt(g, 0.42, 0.55);
    _placeOwn(g, at, TroopType.spear);
    g.ownFacing = 0;
    final tip = g.spearTipAt(0);
    // 12px beyond the tip, still inside the unchanged 18px radius, front 180°.
    _addEnemy(g, tip + const Offset(0, -12));
    g.enemyFacing = math.pi;
    g.debugArmEnemyChargeAura();
    expect((g.spearTipAt(0) - g.tokenCenter(1)).distance, lessThan(TaisenGame.kSpearTipHitR));
    expect(TaisenGame.kSpearTipReach, closeTo(48 * 1.28, 0.001));
    expect(TaisenGame.kSpearTipHitR, 18);
    g.debugStepPursuit(1 / 60);
    expect(g.debugHitLabel, isNot('迎擊'));
    expect(g.debugGaritsuArmed, isFalse);
    expect(g.debugTipScrapeArmed, isFalse);
    expect(
      g.debugUnitHp(1),
      closeTo(TaisenGame.kRansenMaxHp - TaisenGame.kRansenTickPerSec, 0.01),
    );

    g.fieldPos[1] = g.spearTipAt(0);
    g.debugStepPursuit(1 / 60);
    expect(g.debugHitLabel, '迎擊');
    expect(g.debugGaritsuArmed, isTrue);
    expect(g.debugInRansen(0), isFalse);
  });

  test('a closing aura cavalry does not 迎撃 until it reaches the tip', () {
    final g = readyGame();
    g.setupSession2Field();
    final spear = g.tokenCenter(0);
    final enemy = g.tokenCenter(2);
    final delta = enemy - spear;
    g.ownFacing = math.atan2(delta.dx, -delta.dy);
    g.debugArmEnemyChargeAura();
    var fired = false;
    var firedWhileShort = false;
    for (var i = 0; i < 60 * 4 && !fired; i++) {
      g.debugStepPursuit(1 / 60);
      final body = g.tokenCenter(0);
      final them = g.tokenCenter(2);
      final tip = g.spearTipAt(0);
      final forward = tip - body;
      final reach = forward.distance;
      final along = ((them.dx - body.dx) * forward.dx + (them.dy - body.dy) * forward.dy) / reach;
      final hit = g.debugTipScrapeArmed || g.debugRetreatCause(2) == '迎擊';
      if (hit) {
        fired = true;
        if (along > reach + 0.05) firedWhileShort = true;
        expect(along, lessThanOrEqualTo(reach + 0.05));
        expect((tip - them).distance, lessThanOrEqualTo(TaisenGame.kSpearTipHitR));
      } else if ((tip - them).distance <= TaisenGame.kSpearTipHitR && along > reach) {
        expect(g.debugRetreatCause(2), isNot('迎擊'), reason: 'frame $i still short of the tip');
        expect(g.debugTipScrapeArmed, isFalse);
      }
    }
    expect(firedWhileShort, isFalse);
    expect(fired, isTrue);
    expect(g.debugInterceptDouble, isFalse);
    expect(g.debugRetreatCause(2), '迎擊');
  });

  test('a direction change turns the tip before the body steps', () {
    final g = readyGame();
    final at = _fieldAt(g, 0.40, 0.55);
    _placeOwn(g, at, TroopType.spear);
    g.ownFacing = math.pi;
    g.panStart(at);
    g.panEnd(at + const Offset(0, -80));
    expect(g.tipFacingAt(0), closeTo(0, 0.08));
    expect(g.tokenCenter(0), at, reason: 'aim is instant; the body has not walked');

    final body = g.tokenCenter(0);
    g.panStart(body);
    g.panUpdate(body + const Offset(120, 0));
    expect(g.tipFacingAt(0), closeTo(math.pi / 2, 0.08));
    expect(g.tokenCenter(0), body);
    expect(g.cardFacingAt(0), isNot(closeTo(0, 0.2)));
  });

  test('tip retracts in 亂戰 and on a sieging body, and returns when the mash ends', () {
    final g = readyGame();
    final at = _fieldAt(g, 0.42, 0.48);
    _placeOwn(g, at, TroopType.spear);
    expect(g.spearTipExtendedAt(0), isTrue);
    _addEnemy(g, at);
    g.debugStepPursuit(1 / 60);
    expect(g.debugInRansen(0), isTrue);
    expect(g.spearTipExtendedAt(0), isFalse);
    expect(g.debugHitLabel, isNot('迎擊'));
    g.fieldPos[1] = g.fieldPos[0] + const Offset(240, 0);
    g.debugStepPursuit(1 / 60);
    expect(g.debugInRansen(0), isFalse);
    expect(g.spearTipExtendedAt(0), isTrue);

    final siege = readyGame();
    final zone = siege.enemyCastleZoneRect;
    _placeOwn(siege, Offset(zone.center.dx, zone.top + zone.height * 0.45), TroopType.siege);
    expect(siege.debugSiegePrepVisible(0), isTrue);
    expect(siege.spearTipExtendedAt(0), isFalse);

    final spearInZone = readyGame();
    _placeOwn(
      spearInZone,
      Offset(zone.center.dx, zone.top + zone.height * 0.45),
      TroopType.spear,
    );
    expect(spearInZone.debugSiegePrepVisible(0), isFalse);
    expect(spearInZone.spearTipExtendedAt(0), isTrue);
  });
}

Offset _fieldAt(TaisenGame g, double xFrac, double yFrac) {
  return Offset(g.size.x * xFrac, g.watchH + g.fieldH * yFrac);
}

void _placeOwn(TaisenGame g, Offset at, TroopType troop) {
  final card = Cost6Roster.all.firstWhere((c) => c.troop == troop);
  g.field
    ..clear()
    ..add(card);
  g.fieldPos
    ..clear()
    ..add(at);
  g.fieldIsEnemy
    ..clear()
    ..add(false);
  g.fieldInCastle
    ..clear()
    ..add(false);
  g.selectedIndex = 0;
  g.dragging = false;
  g.dragTo = null;
}

void _addEnemy(TaisenGame g, Offset at) {
  _addTroop(g, at, TroopType.cavalry, enemy: true);
}

void _addOwn(TaisenGame g, Offset at, TroopType troop) {
  _addTroop(g, at, troop, enemy: false);
}

void _addTroop(TaisenGame g, Offset at, TroopType troop, {required bool enemy}) {
  final card = enemy && troop == TroopType.cavalry
      ? Cost6Roster.all.firstWhere((c) => c.id == 'caocao')
      : Cost6Roster.all.firstWhere((c) => c.troop == troop && c.id != 'caocao');
  g.field.add(card);
  g.fieldIsEnemy.add(enemy);
  g.fieldInCastle.add(false);
  g.fieldPos.add(at);
}
