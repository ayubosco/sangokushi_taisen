import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';
import 'package:sangokushi_taisen/game/troop_retreat_visual_verify.dart';
import 'package:sangokushi_taisen/game/unit_life.dart';

/// Soft polish ×3 (Soft Gate leftover): R1 返城 tip, R2 落點 label, CAV contact stack.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TaisenGame sized() {
    final g = TaisenGame();
    g.onGameResize(Vector2(402, 746));
    return g;
  }

  void paint(TaisenGame g) {
    final rec = ui.PictureRecorder();
    g.render(Canvas(rec));
    rec.endRecording().dispose();
  }

  Rect fieldOf(TaisenGame g) => Rect.fromLTWH(0, g.watchH, g.size.x, g.size.y - g.watchH);

  Rect cardAt(TaisenGame g, Offset c) =>
      Rect.fromCenter(center: c, width: g.tokenCardSize.width, height: g.tokenCardSize.height);

  bool inside(Rect outer, Rect inner) =>
      inner.left >= outer.left - 0.01 &&
      inner.top >= outer.top - 0.01 &&
      inner.right <= outer.right + 0.01 &&
      inner.bottom <= outer.bottom + 0.01;

  group('P1 R1 返城 tip under 撤退', () {
    void expectTipClear(TaisenGame g) {
      g.debugForceHpZero(0);
      expect(g.debugUnitLife(0), UnitLife.retreating);
      expect(g.debugHitLabel, '撤退');
      expect(g.debugLifeTipAt(0), '返城');
      paint(g);

      final c = g.tokenCenter(0);
      final tip = g.debugRetreatTipRect(0);
      expect(tip, isNotNull);
      final splash = g.retreatSplashRect(c);
      expect(tip!.top - splash.bottom, greaterThanOrEqualTo(TaisenGame.kRetreatTipGapPx));
      // Not under the HP bar / number that sit above the card top.
      expect(tip.top, greaterThanOrEqualTo(cardAt(g, c).bottom));
      expect(inside(fieldOf(g), tip), isTrue, reason: 'tip $tip clipped by ${fieldOf(g)}');
    }

    test('mid-field: tip sits below the splash with ≥8 clear and stays on the field', () {
      final g = sized();
      g.debugRestageOwnEnemy(
        ownId: 'zhaoyun',
        ownAt: Offset(g.size.x * 0.42, g.watchH + g.fieldH * 0.4),
        enemyAt: Offset(g.size.x * 0.85, g.watchH + 40),
      );
      expectTipClear(g);
    });

    test('right edge: the whole tip stays on screen', () {
      final g = sized();
      g.debugRestageOwnEnemy(
        ownId: 'zhaoyun',
        ownAt: Offset(g.size.x - 12, g.watchH + g.fieldH * 0.4),
        enemyAt: Offset(40, g.watchH + 40),
      );
      expectTipClear(g);
    });

    test('the tip keeps its slot after the splash decays', () {
      final g = sized();
      g.debugRestageOwnEnemy(
        ownId: 'zhaoyun',
        ownAt: Offset(g.size.x * 0.42, g.watchH + g.fieldH * 0.4),
        enemyAt: Offset(g.size.x * 0.85, g.watchH + 40),
      );
      g.debugForceHpZero(0);
      paint(g);
      final first = g.debugRetreatTipRect(0);
      g.debugDecayCombatFx(TaisenGame.kRetreatSplashSec + 0.1);
      expect(g.debugHitLabel, isEmpty);
      paint(g);
      expect(g.debugRetreatTipRect(0), first);
    });
  });

  group('P2 R2 落點 label', () {
    TaisenGame retreatToCastle() {
      final g = sized();
      final band = g.castleBandRect;
      g.debugRestageOwnEnemy(
        ownId: 'zhaoyun',
        ownAt: Offset(band.center.dx, band.top - 120),
        enemyAt: Offset(60, g.watchH + 60),
      );
      g.debugForceHpZero(0);
      g.debugStepPursuit(1.2);
      g.panStart(g.tokenCenter(0));
      g.panEnd(Offset(band.center.dx, band.bottom - 6));
      return g;
    }

    test('walking skull: label sits above the pin card top, never off the bottom', () {
      final g = retreatToCastle();
      for (var k = 0; k < 12; k++) {
        g.debugStepPursuit(1 / 60);
      }
      expect(g.debugUnitLife(0), UnitLife.retreating);
      expect(g.pinnedMarchAt(0), isTrue);
      paint(g);
      final label = g.debugLandingLabelRect;
      expect(label, isNotNull);
      expect(label!.bottom, lessThanOrEqualTo(cardAt(g, g.dragTo!).top + 0.01));
      expect(inside(fieldOf(g), label), isTrue, reason: 'label $label clipped by ${fieldOf(g)}');
    });

    test('reviving in 己城 with the pin up: label inside the grey card under the timer', () {
      final g = retreatToCastle();
      var guard = 0;
      while (g.debugUnitLife(0) != UnitLife.inCastleReviving && guard < 900) {
        g.debugStepPursuit(1 / 60);
        guard++;
      }
      expect(g.debugUnitLife(0), UnitLife.inCastleReviving);
      // Hold the pin on the bottom of the band, as a device frame can catch it.
      g.selectedIndex = 0;
      g.dragTo = Offset(g.castleBandRect.center.dx, g.castleBandRect.bottom - 6);
      expect(g.pinnedMarchAt(0), isTrue);
      paint(g);

      final label = g.debugLandingLabelRect;
      expect(label, isNotNull);
      final face = cardAt(g, g.clampPlayableCenter(g.tokenCenter(0)));
      expect(inside(face, label!), isTrue, reason: 'label $label outside card $face');
      expect(label.top, greaterThan(face.center.dy), reason: 'label sits under the centred timer');
      expect(label.bottom, lessThanOrEqualTo(g.size.y));
    });
  });

  group('P3 CAV contact card stack', () {
    test('contact-top window is 0.3–0.5s', () {
      expect(TaisenGame.kContactTopSec, inInclusiveRange(0.3, 0.5));
    });

    test('突撃 paints the attacker above the defender, then the stack returns', () {
      final g = sized();
      final at = Offset(g.size.x / 2, g.watchH + g.fieldH * 0.45);
      g.debugRestageOwnEnemy(ownId: 'zhaoyun', ownAt: at, enemyAt: at);
      expect(g.debugTokenPaintOrder, [0, 1]);

      g.flashHit(0, '突撃');
      expect(g.debugTokenPaintOrder, [1, 0]);

      g.debugDecayCombatFx(TaisenGame.kContactTopSec - 0.05);
      expect(g.debugTokenPaintOrder.last, 0);

      g.debugDecayCombatFx(0.1);
      expect(g.debugTokenPaintOrder, [0, 1]);
    });

    test('other splashes keep the field order', () {
      final g = sized();
      final at = Offset(g.size.x / 2, g.watchH + g.fieldH * 0.45);
      g.debugRestageOwnEnemy(ownId: 'zhaoyun', ownAt: at, enemyAt: at);
      g.flashHit(0, '迎擊');
      expect(g.debugTokenPaintOrder, [0, 1]);
      g.flashHit(0, '氣勢');
      expect(g.debugTokenPaintOrder, [0, 1]);
    });

    test('real CAV contact frame: attacker on top, cyan ≤1.5 token', () async {
      final g = sized();
      List<int>? orderAtHit;
      final script = TroopRetreatVisualVerify(
        game: g,
        step: () async => g.debugStepPursuit(1 / 60),
        hold: (shot) async {
          if (shot.id == 'CAV') orderAtHit = g.debugTokenPaintOrder;
        },
      );
      await script.run();
      expect(orderAtHit, isNotNull);
      expect(orderAtHit!.last, 0, reason: 'own cavalry (attacker) paints last at 突撃');

      final cap = g.tokenCardSize.width * 1.5;
      expect(g.debugPunchCyanRadius(charge: true), lessThanOrEqualTo(cap));
      expect(g.debugPunchCyanRadius(charge: false), lessThanOrEqualTo(cap));
    });
  });
}
