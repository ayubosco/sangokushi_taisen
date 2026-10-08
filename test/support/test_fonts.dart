import 'dart:io';

import 'package:flutter/services.dart';

/// Test-only fonts for headless stills / goldens.
///
/// flutter_tester ships only the `FlutterTest` box font, so CJK (and Latin)
/// paint as tofu boxes in headless PNGs. This loads the subset Noto Sans CJK
/// TC in `test/fonts/` (OFL-1.1, see `test/fonts/README.md`) under the
/// family names the app's text resolves to. Nothing here ships in the app:
/// the font is not in pubspec `flutter: fonts/assets`.
const kTestCjkFontFiles = <String>[
  'test/fonts/NotoSansCJKtc-Regular.subset.otf',
  'test/fonts/NotoSansCJKtc-Bold.subset.otf',
];

/// Families the HUD / Flame canvas text resolves to under flutter_test.
///
/// * `Roboto`: Material's default typography on the default (Android) test
///   platform, i.e. every `Text` in the MatchShell HUD / 計略 bar.
/// * `SangokushiInk`: the Flame canvas ink family PR #9 introduces
///   (`TaisenGame.kInkFontFamily`), so canvas labels resolve once it lands.
/// * `Noto Sans CJK TC`: the font's own name, for tests that ask for it.
///
/// Text with *no* `fontFamily` (raw `TextPainter` on the Flame canvas on
/// main) cannot be redirected from test code: flutter_tester maps the empty
/// family straight to its `FlutterTest` box font.
const kTestCjkFontFamilies = <String>[
  'Roboto',
  'SangokushiInk',
  'Noto Sans CJK TC',
];

bool _loaded = false;

/// Loads [kTestCjkFontFiles] once per test isolate. Safe to call repeatedly.
Future<void> loadTestCjkFonts() async {
  if (_loaded) return;
  _loaded = true;
  final root = _packageRoot();
  final bytes = <ByteData>[
    for (final rel in kTestCjkFontFiles)
      ByteData.sublistView(File('${root.path}/$rel').readAsBytesSync()),
  ];
  for (final family in kTestCjkFontFamilies) {
    final loader = FontLoader(family);
    for (final b in bytes) {
      loader.addFont(Future<ByteData>.value(b));
    }
    await loader.load();
  }
}

/// `flutter test` runs with cwd = package root; fall back to walking up
/// from this script for IDE runners that use a different cwd.
Directory _packageRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    if (File('${dir.path}/pubspec.yaml').existsSync() &&
        Directory('${dir.path}/test/fonts').existsSync()) {
      return dir;
    }
    dir = dir.parent;
  }
  return Directory.current;
}
