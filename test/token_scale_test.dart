import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';

void main() {
  test('field token width is 0.10 of field, 5:8, hit ≥12mm', () {
    expect(TaisenGame.kTokenWidthFracOfField, 0.10);
    expect(TaisenGame.kTokenAspectWH, 5 / 8);
    expect(TaisenGame.kWatchFractionOfGame, inInclusiveRange(0.12, 0.13));
    expect(1 - TaisenGame.kWatchFractionOfGame, greaterThanOrEqualTo(0.87));
    expect(TaisenGame.kCastleBandFracOfField, 0.12);
    expect(TaisenGame.kCastleBandFracOfField, lessThanOrEqualTo(0.132));

    const fieldW = 390.0;
    const tokenW = fieldW * TaisenGame.kTokenWidthFracOfField;
    const tokenH = tokenW / TaisenGame.kTokenAspectWH;
    expect(tokenW, 39.0);
    expect(tokenH, closeTo(62.4, 0.01));

    final g = TaisenGame()..onGameResize(Vector2(fieldW, 844));
    final hit = g.tokenHitSize;
    expect(hit.width, greaterThanOrEqualTo(tokenW * TaisenGame.kHitVisualScale));
    expect(hit.height, greaterThanOrEqualTo(tokenH * TaisenGame.kHitVisualScale));
    expect(math.min(hit.width, hit.height), greaterThanOrEqualTo(TaisenGame.kMinHitExtentPx));
  });

  test('JL3 table is aged paper plus a red rail, not a black vacuum', () {
    expect(TaisenGame.kDesktopParchment.computeLuminance(), greaterThan(0.35));
    expect(TaisenGame.kDesktopParchmentDeep.computeLuminance(), greaterThan(0.2));
    expect(TaisenGame.kOwnBand.computeLuminance(), lessThan(0.25));
    expect(TaisenGame.kEnemyBand, isNot(TaisenGame.kOwnBand));
    expect(TaisenGame.kEnemyBand, isNot(TaisenGame.kDesktopParchment));
    expect(TaisenGame.kWatchFractionOfGame, lessThanOrEqualTo(0.18));
    expect(1 - TaisenGame.kWatchFractionOfGame, greaterThanOrEqualTo(0.55));
    expect(TaisenGame.kTokenWidthFracOfField, closeTo(0.10, 0.001));
  });

  test('own and enemy field tokens share identical card size (no enemy scale)', () {
    // Regression: enemy hard-outline used to inflate +20/+12 and read as bigger card.
    expect(TaisenGame.kTokenWidthFracOfField, 0.10);
    const fieldW = 402.0;
    const ownW = fieldW * TaisenGame.kTokenWidthFracOfField;
    const enemyW = fieldW * TaisenGame.kTokenWidthFracOfField;
    expect(ownW, enemyW);
    expect(ownW / fieldW, 0.10);
    expect(TaisenGame.kTokenAspectWH, 5 / 8);
  });
}
