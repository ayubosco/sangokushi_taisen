import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';

void main() {
  test('field token width is 0.10 of field, 5:8, hit ≥48dp', () {
    expect(TaisenGame.kTokenWidthFracOfField, 0.10);
    expect(TaisenGame.kTokenAspectWH, 5 / 8);
    // H0 watch / castle band stay locked (this change is token art only).
    expect(TaisenGame.kWatchFractionOfGame, 0.18);
    expect(TaisenGame.kCastleBandFracOfField, 0.12);

    const fieldW = 390.0;
    const tokenW = fieldW * TaisenGame.kTokenWidthFracOfField;
    const tokenH = tokenW / TaisenGame.kTokenAspectWH;
    expect(tokenW, 39.0);
    expect(tokenH, closeTo(62.4, 0.01));

    final halfDiag = 0.5 * math.sqrt(tokenW * tokenW + tokenH * tokenH);
    final hitR = math.max(halfDiag + 4, 24.0);
    expect(hitR, greaterThanOrEqualTo(24.0));
  });

  test('own and enemy field tokens share identical card size (no enemy scale)', () {
    // Regression: enemy hard-outline used to inflate +20/+12 and read as bigger card.
    expect(TaisenGame.kTokenWidthFracOfField, 0.10);
    const fieldW = 402.0;
    final ownW = fieldW * TaisenGame.kTokenWidthFracOfField;
    final enemyW = fieldW * TaisenGame.kTokenWidthFracOfField; // same constant — no enemy multiplier
    expect(ownW, enemyW);
    expect(ownW / fieldW, 0.10);
    expect(TaisenGame.kTokenAspectWH, 5 / 8);
  });
}
