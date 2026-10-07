import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/data/card_models.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TaisenGame sized() {
    final g = TaisenGame();
    g.onGameResize(Vector2(390, 844));
    return g;
  }

  test('H0 A ratios: watch 0.125, field 0.875, size 0.10, castle 0.12', () {
    final g = sized();
    expect(TaisenGame.kWatchFractionOfGame, closeTo(0.125, 0.0001));
    expect(g.watchH / g.size.y, closeTo(0.125, 0.0001));
    expect(g.fieldH / g.size.y, closeTo(0.875, 0.0001));
    expect(TaisenGame.kTokenWidthFracOfField, 0.10);
    expect(g.tokenCardSize.width / g.size.x, closeTo(0.10, 0.0001));
    expect(TaisenGame.kCastleBandFracOfField, 0.12);
    expect(g.castleBandH / g.fieldH, closeTo(0.12, 0.0001));
    expect(TaisenGame.kCastleBandFracOfField, lessThanOrEqualTo(0.132));
  });

  test('Soft釘 path is 1.25× the prior 240px and lands in the lower 70%', () {
    expect(TaisenGame.kSoftPinPathScale, closeTo(1.25, 0.001));
    expect(TaisenGame.kSoftPinPathPx, closeTo(TaisenGame.kPriorSoftPinPathPx * 1.25, 0.01));
    expect(TaisenGame.kSoftPinPathPx, closeTo(300, 0.01));

    final g = sized();
    final start = Offset(g.size.x * 0.50, g.watchH + g.fieldH * 0.78);
    final landing = g.softPinLandingFrom(start);
    expect((landing - start).distance, closeTo(TaisenGame.kSoftPinPathPx, 1.0));
    expect(g.softPinPrimaryRect.contains(start), isTrue);
    expect(g.softPinPrimaryRect.contains(landing), isTrue);
    expect(landing.dy, greaterThan(g.watchH));
  });

  test('max-5 rank gaps are ≥1.3× token and one token off the bezel', () {
    final g = sized();
    g.setupMatchDemoField();
    expect(g.field.length, lessThanOrEqualTo(TaisenGame.fieldMax));

    final tokenW = g.tokenCardSize.width;
    final ownX = <double>[];
    for (var i = 0; i < g.field.length; i++) {
      if (!g.fieldIsEnemy[i]) ownX.add(g.fieldPos[i].dx);
    }
    ownX.sort();
    expect(ownX.length, greaterThanOrEqualTo(2));
    for (var i = 1; i < ownX.length; i++) {
      final edgeGap = ownX[i] - ownX[i - 1] - tokenW;
      expect(edgeGap, greaterThanOrEqualTo(tokenW * TaisenGame.kMinLaneGapMulOfToken - 0.5));
    }

    final dead = tokenW * TaisenGame.kEdgeDeadZoneMulOfToken;
    for (final x in ownX) {
      expect(x - tokenW / 2, greaterThanOrEqualTo(dead - 0.5));
      expect(g.size.x - (x + tokenW / 2), greaterThanOrEqualTo(dead - 0.5));
    }
    expect(g.maxPerRank, lessThan(TaisenGame.fieldMax));
  });

  test('sixth card is refused; fillers are not extra draggable units', () {
    final g = sized();
    final card = Cost6Roster.all.first;
    for (var i = 0; i < TaisenGame.fieldMax; i++) {
      expect(g.spawnCard(card), isTrue);
    }
    expect(g.spawnCard(card), isFalse);
    expect(g.field.length, TaisenGame.fieldMax);
    // Parchment stains are brown, not a grey unit oval (R≈G≈B).
    expect(TaisenGame.kParchmentStain.r, greaterThan(TaisenGame.kParchmentStain.b + 0.05));
    expect(TaisenGame.kTroopContactShadow.r, greaterThan(TaisenGame.kTroopContactShadow.b + 0.05));
  });

  test('edge dead-zone and R2 grey card stay fully on-screen', () {
    final g = sized();
    final card = g.tokenCardSize;
    final shoved = g.clampPlayableCenter(Offset(-20, g.size.y + 40));
    final face = Rect.fromCenter(center: shoved, width: card.width, height: card.height);
    final dead = g.tokenWidthPx * TaisenGame.kEdgeDeadZoneMulOfToken;
    expect(face.left, greaterThanOrEqualTo(dead - 0.5));
    expect(g.size.x - face.right, greaterThanOrEqualTo(dead - 0.5));
    expect(g.size.y - face.bottom, greaterThanOrEqualTo(dead - 0.5));
    expect(face.top, greaterThanOrEqualTo(g.watchH));
    expect(face.bottom, lessThanOrEqualTo(g.size.y));

    final parked = g.clampPlayableCenter(g.castleBandRect.center);
    final r2 = Rect.fromCenter(center: parked, width: card.width, height: card.height);
    expect(r2.top, greaterThanOrEqualTo(0));
    expect(r2.bottom, lessThanOrEqualTo(g.size.y));
    expect(r2.height, greaterThan(26), reason: 'centred countdown font fits on the grey face');
  });

  test('hit box is ≥1.2× visual and ≥12mm on the short side', () {
    final g = sized();
    final visual = g.tokenCardSize;
    final hit = g.tokenHitSize;
    expect(hit.width / visual.width, greaterThanOrEqualTo(TaisenGame.kHitVisualScale - 0.001));
    expect(hit.height / visual.height, greaterThanOrEqualTo(TaisenGame.kHitVisualScale - 0.001));
    expect(math.min(hit.width, hit.height), greaterThanOrEqualTo(64));
    final at = Offset(g.size.x * 0.5, g.watchH + g.fieldH * 0.6);
    g.spawnCard(Cost6Roster.all.first);
    g.fieldPos[0] = at;
    expect(g.hitTokenAt(at), 0);
    expect(g.hitTokenAt(at + Offset(hit.width / 2 - 1, 0)), 0);
    expect(g.hitTokenAt(at + Offset(hit.width / 2 + 4, 0)), isNull);
    expect(g.hitTokenAt(Offset(at.dx, g.watchH - 2)), isNull);
  });
}
