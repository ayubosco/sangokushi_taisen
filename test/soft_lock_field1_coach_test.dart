import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/data/card_models.dart';
import 'package:sangokushi_taisen/game/tutorial_controller.dart';

import 'feel_gates_test.dart' show readyGame;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Field1 Soft Lock coach: tip cannot skip 槍→弓→回城→用計 gates', () {
    final c = TutorialController()..resetToSession2();
    expect(c.s2, S2Phase.spearGlow);
    expect(c.tipSkippable, isFalse);
    c.skipTip();
    expect(c.s2, S2Phase.spearGlow);
    expect(c.tipText, isNotNull);

    // Advance to turn window without auto facing.
    c.tick(0.4 * 3.03);
    expect(c.s2, S2Phase.enemyApproach);
    c.tick(0.3 * 3.03);
    expect(c.s2, S2Phase.waitTurn);
    c.tick(1.0 * 3.03);
    expect(c.turnWindowOpen, isTrue);
    expect(c.facingCorrect, isFalse, reason: 'MOVE owns facing — no auto-pass');

    c.skipTip();
    expect(c.s2, S2Phase.waitTurn);

    c.onSpearAimedByMove();
    expect(c.facingCorrect, isTrue);
    expect(c.s2, S2Phase.interceptHit);

    c.onAutoIntercept(facingWasCorrect: true);
    // 槍擊退敵 beat two: 更多的騎兵 → 回頭 into a gold 槍擊.
    c.onSpearAimedByMove();
    c.onTurnBackHit();
    expect(c.interceptDone, isTrue);
    expect(c.s2, S2Phase.bowTeach);

    c.skipTip();
    expect(c.s2, S2Phase.bowTeach);

    c.onBowShot();
    expect(c.s2, S2Phase.bowTeach, reason: '遠攻削敵 still wants 單一弓兵攻城');
    c.onBowSiegeLanded();
    expect(c.s2, S2Phase.bowTeach, reason: '遠攻削敵 still wants 另一弓兵從後支援');
    c.onBowSupportShot();
    expect(c.s2, S2Phase.bowTeach, reason: '遠攻削敵 still wants 輪流走位牽制');
    c.onBowKiteShot(mover: 1);
    c.onBowKiteShot(mover: 4);
    expect(c.s2, S2Phase.returnCity);

    c.skipTip();
    expect(c.s2, S2Phase.returnCity);

    // 計略 alone does not clear Soft Lock Field1.
    c.onStrategy();
    expect(c.s2, S2Phase.returnCity);
    expect(c.strategyOrReturnDone, isFalse);

    c.onReturnCity(0);
    c.onReturnHealed(0);
    c.onReturnSortied(0);
    expect(c.s2, S2Phase.strategyTeach);
    expect(c.strategyOrReturnDone, isTrue);
    expect(c.strategyLessonLive, isTrue);

    c.skipTip();
    expect(c.s2, S2Phase.strategyTeach, reason: 'tip cannot skip 用計得宜');

    c.onStrategy();
    expect(c.s2, S2Phase.tipDone);
    expect(c.tipSkippable, isTrue);
  });

  test('Session2 field stages spear+bow and allows Soft Lock return drag', () {
    final coach = TutorialController()..resetToSession2();
    final g = readyGame(tutorial: coach);
    g.setupSession2Field();

    var hasSpear = false;
    var hasBow = false;
    for (var i = 0; i < g.field.length; i++) {
      if (g.fieldIsEnemy[i]) continue;
      if (g.field[i].troop == TroopType.spear) hasSpear = true;
      if (g.field[i].troop == TroopType.bow) hasBow = true;
    }
    expect(hasSpear, isTrue);
    expect(hasBow, isTrue);
    expect(g.debugSpearIndex, isNotNull);
    expect(g.debugChargingEnemyIndex, isNotNull);

    coach.interceptDone = true;
    coach.s2 = S2Phase.returnCity;
    coach.tipText = '拖返';
    final band = g.castleBandRect;
    final own = g.tokenCenter(0);
    g.panStart(own);
    expect(g.dragging, isTrue, reason: 'Session2 returnCity must allow drag');
    final deep = Offset(own.dx, band.top + band.height * 0.72);
    g.panEnd(deep);
    var guard = 0;
    while (g.dragTo != null && guard < 600) {
      g.debugStepPursuit(1 / 60);
      guard++;
    }
    expect(
      coach.s2 == S2Phase.strategyTeach || (g.fieldInCastle.isNotEmpty && g.fieldInCastle[0]),
      isTrue,
      reason: '歸城 park must advance or park the body',
    );
  });

  test('bow standing runs during bowTeach (tutorial no longer hard-blocks 弓)', () {
    final coach = TutorialController()..resetToSession2();
    coach.interceptDone = true;
    coach.s2 = S2Phase.bowTeach;
    final g = readyGame(tutorial: coach);
    g.setupSession2Field();

    int? bow;
    int? target;
    for (var i = 0; i < g.field.length; i++) {
      if (!g.fieldIsEnemy[i] && g.field[i].troop == TroopType.bow) bow = i;
      if (g.fieldIsEnemy[i] && i != g.debugChargingEnemyIndex) target = i;
    }
    expect(bow, isNotNull);
    expect(target, isNotNull);
    g.selectedIndex = bow;
    g.fieldPos[bow!] = g.fieldPos[target!] + const Offset(-90, 50);
    g.dragging = false;
    g.dragTo = null;

    var guard = 0;
    while (!coach.bowShotLanded && guard < 500) {
      g.debugStepPursuit(1 / 60);
      guard++;
    }
    expect(coach.bowShotLanded, isTrue, reason: 'standing bow must land the shot beat');
    expect(g.debugHitLabel, '射');
    expect(coach.s2, S2Phase.bowTeach, reason: 'a shot alone does not clear 遠攻削敵');
  });
}
