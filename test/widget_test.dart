import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/main.dart';

void main() {
  testWidgets('app loads title', (tester) async {
    await tester.pumpWidget(const SangokushiApp());
    expect(find.text('三國指大戰'), findsOneWidget);
  });
}
