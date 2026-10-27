import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/data/card_models.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';

import 'feel_gates_test.dart' show readyGame;

/// AUTH-GAP §6 SGE-05 / BOW-10. A defending bow slows the enemy siege gauge
/// only while it could loose: standing, not 亂戰, not 歸城, sieger in range.
/// Reuses the standing-fire gate and the half-field range (AUTH-GAP §3).
/// Soft Pass ≠ Feel. No Official bow range, siege rate, or mul is asserted.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('enemy siege on our gate', () {
    test('a standing own bow slows the gauge; a non-bow defender does not', () {
      final open = _enemySiegeOnOwnGate();
      _addBody(open.g, open.defendAt, TroopType.infantry, enemy: false);
      open.g.debugStepPursuit(1);
      expect(open.g.debugSiegePrepSlowed(open.e), isFalse);
      expect(
        open.g.debugSiegePrep01(open.e),
        closeTo(TaisenGame.kSiegePrepFillPerSec, 1e-9),
      );

      final pressed = _enemySiegeOnOwnGate();
      _addBody(pressed.g, pressed.defendAt, TroopType.bow, enemy: false);
      final b = pressed.g.field.length - 1;
      expect(pressed.g.inMeleeContact(pressed.g.tokenCenter(b), pressed.at), isFalse);
      pressed.g.debugStepPursuit(1);
      expect(pressed.g.debugSiegePrepSlowed(pressed.e), isTrue);
      expect(
        pressed.g.debugSiegePrep01(pressed.e),
        closeTo(TaisenGame.kSiegePrepFillPerSec * TaisenGame.kSiegePrepBowSlowMul, 1e-6),
      );
      expect(
        pressed.g.debugSiegeCountdownSec(pressed.e),
        greaterThan(open.g.debugSiegeCountdownSec(open.e)),
      );
    });

    test('a marching own bow does not slow the gauge', () {
      final s = _enemySiegeOnOwnGate();
      _addBody(s.g, s.defendAt, TroopType.bow, enemy: false);
      final b = s.g.field.length - 1;
      s.g.selectedIndex = b;
      s.g.dragTo = s.defendAt + const Offset(48, 0);
      s.g.debugStepPursuit(0.1);
      expect(s.g.pinnedMarchAt(b), isTrue);
      expect(s.g.debugSiegePrepSlowed(s.e), isFalse);
      expect(
        s.g.debugSiegePrep01(s.e),
        closeTo(0.1 * TaisenGame.kSiegePrepFillPerSec, 1e-9),
      );
    });

    test('a finger-held own bow does not slow; letting go restores the slow', () {
      final s = _enemySiegeOnOwnGate();
      _addBody(s.g, s.defendAt, TroopType.bow, enemy: false);
      final b = s.g.field.length - 1;
      s.g.selectedIndex = b;
      s.g.dragging = true;
      s.g.debugStepPursuit(0.4);
      expect(s.g.debugSiegePrepSlowed(s.e), isFalse);

      s.g.dragging = false;
      final before = s.g.debugSiegePrep01(s.e);
      s.g.debugStepPursuit(0.4);
      expect(s.g.debugSiegePrepSlowed(s.e), isTrue);
      expect(
        s.g.debugSiegePrep01(s.e) - before,
        closeTo(0.4 * TaisenGame.kSiegePrepFillPerSec * TaisenGame.kSiegePrepBowSlowMul, 1e-6),
      );
    });

    test('an own bow parked in 歸城 does not slow the gauge', () {
      final s = _enemySiegeOnOwnGate();
      _addBody(s.g, s.defendAt, TroopType.bow, enemy: false);
      final b = s.g.field.length - 1;
      s.g.fieldInCastle[b] = true;
      s.g.debugStepPursuit(1);
      expect(s.g.debugSiegePrepSlowed(s.e), isFalse);
      expect(
        s.g.debugSiegePrep01(s.e),
        closeTo(TaisenGame.kSiegePrepFillPerSec, 1e-9),
      );
    });

    test('an own bow locked in 亂戰 does not slow the gauge', () {
      final s = _enemySiegeOnOwnGate();
      _addBody(s.g, s.defendAt, TroopType.bow, enemy: false);
      final b = s.g.field.length - 1;
      _addBody(s.g, s.defendAt, TroopType.infantry, enemy: true);
      s.g.debugStepPursuit(0.5);
      expect(s.g.debugInRansen(b), isTrue);
      expect(s.g.debugInRansen(s.e), isFalse);
      expect(s.g.debugSiegePrepSlowed(s.e), isFalse);
    });
  });

  group('bow siege on the enemy gate', () {
    test('an own bow 攻城中 is slowed by a standing enemy bow, not by a spear', () {
      final open = _ownBowOnEnemyGate();
      _addBody(open.g, open.at + const Offset(0, 180), TroopType.spear, enemy: true);
      open.g.debugStepPursuit(1);
      expect(open.g.debugSiegeCaption(0), TaisenGame.kSiegingCaption);
      expect(open.g.debugSiegePrepSlowed(0), isFalse);

      final pressed = _ownBowOnEnemyGate();
      _addBody(pressed.g, pressed.at + const Offset(0, 180), TroopType.bow, enemy: true);
      pressed.g.debugStepPursuit(1);
      expect(pressed.g.debugSiegeCaption(0), TaisenGame.kSiegingCaption);
      expect(pressed.g.debugSiegePrepSlowed(0), isTrue);
      expect(pressed.g.debugSiegePrep01(0), lessThan(open.g.debugSiegePrep01(0)));
    });

    test('an enemy bow in 亂戰 does not slow the own bow 攻城中', () {
      final s = _ownBowOnEnemyGate();
      final bowAt = s.at + const Offset(0, 180);
      _addBody(s.g, bowAt, TroopType.bow, enemy: true);
      final b = s.g.field.length - 1;
      _addBody(s.g, bowAt, TroopType.infantry, enemy: false);
      s.g.debugStepPursuit(0.5);
      expect(s.g.debugInRansen(b), isTrue);
      expect(s.g.debugInRansen(0), isFalse);
      expect(s.g.debugSiegePrepSlowed(0), isFalse);
      expect(
        s.g.debugSiegePrep01(0),
        closeTo(0.5 * TaisenGame.kSiegePrepFillPerSec, 1e-9),
      );
    });

    test('the slow is a fill scale only; the completed nick keeps gate > wall', () {
      final s = _ownBowOnEnemyGate();
      _addBody(s.g, s.at + const Offset(0, 180), TroopType.bow, enemy: true);
      final before = s.g.enemyCastle;
      const need = 1 / (TaisenGame.kSiegePrepFillPerSec * TaisenGame.kSiegePrepBowSlowMul);
      for (var t = 0.0; t < need + 0.05; t += 0.25) {
        s.g.debugStepPursuit(0.25);
      }
      expect(s.g.debugSiegePrepsLanded(0), 1);
      expect(before - s.g.enemyCastle, closeTo(TaisenGame.kSiegeGateNick, 1e-6));
    });
  });
}

