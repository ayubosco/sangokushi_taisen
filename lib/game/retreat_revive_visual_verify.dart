import 'package:flutter/material.dart';

import 'taisen_game.dart';
import 'unit_life.dart';

/// dart-define: RETREAT_REVIVE_VISUAL_VERIFY=true
/// Free-match sequence for the four retreat／revive checks. Never sets
/// shotPassMode, DEMO_SHOT, or FEEL_SHOT. Cloud does not run this on a device.
///
/// When Air is back:
/// flutter run --dart-define=RETREAT_REVIVE_VISUAL_VERIFY=true -d <udid>
///
/// Holds (log line RETREAT_REVIVE_VISUAL_VERIFY PASS|FAIL):
/// 1. R1 Force HP→0 → skull + 「撤退」; reviveLeft frozen after 3s outside 己城
/// 2. R2 Drag into castleBand → reviveLeft ticks
/// 3. R3 Countdown ends → HP=100, body can leave and return to alive
/// 4. R4 Alive enter castle → no skull, tip「返城回血」, label is not 「復活」
const bool kRetreatReviveVisualVerify = bool.fromEnvironment(
  'RETREAT_REVIVE_VISUAL_VERIFY',
  defaultValue: false,
);

/// How long each prove frame stays put so a later device capture can grab it.
const Duration kRetreatReviveVisualHold = Duration(seconds: 4);

/// Steps per second. Device [step] is a 16ms yield while the engine runs.
/// The cloud test's [step] must call `debugStepPursuit(1/60)`.
const int kRetreatReviveVerifyFps = 60;

class RetreatReviveVisualShot {
  const RetreatReviveVisualShot({
    required this.id,
    required this.caption,
    required this.hold,
    required this.life,
    required this.skull,
    required this.splash,
    required this.hp,
    required this.hpMark,
    required this.reviveLeft,
    required this.reviveMark,
    required this.tip,
    required this.morale,
    required this.moraleMark,
    required this.ready,
    required this.leftCastle,
    required this.exitArmed,
  });

  final String id;
  final String caption;
  final Duration hold;
  final UnitLife life;
  final bool skull;
  final String splash;
  final double hp;
  final double hpMark;
  final double reviveLeft;
  final double reviveMark;
  final String tip;
  final int morale;
  final int moraleMark;
  final bool ready;
  final bool leftCastle;
  final bool exitArmed;

  bool get pass {
    switch (id) {
      case 'R1':
        return life == UnitLife.retreating &&
            skull &&
            splash == '撤退' &&
            hp == 0 &&
            (reviveLeft - reviveMark).abs() < 0.05 &&
            tip == '散咗拖返城先復活' &&
            morale == moraleMark;
      case 'R2':
        return life == UnitLife.inCastleReviving &&
            skull &&
            reviveLeft < reviveMark - 0.10 &&
            hp == 0 &&
            splash != '復活';
      case 'R3':
        return ready &&
            leftCastle &&
            exitArmed &&
            !skull &&
            life == UnitLife.alive &&
            hp == TaisenGame.kRansenMaxHp &&
            splash != '復活';
      case 'R4':
        return life == UnitLife.alive &&
            !skull &&
            tip == '返城回血' &&
            splash != '復活' &&
            splash != '撤退' &&
            reviveLeft == 0 &&
            hp > hpMark &&
            hp < TaisenGame.kRansenMaxHp;
      default:
        return false;
    }
  }
}

/// Drives R1–R4 on a free-match [TaisenGame] (tutorial stays null).
class RetreatReviveVisualVerify {
  RetreatReviveVisualVerify({
    required this.game,
    required this.step,
    required this.hold,
  });

  final TaisenGame game;
  final Future<void> Function() step;
  final Future<void> Function(RetreatReviveVisualShot shot) hold;

