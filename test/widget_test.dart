import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/main.dart';

void main() {
  testWidgets('app loads match shell', (tester) async {
    await tester.pumpWidget(const SangokushiApp());
    // C HUD still present
    expect(find.textContaining('C'), findsWidgets);
  });
}
