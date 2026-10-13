import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/game/soft_lock_cues.dart';
import 'package:sangokushi_taisen/game/taisen_game.dart';

import 'feel_gates_test.dart' show readyGame;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Soft Lock cue sprites load from assets/fx/soft-lock-cues', () async {
    final bank = SoftLockCueBank();
    await bank.loadAll();
    expect(bank.isLoaded, isTrue, reason: 'all Design cue names must resolve');
    for (final name in SoftLockCueBank.names) {
      expect(bank.has(name), isTrue, reason: name);
      expect(SoftLockCueBank.sizePt.containsKey(name), isTrue);
    }
  });

  test('TaisenGame onLoad attaches Soft Lock cues without changing L0 gameplay hooks', () async {
    final g = readyGame();
    await g.onLoad();
    expect(g.softLockCues.isLoaded, isTrue);
    // Gameplay flags at HEAD stay intact (no combat invent).
    expect(TaisenGame.kSpearTipReach, greaterThan(40));
    expect(g.debugBowWinding, isFalse);
  });
}