  Future<void> run() async {
    if (game.tutorial != null) {
      // ignore: avoid_print
      print('RETREAT_REVIVE_VISUAL_VERIFY skip tutorial!=null (free match only)');
      return;
    }
    // ignore: avoid_print
    print(
      'RETREAT_REVIVE_VISUAL_VERIFY start free-match '
      'define=RETREAT_REVIVE_VISUAL_VERIFY shotPass=false '
      'baseSec=${TaisenGame.kReviveBaseSec} skillMul=${TaisenGame.kReviveSkillMul} '
      'moraleCost=${TaisenGame.kRetreatMoraleCost}',
    );
    final sized = await _until(() => game.size.x > 1 && game.size.y > 1);
    if (!sized) {
      // ignore: avoid_print
      print('RETREAT_REVIVE_VISUAL_VERIFY FAIL no game size');
      return;
    }
    await _frameFrozenOutside();
    await _frameCastleTicks();
    await _frameCompleteRedeploy();
    await _frameAliveHeal();
    // ignore: avoid_print
    print('RETREAT_REVIVE_VISUAL_VERIFY done');
  }

  Future<void> _frameFrozenOutside() async {
    game.debugRestageOwnEnemy(
      ownId: 'zhaoyun',
      ownAt: _outside(),
      enemyAt: _enemyFar(),
    );
    game.matchMorale = 5;
    game.debugForceHpZero(0);
    final splash = game.debugHitLabel;
    final reviveAtForce = game.debugReviveLeft(0);
    final moraleAtForce = game.matchMorale;
    await _advance(3);
    // The 1s 「撤退」 splash decays during the freeze proof on device.
    // Put it back for the hold so the capture shows the flash, not only the skull.
    game.flashHit(0, '撤退');
    await _emit(
      id: 'R1',
      caption: 'R1 撤退 frozen',
      splash: splash,
      hpMark: 0,
      reviveMark: reviveAtForce,
      moraleMark: moraleAtForce,
      ready: false,
      leftCastle: false,
      exitArmed: false,
    );
  }

  Future<void> _frameCastleTicks() async {
    final before = game.debugReviveLeft(0);
    final body = game.tokenCenter(0);
    final into = _castlePoint();
    game.resumeEngine();
    game.panStart(body);
    game.panEnd(into);
    final ticking = await _until(
      () =>
          game.debugUnitLife(0) == UnitLife.inCastleReviving &&
          game.debugReviveLeft(0) < before - 0.10,
      maxSteps: 800,
    );
    if (!ticking) {
      // ignore: avoid_print
      print('RETREAT_REVIVE_VISUAL_VERIFY FAIL R2 countdown never ticked');
    }
    await _emit(
      id: 'R2',
      caption: 'R2 castle tick',
      splash: game.debugHitLabel,
      hpMark: 0,
      reviveMark: before,
      moraleMark: game.matchMorale,
      ready: false,
      leftCastle: false,
      exitArmed: false,
    );
  }

  Future<void> _frameCompleteRedeploy() async {
    final done = await _until(
      () => game.debugUnitLife(0) == UnitLife.readyRedeploy,
      maxSteps: 20 * kRetreatReviveVerifyFps,
    );
    if (!done) {
      // ignore: avoid_print
      print('RETREAT_REVIVE_VISUAL_VERIFY FAIL R3 revive never finished');
    }
    final ready = game.debugUnitLife(0) == UnitLife.readyRedeploy &&
        game.debugUnitHp(0) == TaisenGame.kRansenMaxHp;
    final body = game.tokenCenter(0);
    final band = game.castleBandRect;
    final out = Offset(body.dx, band.top - 90);
    game.resumeEngine();
    game.panStart(body);
    game.panEnd(out);
    final exitArmed = game.dragTo != null;
    final left = await _until(
      () => game.debugUnitLife(0) == UnitLife.alive,
      maxSteps: 800,
    );
    if (!left) {
      // ignore: avoid_print
      print('RETREAT_REVIVE_VISUAL_VERIFY FAIL R3 body never left 己城');
    }
    await _emit(
      id: 'R3',
      caption: 'R3 HP100 redeploy',
      splash: game.debugHitLabel,
      hpMark: TaisenGame.kRansenMaxHp,
      reviveMark: 0,
      moraleMark: game.matchMorale,
      ready: ready,
      leftCastle: left,
      exitArmed: exitArmed,
    );
  }

