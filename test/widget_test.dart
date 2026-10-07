import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/main.dart';

void main() {
  testWidgets('app opens on the splash; the play shell keeps the C HUD', (tester) async {
    await tester.pumpWidget(const SangokushiApp());

    // Opening shell is the title splash. The clock lives on the play shell.
    expect(find.text('輕觸繼續'), findsOneWidget);
    expect(find.text('教學場 · 兵法 · 指尖對陣'), findsOneWidget);
    expect(find.textContaining('C'), findsNothing);

    await tester.tap(find.text('輕觸繼續'));
    await tester.pump();

    expect(find.text('今場不用兵法'), findsOneWidget);
    await tester.tap(find.text('今場不用兵法'));
    await tester.pump();

    expect(find.textContaining('C'), findsWidgets);
    expect(find.text('計略'), findsOneWidget);

    // Session-banner delays are not cancelled with the shell. Elapse them
    // after dispose so the test binding has no pending timers.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 2300));
  });
}
