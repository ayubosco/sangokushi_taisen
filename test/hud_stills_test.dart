import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/data/card_models.dart';
import 'package:sangokushi_taisen/game/faction_colors.dart';
import 'package:sangokushi_taisen/main.dart';

/// Headless battle HUD still (MatchShell: HUD + field + 計略 bar) for
/// Design / UIUX Gate review. No simulator, no device.
///
/// Skipped unless `HUD_STILLS=1`, so a normal `flutter test` never writes
/// files. Output dir defaults to `build/hud-stills/` (gitignored); override
/// with `HUD_STILLS_OUT=<dir>`.
///
///   HUD_STILLS=1 flutter test test/hud_stills_test.dart
///
/// CJK/Latin glyphs come from the test-only fonts loaded in
/// `test/flutter_test_config.dart` (see `test/fonts/README.md`).
void main() {
  testWidgets(
    'writes a headless MatchShell HUD still',
    (tester) async {
      // iPhone 17-class portrait: 402×874 logical @3×.
      tester.view.physicalSize = const Size(1206, 2622);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final shotKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: shotKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            // Mirrors SangokushiApp's theme so the HUD matches the app.
            theme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: FactionColors.lacquer,
              colorScheme: const ColorScheme.dark(
                primary: FactionColors.gold,
                secondary: FactionColors.shu,
              ),
            ),
            home: const MatchShell(faction: Faction.shu, bingfaLabel: '兵法：火計'),
          ),
        ),
      );

      // Decode the HUD title PNG for real (image codecs need runAsync).
      final ctx = tester.element(find.byType(MatchShell));
      await tester.runAsync(
        () => precacheImage(const AssetImage('assets/branding/sangokushi-yubi-title-v2.png'), ctx),
      );
      // TaisenGame.onLoad decodes its sprite sheets; give that real async
      // time between fake-clock frames so the field paints, then let the
      // post-frame setupMatchDemoField land.
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 16));
      }

      final outDir = Directory(Platform.environment['HUD_STILLS_OUT'] ?? 'build/hud-stills');
      final name = Platform.environment['HUD_STILLS_NAME'] ?? 'match-hud.png';
      final file = File('${outDir.path}/$name');
      await tester.runAsync(() async {
        final boundary = shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        expect(bytes, isNotNull);
        await outDir.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
      });
      expect(file.lengthSync(), greaterThan(20000));
      // ignore: avoid_print
      print('HUD_STILL ${file.absolute.path} ${file.lengthSync()}B');

      // Unmount so the HUD's Stream.periodic and the game ticker stop.
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: Platform.environment['HUD_STILLS'] != '1',
  );
}
