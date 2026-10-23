import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/data/card_models.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';

import 'feel_gates_test.dart' show readyGame;

/// AUTH-GAP §6 SGE-06. Checklist AC1「2倍近い」/ 天 gate > wall.
/// After a prep completes (SGE-01..04 path), the gate takes clearly more castle
/// damage than the wall under the same siege tick. A uniform chip fails.
/// Qualitative only: no Official gate/wall mul and no hardened 2×.
/// Soft Pass ≠ Feel.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the gate nick is strictly larger and is not shipped as an exact 2×', () {
    final gate = TaisenGame.siegeNickFor(SiegeFace.gate);
    final wall = TaisenGame.siegeNickFor(SiegeFace.wall);
    expect(wall, greaterThan(0));
    expect(gate, greaterThan(wall));
    expect(gate, isNot(closeTo(wall * 2, 1e-9)));
  });

  test('the center opening is the gate; both flanks are wall', () {
    final g = readyGame();
    final w = g.size.x;
    final left = (w - w * TaisenGame.kSiegeGateSpanFrac) / 2;
    final right = left + w * TaisenGame.kSiegeGateSpanFrac;
    final y = g.enemyCastleZoneRect.center.dy;
    expect(g.siegeFaceAt(Offset(w * 0.5, y)), SiegeFace.gate);
    expect(g.siegeFaceAt(Offset(left, y)), SiegeFace.gate);
    expect(g.siegeFaceAt(Offset(left - 1, y)), SiegeFace.wall);
    expect(g.siegeFaceAt(Offset(right - 1, y)), SiegeFace.gate);
    expect(g.siegeFaceAt(Offset(right, y)), SiegeFace.wall);
    expect(g.siegeFaceAt(Offset(w * 0.05, y)), SiegeFace.wall);
    expect(g.siegeFaceAt(Offset(w * 0.95, y)), SiegeFace.wall);
  });

  test('a sweep across the enemy castle face lands two nicks, gate above wall', () {
    final gateDrops = <double>[];
    final wallDrops = <double>[];
    for (final fx in const [0.05, 0.15, 0.30, 0.36, 0.45, 0.5, 0.55, 0.64, 0.70, 0.85, 0.95]) {
      final r = _oneFullPrep(fx: fx, troop: TroopType.siege, enemy: false);
      expect(r.drop, closeTo(TaisenGame.siegeNickFor(r.face), 1e-9), reason: 'fx=$fx');
      (r.face == SiegeFace.gate ? gateDrops : wallDrops).add(r.drop);
    }
    expect(gateDrops, isNotEmpty);
    expect(wallDrops, isNotEmpty);
    final minGate = gateDrops.reduce((a, b) => a < b ? a : b);
    final maxWall = wallDrops.reduce((a, b) => a > b ? a : b);
    expect(minGate, greaterThan(maxWall));
    expect({...gateDrops, ...wallDrops}.length, 2, reason: 'uniform chip = Fail');
  });

  test('the same siege tick lands at the same time on gate and wall; only the nick differs', () {
    final gate = _sieger(fx: 0.5, troop: TroopType.siege, enemy: false);
    final wall = _sieger(fx: 0.1, troop: TroopType.siege, enemy: false);
    gate.debugStepPursuit(1);
    wall.debugStepPursuit(1);
    expect(gate.debugSiegePrep01(0), wall.debugSiegePrep01(0));
    expect(gate.debugSiegeCountdownSec(0), wall.debugSiegeCountdownSec(0));
    expect(gate.enemyCastle, wall.enemyCastle, reason: 'no chip before prep completes');
  });

  test('over several preps the gate takes clearly more than the wall', () {
    for (final troop in const [TroopType.siege, TroopType.bow]) {
      final gate = _sieger(fx: 0.5, troop: troop, enemy: false);
      final wall = _sieger(fx: 0.9, troop: troop, enemy: false);
      final g0 = gate.enemyCastle;
      final w0 = wall.enemyCastle;
      const preps = 3;
      for (var k = 0; k < preps; k++) {
        gate.debugStepPursuit(1 / TaisenGame.kSiegePrepFillPerSec);
        wall.debugStepPursuit(1 / TaisenGame.kSiegePrepFillPerSec);
      }
      expect(gate.debugSiegePrepsLanded(0), preps, reason: '$troop');
      expect(wall.debugSiegePrepsLanded(0), preps, reason: '$troop');
      final gateLoss = g0 - gate.enemyCastle;
      final wallLoss = w0 - wall.enemyCastle;
      expect(gateLoss, closeTo(preps * TaisenGame.kSiegeGateNick, 1e-9), reason: '$troop');
      expect(wallLoss, closeTo(preps * TaisenGame.kSiegeWallNick, 1e-9), reason: '$troop');
      expect(gateLoss, greaterThan(wallLoss), reason: '$troop');
    }
  });

  test('an enemy sieger on 己城 also hits the gate harder than the wall', () {
    final gate = _oneFullPrep(fx: 0.5, troop: TroopType.siege, enemy: true);
    final wall = _oneFullPrep(fx: 0.1, troop: TroopType.siege, enemy: true);
    expect(gate.face, SiegeFace.gate);
    expect(wall.face, SiegeFace.wall);
    expect(gate.drop, closeTo(TaisenGame.kSiegeGateNick, 1e-9));
    expect(wall.drop, closeTo(TaisenGame.kSiegeWallNick, 1e-9));
    expect(gate.drop, greaterThan(wall.drop));
  });
}

({SiegeFace face, double drop}) _oneFullPrep({
  required double fx,
  required TroopType troop,
  required bool enemy,
}) {
  final g = _sieger(fx: fx, troop: troop, enemy: enemy);
  final face = g.siegeFaceAt(g.fieldPos[0]);
  expect(g.debugSiegeFace(0), face.name);
  final before = enemy ? g.ownCastle : g.enemyCastle;
  g.debugStepPursuit(1 / TaisenGame.kSiegePrepFillPerSec);
  expect(g.debugSiegePrepsLanded(0), 1, reason: 'fx=$fx');
  final after = enemy ? g.ownCastle : g.enemyCastle;
  return (face: face, drop: before - after);
}

/// One stationary sieger in its enemy castle zone at [fx] of field width.
TaisenGame _sieger({required double fx, required TroopType troop, required bool enemy}) {
  final g = readyGame();
  final zone = enemy ? g.castleBandRect : g.enemyCastleZoneRect;
  final at = Offset(g.size.x * fx, zone.top + zone.height * 0.45);
  final card = Cost6Roster.all.firstWhere((c) => c.troop == troop);
  g.field
    ..clear()
    ..add(card);
  g.fieldPos
    ..clear()
    ..add(at);
  g.fieldIsEnemy
    ..clear()
    ..add(enemy);
  g.fieldInCastle
    ..clear()
    ..add(false);
  g.selectedIndex = enemy ? null : 0;
  g.dragging = false;
  g.dragTo = null;
  expect(g.inEnemyCastleZone(0), isTrue);
  expect(g.debugSiegePrepVisible(0), isTrue);
  return g;
}
