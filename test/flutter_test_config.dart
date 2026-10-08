import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'support/test_fonts.dart';

/// Runs before every test file: registers the test-only CJK/Latin font so
/// headless stills and goldens render real glyphs instead of tofu boxes.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await loadTestCjkFonts();
  await testMain();
}
