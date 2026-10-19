import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/data/card_models.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';
import 'package:sangokushi_taisen/game/unit_life.dart';

import 'feel_gates_test.dart' show readyGame;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('P1–P3 Soft Pass H0 numbers', () {
    expect(TaisenGame.kWatchFractionOfGame, closeTo(0.125, 0.0001));
    expect(1 - TaisenGame.kWatchFractionOfGame, closeTo(0.875, 0.0001));
    expect(TaisenGame.kTokenWidthFracOfField, closeTo(0.097, 0.0001));
    expect(TaisenGame.kTokenAspectWH, 5 / 8);
    expect(TaisenGame.kSoftPinPathPx, closeTo(261, 0.01));
    expect(TaisenGame.kChargeTravelNeed, 120);

    final g = readyGame();
    expect(g.watchH / g.size.y, closeTo(0.125, 0.0001));
    expect(g.fieldH / g.size.y, closeTo(0.875, 0.0001));
    expect(math.min(g.tokenHitSize.width, g.tokenHitSize.height), greaterThanOrEqualTo(64));
  });

  test('P4 計略 seal anchors and Watch-strip FX do not meet the medallion', () {
    expect(TaisenGame.kStrategySealPt, 64);
    expect(TaisenGame.kStrategySealCenter, const Offset(350, 814));
    final box = Rect.fromCenter(
      center: TaisenGame.kStrategySealCenter,
      width: TaisenGame.kStrategySealPt,
      height: TaisenGame.kStrategySealPt,
    );
    expect(box.left, closeTo(318, 0.01));
    expect(box.top, closeTo(782, 0.01));
    expect(TaisenGame.kSoftPassFrameH - box.bottom, closeTo(28, 0.01));

    final g = readyGame();
    g.setupSession2Field();
    final before = g.matchMorale;
    final cost = g.field[0].strategyMorale;
    expect(g.strategyPreviewVisible, isTrue);
    g.triggerStrategyFx();
    expect(g.matchMorale, before - cost);
    expect(g.strategyPreviewVisible, isFalse);
    expect(g.debugHitLabel, isNot('迎擊'));
    expect(g.debugStrategyCastAt, isNotNull);
    final banner = g.strategyBannerRect;
    final stamp = g.strategyStampAt;
    final med = g.gaugeMedallionRect;
    final clip = g.watchCueClipRect;
    expect(banner.bottom, lessThanOrEqualTo(clip.bottom + 0.5));
    expect(banner.overlaps(med), isFalse);
    expect(med.top, greaterThanOrEqualTo(g.watchH - 0.5));
    expect(stamp.dy, lessThan(g.watchH));
    expect(stamp.dx, inInclusiveRange(banner.left, banner.right));
    expect(clip.bottom, lessThanOrEqualTo(g.watchH - TaisenGame.kCastleStripPx + 0.5));
  });

  test('P5 intercept arms tip-scrape and a single 迎擊; rear and idle do not', () {
    final g = readyGame();
    final at = Offset(g.size.x * 0.42, g.watchH + g.fieldH * 0.55);
    final spear = Cost6Roster.all.firstWhere((c) => c.troop == TroopType.spear);
    g.field
      ..clear()
      ..add(spear);
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
    g.ownFacing = 0;
    final cav = Cost6Roster.all.firstWhere((c) => c.id == 'caocao');
    g.field.add(cav);
    g.fieldIsEnemy.add(true);
    g.fieldInCastle.add(false);
    g.fieldPos.add(g.spearTipAt(0) + const Offset(0, -12));
    g.enemyFacing = 0;
    g.debugArmEnemyChargeAura();
    g.debugStepPursuit(1 / 60);
    expect(g.debugTipScrapeArmed, isFalse, reason: 'rear scrape is not 迎擊');
    expect(g.debugHitLabel, isNot('迎擊'));

    g.fieldPos[1] = g.spearTipAt(0);
    g.enemyFacing = math.pi;
    g.debugStepPursuit(1 / 60);
    expect(g.debugTipScrapeArmed, isTrue);
    expect(g.debugHitLabel, '迎擊');
    expect(g.debugInRansen(0), isFalse);
    expect(g.debugRetreatCause(1), '迎擊');
    expect(g.debugUnitLife(1), UnitLife.retreating);
    expect(g.spearTipExtendedAt(0), isTrue);
  });

  test('P6 watch cue clip stays inside the 0.125 band above the gauges', () {
    final g = TaisenGame()..onGameResize(Vector2(402, 760));
    expect(g.watchH / g.size.y, closeTo(0.125, 0.0001));
    final clip = g.watchCueClipRect;
    expect(clip.top, 0);
    expect(clip.bottom, lessThanOrEqualTo(g.watchH));
    expect(clip.bottom, lessThanOrEqualTo(g.watchH - TaisenGame.kCastleStripPx + 0.01));
    expect(clip.overlaps(g.gaugeMedallionRect), isFalse);
    expect(g.strategyBannerRect.bottom, lessThanOrEqualTo(clip.bottom + 0.5));
  });
}
