import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/data/card_models.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';
import 'package:sangokushi_taisen/game/tutorial_controller.dart';
import 'package:sangokushi_taisen/game/unit_life.dart';

import 'feel_gates_test.dart' show readyGame;

/// 英傑 戰鬥教學 stage 1 逐一擊破: own 刀兵 vs enemy 刀兵. 刀兵 has no troop
/// specialty, so the lesson is drag into contact and win the 亂戰.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Walk the own 刀兵 onto the foe and hold until the coach leaves 亂戰.
  void marchIntoFoe(TaisenGame g, TutorialController coach) {
    final own = g.tutorialOwnIndex!;
    final foe = g.tutorialEnemyIndex!;
    g.panStart(g.tokenCenter(own));
    g.panUpdate(g.tokenCenter(foe));
    g.panEnd(g.tokenCenter(foe));
    for (var i = 0; i < 60 * 40; i++) {
      g.debugStepPursuit(1 / 60);
      if (coach.s0 != IchigekiPhase.selectFoot && coach.s0 != IchigekiPhase.ransen) break;
    }
  }

  test('rail opens on 逐一擊破 and keeps the later stages named and locked', () {
    final c = TutorialController()..resetToIchigeki();
    expect(c.session, TutorialSession.ichigeki);
    expect(c.lessons.map((l) => l.name).toList(),
        ['逐一擊破', '快馬突擊', '槍擊退敵', '遠攻削敵', '回城', '用計得宜']);
    expect(c.lessons.first.gate, TutorialLessonGate.current);
    expect(c.lessons.skip(1).every((l) => l.gate == TutorialLessonGate.locked), isTrue);
    expect(c.tipText, contains('刀兵無兵種特性，只能發動亂戰'));
    expect(c.tipSkippable, isFalse);

    c.skipTip();
    expect(c.session, TutorialSession.ichigeki, reason: 'the tip cannot skip 亂戰');

    c.onIchigekiRansen();
    expect(c.s0, IchigekiPhase.ransen);
    c.onIchigekiEnemyRouted();
    expect(c.s0, IchigekiPhase.tipNext);
    expect(c.tipSkippable, isTrue);
    expect(c.lessons.first.gate, TutorialLessonGate.done);
    expect(c.lessons[1].gate, TutorialLessonGate.current, reason: '快馬突擊 is next');

    c.skipTip();
    expect(c.session, TutorialSession.session1);
    expect(c.s1, S1Phase.highlightSelect);
    expect(c.lessons.first.gate, TutorialLessonGate.done);
    expect(c.lessons[1].gate, TutorialLessonGate.current);
  });

  test('field is 刀兵 vs 刀兵 with no charge, tip, or bow', () {
    final coach = TutorialController()..resetToIchigeki();
    final g = readyGame(tutorial: coach)..setupIchigekiField();
    expect(g.field, hasLength(2));
    expect(g.field.every((c) => c.troop == TroopType.infantry), isTrue);
    expect(g.isEnemyAt(0), isFalse);
    expect(g.isEnemyAt(1), isTrue);
    expect(g.debugUnitHp(0), TaisenGame.kRansenMaxHp);
    expect(g.debugUnitHp(1), TaisenGame.kIchigekiEnemyHp);

    // The enemy card is read-only.
    g.selectOrDetailAt(g.tokenCenter(1));
    expect(g.selectedIndex, isNot(1));
    g.panStart(g.tokenCenter(1));
    expect(g.dragging, isFalse);
  });

  test('drag into the foe enters 亂戰; the foe routs and 逐一擊破 clears', () {
    final coach = TutorialController()..resetToIchigeki();
    final g = readyGame(tutorial: coach)..setupIchigekiField();
    var sawRansen = false;
    final own = g.tutorialOwnIndex!;
    final foe = g.tutorialEnemyIndex!;
    g.panStart(g.tokenCenter(own));
    expect(g.dragging, isTrue);
    g.panUpdate(g.tokenCenter(foe));
    g.panEnd(g.tokenCenter(foe));
    for (var i = 0; i < 60 * 40; i++) {
      g.debugStepPursuit(1 / 60);
      if (coach.s0 == IchigekiPhase.ransen) {
        sawRansen = true;
        expect(g.debugInRansen(own), isTrue);
        expect(g.debugHitLabel, isNot('突撃'), reason: '刀兵 has no 突撃');
      }
      if (coach.s0 == IchigekiPhase.tipNext) break;
    }
    expect(sawRansen, isTrue);
    expect(coach.s0, IchigekiPhase.tipNext);
    expect(g.debugUnitLife(foe), isNot(UnitLife.alive));
    expect(g.debugUnitLife(own), UnitLife.alive);
    expect(g.debugUnitHp(own), lessThan(TaisenGame.kRansenMaxHp),
        reason: '亂戰 is mutual: own 刀兵 pays too');

    // 快馬突擊 starts on fresh bodies, not the routed foe.
    coach.skipTip();
    g.setupSession1Field();
    expect(coach.session, TutorialSession.session1);
    expect(g.field[0].troop, TroopType.cavalry);
    expect(g.debugUnitLife(1), UnitLife.alive);
    expect(g.debugUnitHp(1), TaisenGame.kRansenMaxHp);
  });

  test('own 刀兵 routing first fails the stage and re-seeds the pair', () {
    final coach = TutorialController()..resetToIchigeki();
    final g = readyGame(tutorial: coach)..setupIchigekiField();
    g.debugSetUnitHp(0, 1);
    marchIntoFoe(g, coach);
    expect(coach.s0, IchigekiPhase.failRetry);
    expect(coach.failed, isTrue);
    expect(g.debugUnitLife(0), isNot(UnitLife.alive));

    coach.tick(0.8 * 3.03);
    expect(coach.s0, IchigekiPhase.selectFoot);
    expect(coach.ichigekiNeedsField, isTrue);
    g.consumeIchigekiRetry();
    expect(coach.ichigekiNeedsField, isFalse);
    expect(g.debugUnitLife(0), UnitLife.alive);
    expect(g.debugUnitHp(0), TaisenGame.kRansenMaxHp);
    expect(g.debugUnitHp(1), TaisenGame.kIchigekiEnemyHp);

    marchIntoFoe(g, coach);
    expect(coach.s0, IchigekiPhase.tipNext);
  });

  test('splitting the pair mid-亂戰 drops the coach back to the drag step', () {
    final coach = TutorialController()..resetToIchigeki();
    final g = readyGame(tutorial: coach)..setupIchigekiField();
    final own = g.tutorialOwnIndex!;
    final foe = g.tutorialEnemyIndex!;
    g.panStart(g.tokenCenter(own));
    g.panUpdate(g.tokenCenter(foe));
    g.panEnd(g.tokenCenter(foe));
    for (var i = 0; i < 60 * 20 && coach.s0 != IchigekiPhase.ransen; i++) {
      g.debugStepPursuit(1 / 60);
    }
    expect(coach.s0, IchigekiPhase.ransen);

    final back = g.tokenCenter(own) + const Offset(0, 260);
    g.panStart(g.tokenCenter(own));
    g.panUpdate(back);
    g.panEnd(back);
    for (var i = 0; i < 60 * 10 && coach.s0 == IchigekiPhase.ransen; i++) {
      g.debugStepPursuit(1 / 60);
    }
    expect(coach.s0, IchigekiPhase.selectFoot);
    expect(g.debugUnitLife(foe), UnitLife.alive);
  });
}
