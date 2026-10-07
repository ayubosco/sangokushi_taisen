import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/data/card_models.dart';
import 'package:sangokushi_taisen/game/faction_colors.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';

/// Headless Soft Lock stills for Design / UIUX.
///
/// GameWidget's live ticker deadlocks `tester.pump` once 場1 is on the canvas,
/// so this paints [TaisenGame.render] into a [ui.PictureRecorder] and composites
/// the MatchShell HUD + Cost/計略 bar around it. No simulator, no device.
///
/// Logical frame is iPhone 17-class portrait (402×874) at 1×. Ratios match a
/// 3× 1206×2622 still. Skipped unless `PR9_H0_STILLS=1` so a normal
/// `flutter test` does not rewrite the committed PNGs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'writes full-screen Soft Lock stills',
    (tester) async {
      const screen = Size(402, 874);
      // MatchShell chrome outside the GameWidget: HUD padding+title, 計略 bar.
      const hudH = 36.0;
      const bottomH = 78.0;
      final gameSize = Size(screen.width, screen.height - hudH - bottomH);

      final game = TaisenGame();
      game.onGameResize(Vector2(gameSize.width, gameSize.height));
      game.pauseEngine();
      game.clock.pause();

      final out = Directory('artifacts/pr9-h0-stills');
      await tester.runAsync(() async {
        final fontFile = File('/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf');
        if (fontFile.existsSync()) {
          final fontBytes = await fontFile.readAsBytes();
          await ui.loadFontFromList(fontBytes, fontFamily: TaisenGame.kInkFontFamily);
          await ui.loadFontFromList(fontBytes, fontFamily: 'Roboto');
        }
        await Future<void>.sync(() => game.onLoad()).timeout(const Duration(seconds: 30));
        await out.create(recursive: true);

        ui.Image? title;
        try {
          final data = await rootBundle.load('assets/branding/sangokushi-yubi-title-v2.png');
          final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
          title = (await codec.getNextFrame()).image;
        } catch (_) {}

        Future<void> shoot(String name) async {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          _paintScreen(canvas, screen, hudH, bottomH, game, title);
          final picture = recorder.endRecording();
          final image = await picture.toImage(screen.width.toInt(), screen.height.toInt());
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          expect(bytes, isNotNull);
          expect(image.width, screen.width.toInt());
          expect(image.height, screen.height.toInt());
          final file = File('${out.path}/$name');
          await file.writeAsBytes(
            bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          );
          image.dispose();
          expect(file.lengthSync(), greaterThan(20000));
          // ignore: avoid_print
          print('STILL ${file.path} ${file.lengthSync()}B');
        }

        game.setupSession1Field();
        game.dragging = false;
        game.dragTo = null;
        game.selectedIndex = null;
        expect(game.watchH / game.size.y, closeTo(0.125, 0.001));
        expect(game.fieldH / game.size.y, closeTo(0.875, 0.001));
        expect(game.tokenCardSize.width / game.size.x, closeTo(0.10, 0.001));
        expect(TaisenGame.kSoftPinPathPx, 300);
        await shoot('pr9-h0-e09bd07-fullscreen-idle.png');

        final start = Offset(game.size.x * 0.42, game.watchH + game.fieldH * 0.78);
        game.fieldPos[0] = start;
        game.fieldPos[1] = Offset(game.size.x * 0.78, game.watchH + game.fieldH * 0.22);
        final landing = game.softPinLandingFrom(start);
        expect((landing - start).distance, closeTo(TaisenGame.kSoftPinPathPx, 1));
        expect(
          game.ashWeaponGhostTrailPoints(start, landing, cardH: game.tokenCardSize.height).length,
          greaterThanOrEqualTo(3),
        );
        game.panStart(start);
        game.panEnd(landing);
        expect(game.pinnedMarchAt(0), isTrue, reason: 'mid still must be a committed Soft釘');
        expect(game.field[0].troop, TroopType.cavalry);
        expect(game.dragging, isFalse);
        await shoot('pr9-h0-e09bd07-fullscreen-softpin-mid.png');

        var guard = 0;
        while (game.dragTo != null && guard < 60 * 12) {
          game.debugStepPursuit(1 / 60);
          guard++;
        }
        expect(game.dragTo, isNull, reason: 'arrive still needs the body on the pin');
        expect(game.pinnedMarchAt(0), isFalse);
        await shoot('pr9-h0-e09bd07-fullscreen-arrive.png');
      });
    },
    skip: Platform.environment['PR9_H0_STILLS'] != '1',
  );
}

void _paintScreen(
  Canvas canvas,
  Size screen,
  double hudH,
  double bottomH,
  TaisenGame game,
  ui.Image? title,
) {
  canvas.drawRect(
    Offset.zero & screen,
    Paint()..color = FactionColors.lacquer,
  );
  _paintHud(canvas, screen.width, hudH, title, game.clock.remainingC);
  canvas.save();
  canvas.translate(0, hudH);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, screen.width, game.size.y),
    Paint()..color = FactionColors.lacquer,
  );
  game.render(canvas);
  canvas.restore();
  _paintBottom(canvas, Rect.fromLTWH(0, screen.height - bottomH, screen.width, bottomH));
}

void _paintHud(Canvas canvas, double width, double height, ui.Image? title, int c) {
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width, height),
    Paint()..color = FactionColors.lacquer,
  );
  if (title != null) {
    final dst = Rect.fromLTWH(12, (height - 24) / 2, 24 * title.width / title.height, 24);
    canvas.drawImageRect(
      title,
      Rect.fromLTWH(0, 0, title.width.toDouble(), title.height.toDouble()),
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
  } else {
    _label(canvas, '三國大戰', const Offset(12, 8), FactionColors.gold, 16, FontWeight.w700);
  }
  _label(canvas, 'Cost6', const Offset(118, 10), const Color(0x8AFFFFFF), 13, FontWeight.w400);
  final chip = RRect.fromRectAndRadius(
    const Rect.fromLTWH(168, 6, 92, 24),
    const Radius.circular(6),
  );
  canvas.drawRRect(chip, Paint()..color = const Color(0xFF1A1A1A));
  canvas.drawRRect(
    chip,
    Paint()
      ..color = FactionColors.gold.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke,
  );
  _label(canvas, '兵法：火計', const Offset(176, 10), FactionColors.gold, 12, FontWeight.w700);
  _label(canvas, '$c C', Offset(width - 52, 8), FactionColors.gold, 18, FontWeight.w700);
}

void _paintBottom(Canvas canvas, Rect bar) {
  canvas.drawRect(bar, Paint()..color = FactionColors.lacquer);
  _label(canvas, 'Cost 6', Offset(bar.left + 12, bar.top + 26), FactionColors.gold, 16, FontWeight.w800);
  const button = Size(102.4, 64);
  final buttonRect = Rect.fromLTWH(
    bar.right - 12 - button.width,
    bar.top + 6,
    button.width,
    button.height,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(buttonRect, const Radius.circular(4)),
    Paint()..color = FactionColors.gold,
  );
  final tp = TextPainter(
    text: const TextSpan(
      text: '計略',
      style: TextStyle(
        color: FactionColors.lacquer,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        fontFamily: TaisenGame.kInkFontFamily,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(
    canvas,
    buttonRect.center - Offset(tp.width / 2, tp.height / 2),
  );
}

void _label(Canvas canvas, String text, Offset at, Color color, double size, FontWeight weight) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: weight,
        fontFamily: TaisenGame.kInkFontFamily,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, at);
}
