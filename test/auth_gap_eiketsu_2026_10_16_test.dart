import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/data/card_models.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';

import 'feel_gates_test.dart' show readyGame;

/// Locks the 2026-10-16 英傑 foil gaps. These asserts describe today's
/// Soft Lock. They are not a Feel Pass. See docs/AUTH-GAP-EIKETSU-2026-10-16.md.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AUTH-GAP 槍擊: reversing the spear with no tip contact does not arm 迎撃', () {
    final g = readyGame();
    g.setupSession2Field();
    final spear = g.tutorialOwnIndex!;
    final cav = g.tutorialEnemyIndex!;
    final hp = g.debugUnitHp(cav);
    // Park the cavalry off the tip so a turn cannot be mistaken for contact.
    g.fieldPos[cav] = Offset(g.size.x * 0.92, g.watchH + 12);

    g.debugLockCardFacing(spear, 0);
    g.debugStepPursuit(1 / 60);
    expect(g.debugHitLabel, isNot('迎擊'));
    expect(g.debugGaritsuArmed, isFalse);

    g.debugLockCardFacing(spear, math.pi);
    g.debugStepPursuit(1 / 60);
    expect(g.debugHitLabel, isNot('迎擊'));
    expect(g.debugGaritsuArmed, isFalse);
    expect(g.debugTipScrapeArmed, isFalse);
    expect(g.debugUnitHp(cav), hp);
    expect(g.spearTipExtendedAt(spear), isTrue);
    expect(g.debugInRansen(spear), isFalse);
  });

  test('AUTH-GAP 計略: the seal does not spend 士氣 or the card cost', () {
    final g = readyGame();
    g.setupSession2Field();
    g.matchMorale = 8;
    final card = g.field[g.selectedIndex!];
    expect(card.strategyMorale, greaterThan(0));
    expect(card.intel, isNotEmpty);

    g.triggerStrategyFx(notifyTutorial: false);

    expect(g.matchMorale, 8);
    expect(g.debugStrategyCastAt, isNotNull);
    expect(g.debugHitLabel, isNot('迎擊'));
    expect(g.debugHitLabel, isNot('雷擊'));
  });

  test('AUTH-GAP 弓攻城: a standing bow in the enemy castle zone fills no prep', () {
    final g = readyGame();
    final at = _inEnemyZone(g);
    final castle = g.enemyCastle;
    _placeOwn(g, at, TroopType.bow);

    expect(g.inEnemyCastleZone(0), isTrue);
    expect(g.debugSiegePrepVisible(0), isFalse);
    g.debugStepPursuit(0.4);
    expect(g.debugSiegePrep01(0), 0);
    expect(g.debugSiegePrepVisible(0), isFalse);
    expect(g.enemyCastle, castle);
    expect(g.debugHitLabel, isNot('攻城'));
  });
}

Offset _inEnemyZone(TaisenGame g) {
  final zone = g.enemyCastleZoneRect;
  return Offset(zone.center.dx, zone.top + zone.height * 0.45);
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
