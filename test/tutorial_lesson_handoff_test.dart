import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/game/tutorial_controller.dart';
import 'package:sangokushi_taisen/ui/tutorial_lesson_rail.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('handoff names stay readable and only 快馬突擊 is open after 逐一擊破', () {
    final c = TutorialController()..resetToSession1();
    final names = c.lessons.map((l) => l.name).toList();
    expect(names, ['逐一擊破', '快馬突擊', '槍擊退敵', '遠攻削敵', '回城', '用計得宜']);
    expect(c.lessons.map((l) => l.gate).toList(), [
      TutorialLessonGate.done,
      TutorialLessonGate.current,
      TutorialLessonGate.locked,
      TutorialLessonGate.locked,
      TutorialLessonGate.locked,
      TutorialLessonGate.locked,
    ]);
    expect(c.bowLessonUnlocked, isFalse);

    c.onSelectOwnCavalry();
    c.onChargeTravelProgress(1);
    c.onAutoCharge();
    expect(c.s1, S1Phase.tipNext);
    expect(c.lessons.firstWhere((l) => l.id == 'spear').gate, TutorialLessonGate.current);
    expect(c.lessons.firstWhere((l) => l.id == 'bow').gate, TutorialLessonGate.locked);
    expect(c.bowLessonUnlocked, isFalse);
  });

  test('a long wait does not hard-unlock 弓; one aimed 迎撃 does', () {
    final c = TutorialController()..resetToSession2();
    expect(c.lessons.firstWhere((l) => l.id == 'bow').name, '遠攻削敵');
    expect(c.lessons.firstWhere((l) => l.id == 'bow').gate, TutorialLessonGate.locked);
    expect(c.lessons.firstWhere((l) => l.id == 'spear').gate, TutorialLessonGate.current);

    c.tick(0.4 * 3.03);
    c.tick(0.3 * 3.03);
    c.tick(8);
    expect(c.s2, S2Phase.waitTurn);
    expect(c.turnWindowOpen, isTrue);
    c.tick(20);
    expect(c.facingCorrect, isFalse);
    expect(c.s2, isNot(S2Phase.bowTeach));
    expect(c.bowLessonUnlocked, isFalse);
    expect(c.bowLessonLive, isFalse);

    c.onAutoIntercept(facingWasCorrect: false);
    expect(c.bowLessonUnlocked, isFalse);
    expect(c.s2, S2Phase.failRetry);

    c.tick(0.8 * 3.03);
    expect(c.s2, S2Phase.waitTurn);
    c.tick(1.0 * 3.03);
    c.onSpearAimedByMove();
    expect(c.facingCorrect, isTrue);
    expect(c.bowLessonUnlocked, isFalse, reason: 'aim alone is not the Pass');

    c.onAutoIntercept(facingWasCorrect: true);
    // 槍擊退敵 beat two: 更多的騎兵 → 回頭 into a gold 槍擊.
    c.onSpearAimedByMove();
    c.onTurnBackHit();
    expect(c.interceptDone, isTrue);
    expect(c.s2, S2Phase.bowTeach);
    expect(c.bowLessonLive, isTrue);
    expect(c.lessons.firstWhere((l) => l.id == 'bow').gate, TutorialLessonGate.current);
    expect(c.lessons.firstWhere((l) => l.id == 'spear').gate, TutorialLessonGate.done);
    expect(c.lessons.firstWhere((l) => l.id == 'return').gate, TutorialLessonGate.locked);
    expect(c.tipText, contains('弓'));
    expect(c.tipSkippable, isFalse);

    c.skipTip();
    expect(c.s2, S2Phase.bowTeach);

    c.onBowShot();
    expect(c.s2, S2Phase.bowTeach);
    c.onBowSiegeLanded();
    expect(c.s2, S2Phase.bowTeach);
    c.onBowSupportShot();
    expect(c.s2, S2Phase.bowTeach);
    c.onBowKiteShot(mover: 1);
    c.onBowKiteShot(mover: 4);
    expect(c.s2, S2Phase.returnCity);
    expect(c.bowLessonLive, isFalse);
    expect(c.bowLessonUnlocked, isTrue);
    expect(c.lessons.firstWhere((l) => l.id == 'bow').gate, TutorialLessonGate.done);
    expect(c.lessons.firstWhere((l) => l.id == 'return').gate, TutorialLessonGate.current);
  });

  testWidgets('弓教學 stays on the rail while locked, then reads as the current lesson', (tester) async {
    final c = TutorialController()..resetToSession2();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TutorialLessonRail(controller: c),
        ),
      ),
    );

    expect(find.byKey(const Key('tutorial-lesson-rail')), findsOneWidget);
    expect(find.text('遠攻削敵'), findsOneWidget);
    expect(find.text('槍擊退敵'), findsOneWidget);
    expect(find.text('快馬突擊'), findsOneWidget);

    final lockedBow = tester.widget<Text>(find.descendant(
      of: find.byKey(const Key('tutorial-lesson-bow')),
      matching: find.text('遠攻削敵'),
    ));
    expect(lockedBow.style!.color, isNot(Colors.transparent));
    expect(lockedBow.style!.color!.a, greaterThan(0.8));
    expect(
      find.descendant(
        of: find.byKey(const Key('tutorial-lesson-bow')),
        matching: find.text('未開'),
      ),
      findsOneWidget,
    );
    expect(find.byType(InkWell), findsNothing);
    expect(find.byType(TextButton), findsNothing);

    c.tick(0.4 * 3.03);
    c.tick(0.3 * 3.03);
    c.tick(1.0 * 3.03);
    c.onSpearAimedByMove();
    c.onAutoIntercept(facingWasCorrect: true);
    // 槍擊退敵 beat two: 更多的騎兵 → 回頭 into a gold 槍擊.
    c.onSpearAimedByMove();
    c.onTurnBackHit();
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const Key('tutorial-lesson-bow')),
        matching: find.text('進行'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('tutorial-lesson-return')),
        matching: find.text('未開'),
      ),
      findsOneWidget,
    );
    expect(find.text('遠攻削敵'), findsOneWidget);
  });

  testWidgets('C1 hand cues 槍→弓 and stays off 回城 while 快馬突擊 is current', (tester) async {
    final s1 = TutorialController()..resetToSession1();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: TutorialLessonRail(controller: s1))),
    );
    expect(s1.lessons.first.name, '逐一擊破');
    expect(s1.lessons.first.gate, TutorialLessonGate.done);
    expect(s1.lessons[1].current, isTrue);
    expect(s1.lessons[1].name, '快馬突擊');
    expect(find.byKey(const Key('tutorial-handoff-link')), findsNothing);
    expect(find.text('迎撃後開弓'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('tutorial-lesson-charge')),
        matching: find.byKey(const Key('tutorial-handoff-hand')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('tutorial-lesson-return')),
        matching: find.byKey(const Key('tutorial-handoff-hand')),
      ),
      findsNothing,
    );

    final s2 = TutorialController()..resetToSession2();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: TutorialLessonRail(controller: s2))),
    );
    expect(s2.lessons.firstWhere((l) => l.id == 'spear').current, isTrue);
    expect(s2.bowLessonUnlocked, isFalse);
    expect(find.text('迎撃後開弓'), findsOneWidget);
    expect(find.byKey(const Key('tutorial-handoff-link')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('tutorial-lesson-spear')),
        matching: find.byKey(const Key('tutorial-handoff-hand')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('tutorial-lesson-bow')),
        matching: find.byKey(const Key('tutorial-lesson-lock-bow')),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('tutorial-lesson-open-bow')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('tutorial-lesson-return')),
        matching: find.byKey(const Key('tutorial-handoff-hand')),
      ),
      findsNothing,
    );
    expect(s2.lessons.map((l) => l.name).toList(), ['逐一擊破', '快馬突擊', '槍擊退敵', '遠攻削敵', '回城', '用計得宜']);
    expect(s2.lessons, hasLength(6));

    s2.turnWindowOpen = true;
    s2.s2 = S2Phase.waitTurn;
    s2.onSpearAimedByMove();
    s2.onAutoIntercept(facingWasCorrect: true);
    // 槍擊退敵 beat two: 更多的騎兵 → 回頭 into a gold 槍擊.
    s2.onSpearAimedByMove();
    s2.onTurnBackHit();
    await tester.pump();
    expect(s2.bowLessonUnlocked, isTrue);
    expect(find.byKey(const Key('tutorial-lesson-lock-bow')), findsNothing);
    expect(find.byKey(const Key('tutorial-lesson-open-bow')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('tutorial-lesson-bow')),
        matching: find.byKey(const Key('tutorial-handoff-hand')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('tutorial-lesson-return')),
        matching: find.byKey(const Key('tutorial-handoff-hand')),
      ),
      findsNothing,
    );

    s2.onBowShot();
    s2.onBowSiegeLanded();
    s2.onBowSupportShot();
    s2.onBowKiteShot(mover: 1);
    s2.onBowKiteShot(mover: 4);
    await tester.pump();
    expect(s2.lessons.firstWhere((l) => l.id == 'return').current, isTrue);
    expect(
      find.descendant(
        of: find.byKey(const Key('tutorial-lesson-return')),
        matching: find.byKey(const Key('tutorial-handoff-hand')),
      ),
      findsOneWidget,
    );
    expect(find.text('迎撃後開弓'), findsNothing);
    expect(find.byKey(const Key('tutorial-handoff-link')), findsNothing);
  });
}