typedef _Siege = ({TaisenGame g, int e, Offset at, Offset defendAt});

/// Own decoy far from both castles at 0, enemy siege on our gate at 1.
_Siege _enemySiegeOnOwnGate() {
  final g = readyGame();
  final band = g.castleBandRect;
  final at = Offset(band.center.dx, band.top + band.height * 0.4);
  _placeOwn(g, Offset(g.size.x * 0.12, g.watchH + g.fieldH * 0.3), TroopType.siege);
  g.selectedIndex = null;
  _addBody(g, at, TroopType.siege, enemy: true);
  const e = 1;
  expect(g.inEnemyCastleZone(e), isTrue);
  final defendAt = Offset(at.dx, at.dy - g.fieldH * 0.3);
  expect((defendAt - at).distance, lessThan(g.fieldH * 0.5));
  return (g: g, e: e, at: at, defendAt: defendAt);
}

/// Own bow at 0 standing on the enemy gate.
({TaisenGame g, Offset at}) _ownBowOnEnemyGate() {
  final g = readyGame();
  final zone = g.enemyCastleZoneRect;
  final at = Offset(zone.center.dx, zone.top + zone.height * 0.45);
  _placeOwn(g, at, TroopType.bow);
  g.selectedIndex = null;
  expect(g.debugSiegeFace(0), 'gate');
  return (g: g, at: at);
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

void _addBody(TaisenGame g, Offset at, TroopType troop, {required bool enemy}) {
  final card = Cost6Roster.all.firstWhere(
    (c) => c.troop == troop && (enemy || !g.field.contains(c)),
  );
  g.field.add(card);
  g.fieldIsEnemy.add(enemy);
  g.fieldInCastle.add(false);
  g.fieldPos.add(at);
}
