import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/data/card_models.dart';
import 'package:sangokushi_taisen/game/faction_colors.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';
import 'package:sangokushi_taisen/game/unit_life.dart';

/// Headless Soft Pass stills after Gate P1–P6. No simulator.
/// Skipped unless `OVERNIGHT_STILLS=1`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'writes Soft Pass P1–P6 stills including beat 02 tip-scrape',
    (tester) async {
      const screen = Size(402, 874);
      const hudH = 36.0;
      const bottomH = 92.0;
      final gameSize = Size(screen.width, screen.height - hudH - bottomH);
      final game = TaisenGame();
      game.onGameResize(Vector2(gameSize.width, gameSize.height));
      game.pauseEngine();
      game.clock.pause();

      final out = Directory('artifacts/overnight-soft-pass-stills');
      await tester.runAsync(() async {
        final fontFile = File('/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf');
        if (fontFile.existsSync()) {
          final fontBytes = await fontFile.readAsBytes();
          await ui.loadFontFromList(fontBytes, fontFamily: TaisenGame.kInkFontFamily);
        }
        await Future<void>.sync(() => game.onLoad()).timeout(const Duration(seconds: 40));
        await out.create(recursive: true);

        Future<void> shoot(String name) async {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          canvas.drawRect(Offset.zero & screen, Paint()..color = FactionColors.lacquer);
          canvas.save();
          canvas.translate(0, hudH);
          game.render(canvas);
          canvas.restore();
          final seal = Rect.fromCenter(
            center: TaisenGame.kStrategySealCenter,
            width: TaisenGame.kStrategySealPt,
            height: TaisenGame.kStrategySealPt,
          );
          canvas.drawRect(seal, Paint()..color = FactionColors.lacquer);
          canvas.drawRect(
            seal,
            Paint()
              ..color = FactionColors.gold
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
          final tp = TextPainter(
            text: const TextSpan(
              text: '計略',
              style: TextStyle(
                color: FactionColors.gold,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFamily: TaisenGame.kInkFontFamily,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, seal.center - Offset(tp.width / 2, tp.height / 2));
          final picture = recorder.endRecording();
          final image = await picture.toImage(screen.width.toInt(), screen.height.toInt());
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('${out.path}/$name');
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
          expect(file.lengthSync(), greaterThan(8000));
          // ignore: avoid_print
          print('STILL ${file.absolute.path}');
        }

        Future<void> shootWatch(String name) async {
          final bandH = (hudH + game.watchH).ceil();
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          canvas.drawRect(
            Rect.fromLTWH(0, 0, screen.width, bandH.toDouble()),
            Paint()..color = FactionColors.lacquer,
          );
          canvas.save();
          canvas.translate(0, hudH);
          canvas.clipRect(Rect.fromLTWH(0, 0, game.size.x, game.watchH));
          game.render(canvas);
          canvas.restore();
          final picture = recorder.endRecording();
          final image = await picture.toImage(screen.width.toInt(), bandH);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('${out.path}/$name');
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
          expect(game.watchH / game.size.y, closeTo(0.125, 0.001));
          // ignore: avoid_print
          print('WATCH ${file.absolute.path} h=$bandH');
        }

        expect(game.watchH / game.size.y, closeTo(0.125, 0.001));
        expect(game.tokenCardSize.width / game.size.x, closeTo(0.097, 0.001));
        expect(TaisenGame.kSoftPinPathPx, 261);

        game.setupChargeAuraHitPose();
        expect(game.auraActive, isTrue);
        expect(game.debugHitLabel, '突撃');
        await shoot('01-charge-aura-hit.png');
        await shootWatch('06c-watch-aura.png');

        final spearAt = Offset(game.size.x * 0.40, game.watchH + game.fieldH * 0.58);
        final spear = Cost6Roster.all.firstWhere((c) => c.troop == TroopType.spear);
        final cav = Cost6Roster.all.firstWhere((c) => c.id == 'caocao');
        game.field
          ..clear()
          ..add(spear)
          ..add(cav);
        game.fieldIsEnemy
          ..clear()
          ..add(false)
          ..add(true);
        game.fieldInCastle
          ..clear()
          ..add(false)
          ..add(false);
        game.fieldPos
          ..clear()
          ..add(spearAt);
        game.ownFacing = 0;
        game.selectedIndex = 0;
        game.dragging = false;
        game.dragTo = null;
        game.fieldPos.add(game.spearTipAt(0));
        game.enemyFacing = math.pi;
        game.debugArmEnemyChargeAura();
        game.debugStepPursuit(1 / 60);
        expect(game.softLockCues.has('tip-scrape'), isTrue);
        expect(game.softLockCues.has('fly-geigeki'), isTrue);
        expect(game.debugTipScrapeArmed, isTrue, reason: 'beat 02 must resolve live scrape');
        expect(game.debugHitLabel, '迎擊');
        expect(game.debugInRansen(0), isFalse);
        expect(game.spearTipExtendedAt(0), isTrue);
        await shoot('02-spear-tip-geigeki.png');
        await shootWatch('06a-watch-tip.png');

        game.debugDecayCombatFx(2);
        game.debugRestageOwnEnemy(
          ownId: 'sunquan',
          ownAt: Offset(game.size.x * 0.3, game.watchH + game.fieldH * 0.55),
          enemyAt: Offset(game.size.x * 0.3, game.watchH + game.fieldH * 0.25),
        );
        game.setupFeelBowWindupPose();
        expect(game.debugBowWinding, isTrue);
        await shoot('03-bow-standing.png');
        await shootWatch('06b-watch-bow.png');

        final mashAt = Offset(game.size.x * 0.48, game.watchH + game.fieldH * 0.48);
        game.field
          ..clear()
          ..add(spear)
          ..add(cav);
        game.fieldIsEnemy
          ..clear()
          ..add(false)
          ..add(true);
        game.fieldInCastle
          ..clear()
          ..add(false)
          ..add(false);
        game.fieldPos
          ..clear()
          ..add(mashAt)
          ..add(mashAt);
        game.selectedIndex = 0;
        game.debugStepPursuit(1 / 60);
        expect(game.debugInRansen(0), isTrue);
        expect(game.spearTipExtendedAt(0), isFalse);
        expect(game.debugHitLabel, isNot('迎擊'));
        await shoot('04-ransen-mash.png');

        final band = game.castleBandRect;
        final living = Cost6Roster.all.firstWhere((c) => c.id == 'zhaoyun');
        game.debugRestageOwnEnemy(
          ownId: living.id,
          ownAt: Offset(band.center.dx, band.top + band.height * 0.72),
          enemyAt: Offset(game.size.x * 0.7, game.watchH + game.fieldH * 0.2),
        );
        game.fieldInCastle[0] = true;
        game.debugSetUnitHp(0, 60);
        game.castleBandHot = true;
        game.debugStepPursuit(1 / 60);
        expect(game.debugUnitLife(0), UnitLife.alive);
        expect(game.debugShowsSkull(0), isFalse);
        expect(game.debugLifeTipAt(0), '返城回血');
        await shoot('05a-living-guicheng.png');

        game.debugForceHpZero(0);
        game.fieldPos[0] = Offset(game.size.x * 0.4, game.watchH + game.fieldH * 0.4);
        game.fieldInCastle[0] = false;
        expect(game.debugUnitLife(0), UnitLife.retreating);
        expect(game.debugLifeTipAt(0), '返城');
        final frozen = game.debugReviveLeft(0);
        game.debugStepPursuit(1);
        expect(game.debugReviveLeft(0), closeTo(frozen, 0.001));
        await shoot('05b-skull-fancheng.png');
        await shootWatch('06d-watch-fancheng.png');
      });
    },
    skip: Platform.environment['OVERNIGHT_STILLS'] != '1',
  );
}