  Future<void> _frameAliveHeal() async {
    final at = _castlePoint();
    game.debugRestageOwnEnemy(
      ownId: 'zhaoyun',
      ownAt: at,
      enemyAt: _enemyFar(),
    );
    game.debugSetUnitHp(0, 40);
    game.resumeEngine();
    game.panStart(at);
    game.panEnd(at);
    final hpAtPark = game.debugUnitHp(0);
    await _advance(1);
    await _emit(
      id: 'R4',
      caption: 'R4 返城回血',
      splash: game.debugHitLabel,
      hpMark: hpAtPark,
      reviveMark: 0,
      moraleMark: game.matchMorale,
      ready: false,
      leftCastle: false,
      exitArmed: false,
    );
  }

  Future<void> _emit({
    required String id,
    required String caption,
    required String splash,
    required double hpMark,
    required double reviveMark,
    required int moraleMark,
    required bool ready,
    required bool leftCastle,
    required bool exitArmed,
  }) async {
    game.visualVerifyCaption = caption;
    final shot = RetreatReviveVisualShot(
      id: id,
      caption: caption,
      hold: kRetreatReviveVisualHold,
      life: game.debugUnitLife(0),
      skull: game.debugShowsSkull(0),
      splash: splash,
      hp: game.debugUnitHp(0),
      hpMark: hpMark,
      reviveLeft: game.debugReviveLeft(0),
      reviveMark: reviveMark,
      tip: game.debugLifeTipAt(0),
      morale: game.matchMorale,
      moraleMark: moraleMark,
      ready: ready,
      leftCastle: leftCastle,
      exitArmed: exitArmed,
    );
    // ignore: avoid_print
    print(
      'RETREAT_REVIVE_VISUAL_VERIFY ${shot.pass ? 'PASS' : 'FAIL'} $id '
      'caption="$caption" life=${shot.life.name} skull=${shot.skull} '
      'splash="${shot.splash}" hp=${shot.hp.toStringAsFixed(1)} '
      'hpMark=${shot.hpMark.toStringAsFixed(1)} '
      'revive=${shot.reviveLeft.toStringAsFixed(2)} '
      'mark=${shot.reviveMark.toStringAsFixed(2)} '
      'tip="${shot.tip}" morale=${shot.morale}/${shot.moraleMark} '
      'ready=${shot.ready} left=${shot.leftCastle} armed=${shot.exitArmed} '
      'holdSec=${shot.hold.inMilliseconds / 1000}',
    );
    await hold(shot);
  }

  Future<void> _advance(double seconds) async {
    final frames = (seconds * kRetreatReviveVerifyFps).round();
    for (var i = 0; i < frames; i++) {
      await step();
    }
  }

  Future<bool> _until(bool Function() ok, {int maxSteps = 800}) async {
    for (var i = 0; i < maxSteps; i++) {
      if (ok()) return true;
      await step();
    }
    return ok();
  }

  Offset _outside() {
    final w = game.size.x > 0 ? game.size.x : 390.0;
    final top = game.size.y > 0 ? game.watchH : 120.0;
    final fh = game.size.y > 0 ? game.fieldH : 500.0;
    return Offset(w * 0.42, top + fh * 0.38);
  }

  Offset _castlePoint() {
    final band = game.castleBandRect;
    return Offset(band.center.dx, band.top + band.height * 0.55);
  }

  Offset _enemyFar() {
    final w = game.size.x > 0 ? game.size.x : 390.0;
    final top = game.size.y > 0 ? game.watchH : 120.0;
    return Offset(w * 0.82, top + 40);
  }
}
