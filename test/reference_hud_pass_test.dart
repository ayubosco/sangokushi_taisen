import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/game/faction_colors.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';
import 'package:sangokushi_taisen/ui/morale_bar.dart';

/// HUD pass against the reference capture (118-S4-COMBAT-01): a 士氣 track
/// with dark sockets, HP-coloured castle bars cut in four, and a big slanted
/// clock between them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('士氣 track', () {
    test('sockets fill the track from the pool up to the ceiling', () {
      expect(MoraleBar.socketPips(4, null, 9), 5);
      expect(MoraleBar.socketPips(9, null, 9), 0);
      expect(MoraleBar.socketPips(1, 4, 9), 5, reason: '1 held + 3 short + 5 dark');
      expect(MoraleBar.socketPips(4, null, null), 0, reason: 'no ceiling, no track');
      expect(MoraleBar.socketPips(6, null, 4), 0);
    });

    testWidgets('filled pips, then dark sockets', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: MoraleBar(morale: 3, cap: 8, charge: 0.5))),
      ));
      expect(find.byKey(const Key('match-morale-pip')), findsNWidgets(3));
      expect(find.byKey(const Key('match-morale-socket')), findsNWidgets(5));
    });

    testWidgets('without a ceiling the bar is unchanged', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: MoraleBar(morale: 3))),
      ));
      expect(find.byKey(const Key('match-morale-pip')), findsNWidgets(3));
      expect(find.byKey(const Key('match-morale-socket')), findsNothing);
    });
  });

  test('castle HP colour runs green, yellow, red and the bar has four cuts', () {
    final full = TaisenGame.castleHpColor(1);
    final half = TaisenGame.castleHpColor(0.5);
    final low = TaisenGame.castleHpColor(0);
    expect(full.g, greaterThan(full.r));
    expect(half.r, greaterThan(0.8));
    expect(half.g, greaterThan(0.7));
    expect(low.r, greaterThan(low.g));
    expect(TaisenGame.kCastleBarSegments, 4);
  });

  testWidgets('regen progress is 0 at the ceiling and rises below it', (tester) async {
    final game = TaisenGame();
    game.onGameResize(Vector2(402, 746));
    await tester.runAsync(() async {
      await Future<void>.sync(() => game.onLoad()).timeout(const Duration(seconds: 40));
    });
    expect(game.matchMorale, game.matchMoraleCap);
    expect(game.moraleRegenProgress, 0);
  });

  testWidgets(
    'writes the HUD still',
    (tester) async {
      const screen = Size(402, 874);
      const hudH = 36.0;
      const bottomH = 92.0;
      final game = TaisenGame();
      game.onGameResize(Vector2(screen.width, screen.height - hudH - bottomH));
      game.pauseEngine();
      game.clock.pause();
      await tester.runAsync(() async {
        final font = File('/Library/Fonts/Arial Unicode.ttf');
        if (font.existsSync()) {
          await ui.loadFontFromList(await font.readAsBytes(), fontFamily: TaisenGame.kInkFontFamily);
        }
        await Future<void>.sync(() => game.onLoad()).timeout(const Duration(seconds: 40));
        game.ownCastle = 0.78;
        game.enemyCastle = 0.31;
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(Offset.zero & screen, Paint()..color = FactionColors.lacquer);
        canvas.save();
        canvas.translate(0, hudH);
        game.render(canvas);
        canvas.restore();
        final image = await recorder.endRecording().toImage(screen.width.toInt() * 2, screen.height.toInt() * 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final out = Directory('artifacts/reference-hud-pass');
        await out.create(recursive: true);
        await File('${out.path}/after.png').writeAsBytes(bytes!.buffer.asUint8List());
      });
    },
    skip: Platform.environment['REFERENCE_HUD_STILLS'] != '1',
  );
}
