import 'package:flutter_test/flutter_test.dart';
import 'package:sangokushi_taisen/game/tutorial_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('travel progress arms aura at 1.0 and mid tips without dropping', () {
    final c = TutorialController();
    c.resetToSession1();
    c.onSelectOwnCavalry();
    expect(c.s1, S1Phase.dragGuide);

    c.onChargeTravelProgress(0.2);
    expect(c.s1, S1Phase.waitAura);
    expect(c.auraReady, isFalse);

    c.onChargeTravelProgress(0.55);
    expect(c.tipText!.contains('氣勢'), isTrue);

    c.onChargeTravelProgress(1.0);
    expect(c.auraReady, isTrue);
    expect(c.didDragDrop, isTrue);
    expect(c.s1, S1Phase.hitCharge);

    c.onAutoCharge();
    expect(c.s1, S1Phase.tipNext);
  });

  test('waitAura is not time-promoted (travel owns aura)', () {
    final c = TutorialController();
    c.resetToSession1();
    c.onSelectOwnCavalry();
    c.onChargeTravelProgress(0.3);
    expect(c.s1, S1Phase.waitAura);
    for (var i = 0; i < 50; i++) {
      c.tick(0.5);
    }
    expect(c.auraReady, isFalse);
    expect(c.s1, S1Phase.waitAura);
  });
}
