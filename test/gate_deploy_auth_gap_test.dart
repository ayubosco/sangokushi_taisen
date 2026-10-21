import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/data/card_models.dart';
import 'package:sangokushi_taisen/game/c_clock.dart';
import 'package:sangokushi_taisen/game/fx_windows.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';
import 'package:sangokushi_taisen/game/tutorial_controller.dart';
import 'package:sangokushi_taisen/game/unit_life.dart';

import 'feel_gates_test.dart' show readyGame;

/// AUTH-GAP leftover: hand card → 自陣城門. Observed-from-英傑 foil yellow path
/// 「刀兵 card → 城門」, and the note that deploying a hand card onto 自陣城門 is
/// a separate order from a field drag. The card parks in 己城 and leaves
/// through the existing ~4成 exit line and 出城·出征 prep. No deploy timer,
/// cost, or px is invented. Not a Feel Pass.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reused knobs stay put; deploy adds no number', () {
    expect(TaisenGame.kCastleEnterDepth, 0.60);
    expect(TaisenGame.kCastleExitDepth, 0.40);
    expect(TaisenGame.kSortiePrepBaseC, 2.5);
    expect(TaisenGame.fieldMax, 5);
  });

  test('a hand card dropped on the field is refused and stays in hand', () {
    final g = _matchWithHand([_foot()]);
    final before = g.field.length;
    expect(g.deployHandCardToGate(0, Offset(g.size.x / 2, g.watchH + g.fieldH * 0.5)), isFalse);
    // Inside the band but short of the ~6成 enter depth: not on the gate yet.
    final band = g.castleBandRect;
    final shallow = Offset(band.center.dx, band.top + band.height * (TaisenGame.kCastleEnterDepth - 0.1));
    expect(g.deployHandCardToGate(0, shallow), isFalse);
    expect(g.field.length, before);
    expect(g.hand, hasLength(1));
  });

  test('gate drop parks the card in 己城 at the 歸城 rest depth, alive and full', () {
    final g = _matchWithHand([_foot()]);
    final before = g.field.length;
    expect(g.deployHandCardToGate(0, _gateDrop(g)), isTrue);
    final i = before;
    expect(g.hand, isEmpty);
    expect(g.field, hasLength(before + 1));
    expect(g.field[i].troop, TroopType.infantry);
    expect(g.isEnemyAt(i), isFalse);
    expect(g.fieldInCastle[i], isTrue);
    expect(g.inCastleBand(g.tokenCenter(i)), isTrue);
    expect(g.castleDepth01(g.tokenCenter(i)), closeTo(0.72, 1e-9));
    expect(g.debugUnitLife(i), UnitLife.alive);
    expect(g.debugUnitHp(i), TaisenGame.kRansenMaxHp);
    expect(g.debugSortiePrepVisible(i), isFalse);
  });

  test('deploy is its own order: an in-flight field drag keeps its pin', () {
    final g = _matchWithHand([_foot()]);
    final start = g.tokenCenter(0);
    g.panStart(start);
    final pin = Offset(start.dx + 40, start.dy - 120);
    g.panUpdate(pin);
    expect(g.dragging, isTrue);
    final pinned = g.dragTo;

    expect(g.deployHandCardToGate(0, _gateDrop(g)), isTrue);
    expect(g.dragging, isTrue);
    expect(g.selectedIndex, 0);
    expect(g.dragTo, pinned);
  });

  test('no deploy timer: the card waits in 己城 until the player drags it out', () {
    final g = _matchWithHand([_foot()]);
    final i = g.field.length;
    g.deployHandCardToGate(0, _gateDrop(g));
    final rest = g.tokenCenter(i);
    g.debugStepPursuit(3 * CClock.secondsPerC);
    expect(g.tokenCenter(i), rest);
    expect(g.fieldInCastle[i], isTrue);
    expect(g.debugSortiePrepVisible(i), isFalse);
  });

  test('drag out crosses ~4成 into the same 出城·出征 prep as a 歸城 body', () {
    for (final troop in [TroopType.infantry, TroopType.cavalry]) {
      final card = Cost6Roster.all.firstWhere((c) => c.troop == troop);
      final g = _matchWithHand([card]);
      final i = g.field.length;
      g.deployHandCardToGate(0, _gateDrop(g));
      final from = g.tokenCenter(i);
      final out = Offset(from.dx, g.castleBandRect.top - 160);
      // Same gesture as a parked 歸城 body: finger stays down while it walks out.
      g.panStart(from);
      g.panUpdate(out);
      expect(g.selectedIndex, i);
      expect(g.debugSortiePrepVisible(i), isFalse, reason: 'still inside the exit line');

      var guard = 0;
      while (!g.debugSortiePrepVisible(i) && guard++ < 600) {
        g.debugStepPursuit(1 / 60);
      }
      g.panEnd(out);
      expect(g.debugSortiePrepVisible(i), isTrue);
      expect(g.debugSortiePrepCaption(i), TaisenGame.kSortiePrepCaption);
      expect(g.fieldInCastle[i], isFalse);
      expect(g.castleDepth01(g.tokenCenter(i)), lessThanOrEqualTo(TaisenGame.kCastleExitDepth + 0.05));
      expect(g.debugSortiePrepLeft(i), closeTo(_prepSeconds(troop), 0.02));
      expect(g.auraActive, isFalse);

      final held = g.tokenCenter(i);
      g.debugStepPursuit(g.debugSortiePrepLeft(i) / 2);
      expect(g.tokenCenter(i), held, reason: 'prep holds the body; no teleport');
      g.debugStepPursuit(g.debugSortiePrepLeft(i) + 1 / 60);
      expect(g.debugSortiePrepVisible(i), isFalse);
      expect(g.debugUnitLife(i), UnitLife.alive);
      expect(g.debugHitLabel, isNot('突撃'));
    }
  });

  test('field cap and lesson rail refuse the deploy', () {
    final full = readyGame();
    full.setupMatchDemoField();
    expect(full.field, hasLength(TaisenGame.fieldMax));
    full.hand.add(_foot());
    expect(full.deployHandCardToGate(0, _gateDrop(full)), isFalse);
    expect(full.hand, hasLength(1));

    final coach = TutorialController();
    final lesson = readyGame(tutorial: coach);
    lesson.setupSession1Field();
    final before = lesson.field.length;
    lesson.hand.add(_foot());
    expect(lesson.deployHandCardToGate(0, _gateDrop(lesson)), isFalse);
    expect(lesson.field, hasLength(before));
  });
}

CardFace _foot() => Cost6Roster.all.firstWhere((c) => c.troop == TroopType.infantry,
    orElse: () => Cost6Roster.all.first);

TaisenGame _matchWithHand(List<CardFace> cards) {
  final g = readyGame();
  g.debugRestageOwnEnemy(
    ownId: 'zhaoyun',
    ownAt: Offset(g.size.x * 0.30, g.watchH + g.fieldH * 0.60),
    enemyAt: Offset(g.size.x * 0.70, g.watchH + g.fieldH * 0.20),
  );
  g.hand.addAll(cards);
  return g;
}

Offset _gateDrop(TaisenGame g) {
  final band = g.castleBandRect;
  return Offset(band.center.dx, band.top + band.height * 0.8);
}

/// Prep seconds a 歸城 body gets at the exit line, via the existing path.
double _prepSeconds(TroopType troop) {
  final wiki = TaisenGame.pursuitWikiBase(troop);
  final spear = TaisenGame.pursuitWikiBase(TroopType.spear);
  if (wiki <= 0) return FxWindows.toSeconds(TaisenGame.kSortiePrepBaseC);
  return FxWindows.toSeconds(TaisenGame.kSortiePrepBaseC * (spear / wiki));
}
