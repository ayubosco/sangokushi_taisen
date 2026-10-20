import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/game/tutorial_controller.dart';
import 'package:sangokushi_taisen/ui/tutorial_lesson_rail.dart';

import 'feel_gates_test.dart' show readyGame;

/// 英傑 戰鬥教學 stage 5 用計得宜: select a general to see its 計略範圍,
/// then cast and spend the printed 士氣. Soft Lock runs it after 回城.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rail order follows the 英傑 stage names and closes on 用計得宜', () {
    final c = TutorialController()..resetToSession1();
    expect(c.lessons.map((l) => l.name).toList(),
        ['快馬突擊', '槍擊退敵', '遠攻削敵', '回城', '用計得宜']);
    expect(c.lessons.last.gate, TutorialLessonGate.locked);

    c.resetToSession2();
    c.interceptDone = true;
    c.s2 = S2Phase.returnCity;
    expect(c.lessons.last.gate, TutorialLessonGate.locked,
        reason: '用計得宜 stays locked until 回城 clears');

    c.onReturnCity();
    expect(c.s2, S2Phase.strategyTeach);
    expect(c.lessons.firstWhere((l) => l.id == 'return').gate, TutorialLessonGate.done);
    expect(c.lessons.last.gate, TutorialLessonGate.current);
    expect(c.tipText, contains('士氣'));

    c.onStrategy();
    expect(c.s2, S2Phase.tipDone);
    expect(c.lessons.every((l) => l.gate == TutorialLessonGate.done), isTrue);
  });

  test('shot either/or close still skips 用計得宜', () {
    final c = TutorialController()..forceSession2Coach();
    c.onReturnCity();
    expect(c.s2, S2Phase.tipDone);
  });

  test('回城 park opens 用計得宜 on a fresh lesson pool; the cast clears it', () {
    final coach = TutorialController()..resetToSession2();
    final g = readyGame(tutorial: coach);
    g.setupSession2Field();
    final seeded = g.matchMorale;
    expect(seeded, greaterThan(0));

    coach.interceptDone = true;
    coach.s2 = S2Phase.returnCity;
    // A 計略 on the 回城 step spends 士氣 but does not skip the step.
    g.selectOrDetailAt(g.tokenCenter(1));
    expect(g.castStrategyAtSelected(), isTrue);
    expect(coach.s2, S2Phase.returnCity);
    expect(g.matchMorale, lessThan(seeded));

    g.triggerReturnCityFx();
    expect(coach.s2, S2Phase.strategyTeach);
    expect(g.matchMorale, seeded, reason: 'lesson pool, not a regen rate');
    expect(g.strategyPreviewVisible, isFalse);

    // Enemy taps do not open a range.
    g.selectOrDetailAt(g.tokenCenter(2));
    expect(g.strategyPreviewVisible, isFalse);

    // Own tap shows the 計略範圍 and caption. No drag on this step.
    final at = g.tokenCenter(1);
    g.selectOrDetailAt(at);
    expect(g.strategyPreviewVisible, isTrue);
    expect(g.strategyPreviewCaption, contains('士氣${g.field[1].strategyMorale}'));
    g.panStart(at);
    expect(g.dragging, isFalse);

    final cost = g.strategyMoraleCostAt(1)!;
    expect(g.castStrategyOnMap(at), isTrue);
    expect(g.matchMorale, seeded - cost);
    expect(g.strategyPreviewVisible, isFalse);
    expect(coach.s2, S2Phase.tipDone);
  });

  test('a short pool refuses the cast and keeps 用計得宜 open', () {
    final coach = TutorialController()..resetToSession2();
    final g = readyGame(tutorial: coach);
    g.setupSession2Field();
    coach.interceptDone = true;
    coach.s2 = S2Phase.strategyTeach;
    g.matchMorale = 0;
    g.selectOrDetailAt(g.tokenCenter(0));
    expect(g.strategyPreviewVisible, isTrue);
    expect(g.castStrategyAtSelected(), isFalse);
    expect(coach.s2, S2Phase.strategyTeach);
  });

  testWidgets('rail hand moves to step 5 after 回城', (tester) async {
    final c = TutorialController()..resetToSession2();
    c.interceptDone = true;
    c.s2 = S2Phase.returnCity;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: TutorialLessonRail(controller: c)),
    ));
    expect(find.byKey(const Key('tutorial-lesson-lock-strategy')), findsOneWidget);

    c.onReturnCity();
    await tester.pump();
    expect(find.byKey(const Key('tutorial-lesson-lock-strategy')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('tutorial-lesson-strategy')),
        matching: find.byKey(const Key('tutorial-handoff-hand')),
      ),
      findsOneWidget,
    );
    expect(find.text('迎撃後開弓'), findsNothing);
    expect(find.byKey(const Key('tutorial-handoff-link')), findsNothing);
  });
}
