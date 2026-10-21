import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/data/card_models.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';

import 'feel_gates_test.dart' show readyGame;

/// AUTH-GAP §4: 「雷擊的效果受雙方智力差距影響。差距越大，雷擊便越有效。」
/// Locks the direction only. The HP figures are Adapted stubs, not an Official
/// formula and not the teaching cards' 智力 6 vs 2.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Own caster with one enemy inside its ring, 士氣 to spare, ring open.
  TaisenGame stage(String ownId, String enemyId) {
    final g = readyGame();
    const ownAt = Offset(195, 600);
    g.debugRestageOwnEnemy(ownId: ownId, ownAt: ownAt, enemyAt: ownAt);
    g.debugRestageOwnEnemy(
      ownId: ownId,
      ownAt: ownAt,
      enemyAt: ownAt + Offset(g.strategyPreviewRadius * 0.5, 0),
      enemyId: enemyId,
    );
    g.matchMorale = 20;
    g.selectedIndex = null;
    g.selectOrDetailAt(ownAt);
    expect(g.strategyPreviewVisible, isTrue);
    return g;
  }

  /// HP the enemy lost to one cast on the caster.
  double castLoss(TaisenGame g) {
    final before = g.debugUnitHp(1);
    expect(g.castStrategyOnMap(g.tokenCenter(0)), isTrue);
    return before - g.debugUnitHp(1);
  }

  test('roster text picks the 智力差 計略 and no other', () {
    final tagged = Cost6Roster.all.where((c) => c.strategyScalesWithIntelGap);
    // 赤壁の大火:「範圍內敵受炎傷害；傷害隨雙方知力上下」. No card is printed 雷擊.
    expect(tagged.map((c) => c.id), ['zhouyu']);
  });

  test('printed 智力 parses from the face string', () {
    final zhouyu = Cost6Roster.all.firstWhere((c) => c.id == 'zhouyu');
    expect(zhouyu.intelValue, 10);
  });

  test('a larger 智力差 strikes harder', () {
    final even = castLoss(stage('zhouyu', 'caocao')); // 10 vs 10
    final mid = castLoss(stage('zhouyu', 'zhanghe')); // 10 vs 7
    final wide = castLoss(stage('zhouyu', 'lvbu')); // 10 vs 1
    expect(even, greaterThan(0));
    expect(mid, greaterThan(even));
    expect(wide, greaterThan(mid));
  });

  test('a negative 智力差 is weaker than an even match and never heals', () {
    final g = stage('zhouyu', 'caocao');
    final cao = g.field[1];
    // Test-only face: same card, higher printed 智力. Not a roster card.
    g.field[1] = CardFace(
      id: 'test-high-intel',
      nameZh: cao.nameZh,
      faction: cao.faction,
      cost: cao.cost,
      troop: cao.troop,
      force: cao.force,
      intel: '13',
      skills: cao.skills,
      strategyName: cao.strategyName,
      strategyMorale: cao.strategyMorale,
      strategyEffect: cao.strategyEffect,
      portraitAsset: cao.portraitAsset,
      source: cao.source,
    );
    final behind = g.intelGapStrikeHp(0, 1);
    expect(behind, lessThan(TaisenGame.kIntelGapStrikeBaseHp));
    expect(behind, greaterThanOrEqualTo(0));
  });

  test('the spend path is unchanged by the strike', () {
    final g = stage('zhouyu', 'lvbu');
    final cost = g.field[0].strategyMorale;
    final pool = g.matchMorale;
    castLoss(g);
    expect(g.matchMorale, pool - cost);
    expect(g.debugStrategyBeamFrom, g.tokenCenter(0));
    expect(g.strategyCastBlocksField, isFalse);
  });

  test('a short pool refuses the cast and strikes nothing', () {
    final g = stage('zhouyu', 'lvbu');
    g.matchMorale = g.field[0].strategyMorale - 1;
    expect(g.castStrategyOnMap(g.tokenCenter(0)), isFalse);
    expect(g.debugUnitHp(1), TaisenGame.kRansenMaxHp);
  });

  test('a 計略 without printed 智力 scaling strikes nothing', () {
    final g = stage('zhaoyun', 'lvbu');
    expect(castLoss(g), 0);
  });

  test('an enemy outside the ring is not struck', () {
    final g = stage('zhouyu', 'lvbu');
    g.fieldPos[1] = g.tokenCenter(0) + Offset(g.strategyPreviewRadius * 1.5, 0);
    expect(castLoss(g), 0);
  });

  test('the stub is linear in the gap, not keyed on 6 vs 2', () {
    final g = stage('zhouyu', 'lvbu');
    final at9 = g.intelGapStrikeHp(0, 1);
    expect(
      at9,
      TaisenGame.kIntelGapStrikeBaseHp + TaisenGame.kIntelGapStrikeHpPerIntel * 9,
    );
    // Adapted / Unverified stubs. Changing them is a later ORDER, not a retune.
    expect(TaisenGame.kIntelGapStrikeBaseHp, 20.0);
    expect(TaisenGame.kIntelGapStrikeHpPerIntel, 8.0);
  });
}
