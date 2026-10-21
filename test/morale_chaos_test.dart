import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';

import 'feel_gates_test.dart' show readyGame;

/// AUTH-GAP §4 result: 「敵軍大破，軍心大亂。」 after the 雷擊 cast.
/// Locks the qualitative result only. The enemy 士氣 loss is an Adapted stub,
/// not an Official figure and not the caster's ~6→~2 spend readout.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Own caster with one enemy inside its ring, both pools stocked, ring open.
  TaisenGame stage(String ownId, String enemyId) {
    final g = readyGame();
    const ownAt = Offset(195, 600);
    g.debugRestageOwnEnemy(
      ownId: ownId,
      ownAt: ownAt,
      enemyAt: ownAt + Offset(g.strategyPreviewRadius * 0.5, 0),
      enemyId: enemyId,
    );
    g.matchMorale = 20;
    g.enemyMatchMorale = 10;
    g.selectedIndex = null;
    g.selectOrDetailAt(ownAt);
    expect(g.strategyPreviewVisible, isTrue);
    return g;
  }

  test('a landed 智力差 cast sets off 軍心大亂 and drops enemy 士氣', () {
    final g = stage('zhouyu', 'lvbu');
    expect(g.moraleChaosActive, isFalse);
    expect(g.moraleChaosLine, isNull);
    expect(g.castStrategyOnMap(g.tokenCenter(0)), isTrue);
    expect(g.debugUnitHp(1), lessThan(TaisenGame.kRansenMaxHp));
    expect(g.moraleChaosActive, isTrue);
    expect(g.moraleChaosLine, TaisenGame.kMoraleChaosLine);
    expect(g.enemyMatchMorale, 10 - TaisenGame.kMoraleChaosEnemyLoss);
  });

  test('軍心大亂 is separate from the caster spend', () {
    final g = stage('zhouyu', 'lvbu');
    final cost = g.field[0].strategyMorale;
    expect(g.castStrategyOnMap(g.tokenCenter(0)), isTrue);
    expect(g.matchMorale, 20 - cost);
  });

  test('enemy 士氣 never goes below 0', () {
    final g = stage('zhouyu', 'lvbu');
    g.enemyMatchMorale = 1;
    expect(g.castStrategyOnMap(g.tokenCenter(0)), isTrue);
    expect(g.enemyMatchMorale, 0);
    expect(g.moraleChaosActive, isTrue);
  });

  test('the result clears with the 計略 FX window', () {
    final g = stage('zhouyu', 'lvbu');
    expect(g.castStrategyOnMap(g.tokenCenter(0)), isTrue);
    g.debugAdvanceStrategyFx(g.debugMoraleChaosLeft + 0.01);
    expect(g.moraleChaosActive, isFalse);
    expect(g.moraleChaosLine, isNull);
  });

  test('a 計略 without 智力差 scaling causes no 軍心大亂', () {
    final g = stage('zhaoyun', 'lvbu');
    expect(g.castStrategyOnMap(g.tokenCenter(0)), isTrue);
    expect(g.moraleChaosActive, isFalse);
    expect(g.enemyMatchMorale, 10);
  });

  test('a cast with no enemy in the ring causes no 軍心大亂', () {
    final g = stage('zhouyu', 'lvbu');
    g.fieldPos[1] = g.tokenCenter(0) + Offset(g.strategyPreviewRadius * 1.5, 0);
    expect(g.castStrategyOnMap(g.tokenCenter(0)), isTrue);
    expect(g.moraleChaosActive, isFalse);
    expect(g.enemyMatchMorale, 10);
  });

  test('a short pool refuses the cast and causes no 軍心大亂', () {
    final g = stage('zhouyu', 'lvbu');
    g.matchMorale = g.field[0].strategyMorale - 1;
    expect(g.castStrategyOnMap(g.tokenCenter(0)), isFalse);
    expect(g.moraleChaosActive, isFalse);
    expect(g.enemyMatchMorale, 10);
  });

  test('the loss is an Adapted stub, not keyed on 6→2', () {
    // Changing it is a later ORDER, not a retune.
    expect(TaisenGame.kMoraleChaosEnemyLoss, 3);
    expect(TaisenGame.kMoraleChaosEnemyLoss, isNot(6 - 2));
  });
}
