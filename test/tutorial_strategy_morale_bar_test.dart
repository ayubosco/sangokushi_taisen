import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/game/c_clock.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';
import 'package:sangokushi_taisen/game/tutorial_controller.dart';
import 'package:sangokushi_taisen/ui/morale_bar.dart';

import 'feel_gates_test.dart' show readyGame;

/// 英傑 stage 5 用計得宜 cue「士氣欄高亮提示計略所需士氣值」. While a caster's
/// 計略範圍 is up, the HUD 士氣 bar lights the caster's printed 士氣 (the pips
/// a cast would spend). A short pool shows the missing points as outlined
/// hexes. The cost comes from the card face, and regen keeps its Adapted
/// stub. No new number. Not a Feel Pass.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pointSec = TaisenGame.kMoraleRegenCPerPoint * CClock.secondsPerC;

  Future<void> pumpBar(WidgetTester tester, {required int morale, int? need}) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Center(child: MoraleBar(morale: morale, need: need))),
    ));
  }

  group('bar', () {
    test('lit pips are the cost, capped by the pool; short is the rest', () {
      expect(MoraleBar.litPips(6, 2), 2);
      expect(MoraleBar.shortPips(6, 2), 0);
      expect(MoraleBar.litPips(2, 2), 2);
      expect(MoraleBar.shortPips(2, 2), 0);
      expect(MoraleBar.litPips(1, 4), 1);
      expect(MoraleBar.shortPips(1, 4), 3);
      expect(MoraleBar.litPips(0, 3), 0);
      expect(MoraleBar.shortPips(0, 3), 3);
      expect(MoraleBar.litPips(5, null), 0);
      expect(MoraleBar.shortPips(5, null), 0);
    });

    testWidgets('no range up: plain fill, nothing lit', (tester) async {
      await pumpBar(tester, morale: 5);
      expect(find.byKey(const Key('match-morale-pip')), findsNWidgets(5));
      expect(find.byKey(const Key('match-morale-need')), findsNothing);
      expect(find.byKey(const Key('match-morale-short')), findsNothing);
    });

    testWidgets('affordable: the trailing cost pips light up', (tester) async {
      await pumpBar(tester, morale: 5, need: 3);
      expect(find.byKey(const Key('match-morale-pip')), findsNWidgets(5));
      expect(find.byKey(const Key('match-morale-need')), findsNWidgets(3));
      expect(find.byKey(const Key('match-morale-short')), findsNothing);
      // The lit run is the tail of the bar, the points a cast would spend.
      final pips = tester
          .widgetList<Padding>(find.descendant(
            of: find.byType(MoraleBar),
            matching: find.byType(Padding),
          ))
          .toList();
      final litFlags = [
        for (final p in pips)
          find
              .descendant(
                of: find.byWidget(p),
                matching: find.byKey(const Key('match-morale-need')),
              )
              .evaluate()
              .isNotEmpty,
      ];
      expect(litFlags, [false, false, true, true, true]);
    });

    testWidgets('short: the whole pool lights and the gap is outlined', (tester) async {
      await pumpBar(tester, morale: 1, need: 4);
      expect(find.byKey(const Key('match-morale-pip')), findsOneWidget);
      expect(find.byKey(const Key('match-morale-need')), findsOneWidget);
      expect(find.byKey(const Key('match-morale-short')), findsNWidgets(3));
    });
  });

  group('game', () {
    TaisenGame strategyStage(TutorialController coach) {
      coach.resetToSession2();
      final g = readyGame(tutorial: coach);
      g.setupSession2Field();
      coach.interceptDone = true;
      coach.s2 = S2Phase.strategyTeach;
      return g;
    }

    test('the need is the previewed caster’s printed 士氣, and only while the range is up', () {
      final coach = TutorialController();
      final g = strategyStage(coach);
      // 場2 opens with the lesson unit's ring up, so the bar is lit with it.
      expect(g.strategyPreviewVisible, isTrue);
      expect(g.strategyMoraleNeed, isNotNull);
      g.cancelStrategyPreview();
      expect(g.strategyMoraleNeed, isNull);

      g.selectOrDetailAt(g.tokenCenter(2));
      expect(g.strategyMoraleNeed, isNull, reason: 'enemy taps open no range');

      g.selectOrDetailAt(g.tokenCenter(1));
      expect(g.strategyPreviewVisible, isTrue);
      expect(g.strategyMoraleNeed, g.field[1].strategyMorale);
      expect(g.strategyMoraleReady, isTrue);

      g.cancelStrategyPreview();
      expect(g.strategyMoraleNeed, isNull);
    });

    test('a range tap points the tip at the lit cost; the cast still clears', () {
      final coach = TutorialController();
      final g = strategyStage(coach);
      final at = g.tokenCenter(1);
      g.selectOrDetailAt(at);
      expect(coach.tipText, contains('士氣欄高亮'));
      expect(coach.tipText, contains('撳計略放'));
      expect(coach.s2, S2Phase.strategyTeach, reason: 'the preview is not the cast');

      expect(g.castStrategyOnMap(at), isTrue);
      expect(g.strategyMoraleNeed, isNull, reason: 'the cast drops the range and the lit cost');
      expect(coach.s2, S2Phase.tipDone);
    });

    test('a short pool says wait; regen up to the cost flips the tip once', () {
      final coach = TutorialController();
      final g = strategyStage(coach);
      final cost = g.strategyMoraleCostAt(1)!;
      g.matchMorale = 0;

      g.selectOrDetailAt(g.tokenCenter(1));
      expect(g.strategyMoraleReady, isFalse);
      expect(coach.tipText, contains('士氣唔夠'));
      expect(g.castStrategyAtSelected(), isFalse);

      var notes = 0;
      coach.addListener(() => notes++);
      for (var p = 1; p < cost; p++) {
        g.debugAdvanceMoraleRegen(pointSec + 0.001);
      }
      expect(g.matchMorale, cost - 1);
      expect(coach.tipText, contains('士氣唔夠'));
      expect(notes, 0, reason: 'still short: the tip does not churn');

      g.debugAdvanceMoraleRegen(pointSec + 0.001);
      expect(g.matchMorale, cost);
      expect(g.strategyMoraleReady, isTrue);
      expect(coach.tipText, contains('撳計略放'));
      expect(notes, 1);

      expect(g.castStrategyAtSelected(), isTrue);
      expect(coach.s2, S2Phase.tipDone);
    });

    test('off 用計得宜 the coach tip is left alone', () {
      final coach = TutorialController()..resetToSession2();
      final g = readyGame(tutorial: coach);
      g.setupSession2Field();
      coach.interceptDone = true;
      coach.s2 = S2Phase.returnCity;
      final tip = coach.tipText;
      g.selectOrDetailAt(g.tokenCenter(1));
      expect(g.strategyMoraleNeed, g.field[1].strategyMorale,
          reason: 'the bar still lights wherever a range is up');
      expect(coach.tipText, tip);

      coach.onStrategyPreview(ready: true);
      expect(coach.tipText, tip);
    });
  });
}
