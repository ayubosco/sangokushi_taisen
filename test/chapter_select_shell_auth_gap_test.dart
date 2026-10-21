import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/game/tutorial_controller.dart';
import 'package:sangokushi_taisen/ui/tutorial_lesson_rail.dart';

/// AUTH-GAP leftover (docs/AUTH-GAP-EIKETSU-2026-10-16.md line 107): the
/// victory / 章節選擇 shell. Observed-from-英傑: the five stage names in order,
/// and a bottom button that read 開始 on stages 1–4 and 開戰 on 用計得宜.
/// Nothing else (title, victory copy, timing, layout) came from the foil.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TutorialController shellOn() => TutorialController()..chapterSelectShell = true;

  void clearIchigeki(TutorialController c) {
    c.onSelectOwnFoot();
    c.onIchigekiRansen();
    c.onIchigekiEnemyRouted();
  }

  void clearCharge(TutorialController c) {
    c.onSelectOwnCavalry();
    c.onChargeTravelProgress(1);
    c.onAutoCharge();
  }

  void clearSpear(TutorialController c) {
    c.tick(0.4 * 3.03);
    c.tick(0.3 * 3.03);
    c.tick(1.0 * 3.03);
    c.onSpearAimedByMove();
    c.onAutoIntercept(facingWasCorrect: true);
  }

  test('章節選擇 lists the five 英傑 stages in order; 回城 is not a stage', () {
    final c = shellOn()..resetToIchigeki();
    expect(c.chapterStages.map((l) => l.name).toList(),
        ['逐一擊破', '快馬突擊', '槍擊退敵', '遠攻削敵', '用計得宜']);
    expect(c.lessons.map((l) => l.id), contains('return'),
        reason: 'the rail keeps the Soft Lock 回城 step');
  });

  test('bottom button reads 開始 on stages 1–4 and 開戰 on 用計得宜', () {
    expect(TutorialController.chapterStartLabelFor('ichigeki'), '開始');
    expect(TutorialController.chapterStartLabelFor('charge'), '開始');
    expect(TutorialController.chapterStartLabelFor('spear'), '開始');
    expect(TutorialController.chapterStartLabelFor('bow'), '開始');
    expect(TutorialController.chapterStartLabelFor('strategy'), '開戰');
  });

  test('逐一擊破 victory goes to 章節選擇; 開始 opens 快馬突擊', () {
    final c = shellOn()..resetToIchigeki();
    clearIchigeki(c);
    expect(c.chapterSelectOpen, isFalse, reason: 'the clear tip shows first');

    c.skipTip();
    expect(c.chapterSelectOpen, isTrue);
    expect(c.session, TutorialSession.ichigeki, reason: 'next stage waits for the button');
    expect(c.chapterSelectNext!.id, 'charge');
    expect(c.chapterStartLabel, '開始');
    expect(c.chapterStages.first.gate, TutorialLessonGate.done);

    c.skipTip();
    expect(c.session, TutorialSession.ichigeki, reason: '跳過 does not bypass 章節選擇');

    c.startChapter();
    expect(c.chapterSelectOpen, isFalse);
    expect(c.session, TutorialSession.session1);
    expect(c.s1, S1Phase.highlightSelect);
  });

  test('快馬突擊 victory goes to 章節選擇; 開始 opens 槍擊退敵', () {
    final c = shellOn()..resetToSession1();
    clearCharge(c);
    c.skipTip();
    expect(c.chapterSelectOpen, isTrue);
    expect(c.session, TutorialSession.session1);
    expect(c.chapterSelectNext!.id, 'spear');
    expect(c.chapterStartLabel, '開始');

    c.startChapter();
    expect(c.session, TutorialSession.session2);
    expect(c.s2, S2Phase.spearGlow);
  });

  test('槍擊退敵 clear opens 章節選擇 on 遠攻削敵; the bow waits for 開始', () {
    final c = shellOn()..resetToSession2();
    clearSpear(c);
    expect(c.s2, S2Phase.bowTeach);
    expect(c.chapterSelectOpen, isTrue);
    expect(c.chapterSelectNext!.id, 'bow');
    expect(c.chapterStartLabel, '開始');
    expect(c.bowLessonUnlocked, isTrue);
    expect(c.bowLessonLive, isFalse, reason: 'no standing fire behind the shell');

    c.onBowShot();
    expect(c.s2, S2Phase.bowTeach, reason: 'a shot behind 章節選擇 does not clear 遠攻削敵');

    c.startChapter();
    expect(c.chapterSelectOpen, isFalse);
    expect(c.bowLessonLive, isTrue);
    c.onBowShot();
    expect(c.s2, S2Phase.returnCity);
    expect(c.chapterSelectOpen, isFalse, reason: '回城 is not a 英傑 stage');
  });

  test('回城 opens 章節選擇 on 用計得宜 with 開戰; the cast waits for it', () {
    final c = shellOn()..resetToSession2();
    c.interceptDone = true;
    c.s2 = S2Phase.returnCity;
    c.onReturnCity();
    expect(c.s2, S2Phase.strategyTeach);
    expect(c.chapterSelectOpen, isTrue);
    expect(c.chapterSelectNext!.id, 'strategy');
    expect(c.chapterStartLabel, '開戰');
    expect(c.strategyLessonLive, isFalse);

    c.onStrategy();
    expect(c.s2, S2Phase.strategyTeach);

    c.startChapter();
    expect(c.strategyLessonLive, isTrue);
    c.onStrategy();
    expect(c.s2, S2Phase.tipDone);
    expect(c.chapterSelectOpen, isFalse,
        reason: 'what follows stage 5 was not on the foil; the 選勢力 close stays');
    c.skipTip();
    expect(c.session, TutorialSession.complete);
  });

  test('shell off keeps the bare state machine and shot stills', () {
    final c = TutorialController()..resetToIchigeki();
    clearIchigeki(c);
    c.skipTip();
    expect(c.chapterSelectOpen, isFalse);
    expect(c.session, TutorialSession.session1);

    final shot = shellOn()..forceSession1Pass();
    shot.skipTip();
    expect(shot.chapterSelectOpen, isFalse);
    expect(shot.session, TutorialSession.session2);
  });

  test('a restart closes 章節選擇', () {
    final c = shellOn()..resetToIchigeki();
    clearIchigeki(c);
    c.skipTip();
    expect(c.chapterSelectOpen, isTrue);
    c.resetToIchigeki();
    expect(c.chapterSelectOpen, isFalse);
  });

  testWidgets('shell shows five stages, the hand on the next one, and the evidence button only',
      (tester) async {
    final c = shellOn()..resetToSession2();
    c.interceptDone = true;
    c.s2 = S2Phase.returnCity;
    c.onReturnCity();
    var started = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ChapterSelectShell(controller: c, onStart: () => started++),
      ),
    ));
    final shell = find.byKey(const Key('chapter-select-shell'));
    for (final name in ['逐一擊破', '快馬突擊', '槍擊退敵', '遠攻削敵', '用計得宜']) {
      expect(find.descendant(of: shell, matching: find.text(name)), findsOneWidget);
    }
    expect(find.descendant(of: shell, matching: find.text('回城')), findsNothing);
    expect(find.descendant(of: shell, matching: find.text('6')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('tutorial-lesson-strategy')),
        matching: find.byKey(const Key('tutorial-handoff-hand')),
      ),
      findsOneWidget,
    );
    expect(find.text('開戰'), findsOneWidget);
    expect(find.text('開始'), findsNothing);
    // Not on the foil: no title, no victory banner copy.
    expect(find.text('章節選擇'), findsNothing);
    expect(find.textContaining('勝利'), findsNothing);

    await tester.tap(find.byKey(const Key('chapter-select-start')));
    expect(started, 1);
  });
}
