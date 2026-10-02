import 'package:flutter/material.dart';

import 'c_clock.dart';
import 'fx_windows.dart';
import 'taisen_game.dart';
import 'unit_life.dart';

/// dart-define: TROOP_RETREAT_VISUAL_VERIFY=true
/// Free-match sequence for the five playtest retreat paths. Never sets
/// shotPassMode, DEMO_SHOT, or FEEL_SHOT. Cloud does not run this on a device.
/// Damage numbers stay the existing stubs. The skull keeps the source word
/// (突撃 / 迎擊 / 射 / 亂戰 / 城傷) after the 「撤退」 splash.
///
/// When Air is back:
/// flutter run --dart-define=TROOP_RETREAT_VISUAL_VERIFY=true -d <udid>
///
/// Holds:
/// 1. CAV  lit-aura contact drops more than one second of 亂戰 and stays overlapped
/// 2. CAVK same burst crosses 0 → skull cause 突撃
/// 3. SPEAR tip is not body 亂戰; cavalry on the tip retreats, cause 迎擊
/// 4. BOW  stopped shots reach 撤退 cause 射; march and 亂戰 fire nothing; low HP same power
/// 5. INF  overlap tick only, cause 亂戰, never 突撃
/// 6. SIEGE 亂戰 chip is the low stub; castle band shows 城傷 and can retreat the siege
const bool kTroopRetreatVisualVerify = bool.fromEnvironment(
  'TROOP_RETREAT_VISUAL_VERIFY',
  defaultValue: false,
);

/// How long each prove frame stays put so a later device capture can grab it.
const Duration kTroopRetreatVisualHold = Duration(seconds: 4);

/// Steps per second. Device [step] is a 16ms yield while the engine runs.
/// The cloud test's [step] must call `debugStepPursuit(1/60)`.
const int kTroopRetreatVerifyFps = 60;

class TroopRetreatVisualShot {
  const TroopRetreatVisualShot({
    required this.id,
    required this.caption,
    required this.hold,
    required this.cause,
    required this.label,
    required this.ownLife,
    required this.enemyLife,
    required this.ownHp,
    required this.enemyHp,
    required this.allyRansen,
    required this.enemyRansen,
    required this.dropped,
    required this.movingSilent,
    required this.scrambleSilent,
    required this.lowHpSame,
    required this.chipAlive,
  });

  final String id;
  final String caption;
  final Duration hold;
  final String cause;
  final String label;
  final UnitLife ownLife;
  final UnitLife enemyLife;
  final double ownHp;
  final double enemyHp;
  final bool allyRansen;
  final bool enemyRansen;
  final double dropped;
  final bool movingSilent;
  final bool scrambleSilent;
  final bool lowHpSame;
  final bool chipAlive;

  bool get pass {
    const burst = TaisenGame.kChargeBurstSec * TaisenGame.kRansenTickPerSec;
    const shot = TaisenGame.kBowShotBurstSec * TaisenGame.kRansenTickPerSec;
    switch (id) {
      case 'CAV':
        return label == '突撃' &&
            dropped > TaisenGame.kRansenTickPerSec &&
            (dropped - burst).abs() < 0.25 &&
            enemyLife == UnitLife.alive &&
            enemyHp > 0 &&
            allyRansen &&
            enemyRansen &&
            cause.isEmpty;
      case 'CAVK':
        return cause == '突撃' &&
            label == '撤退' &&
            enemyLife == UnitLife.retreating &&
            enemyHp == 0 &&
            !enemyRansen;
      case 'SPEAR':
        return cause == '迎擊' &&
            label == '撤退' &&
            enemyLife == UnitLife.retreating &&
            enemyHp == 0 &&
            ownLife == UnitLife.alive &&
            !allyRansen &&
            !enemyRansen;
      case 'BOW':
        return cause == '射' &&
            label == '撤退' &&
            enemyLife == UnitLife.retreating &&
            enemyHp == 0 &&
            movingSilent &&
            scrambleSilent &&
            lowHpSame &&
            (dropped - shot).abs() < 0.05 &&
            ownHp == 8;
      case 'INF':
        return cause == '亂戰' &&
            label == '撤退' &&
            label != '突撃' &&
            enemyLife == UnitLife.retreating &&
            enemyHp == 0 &&
            ownLife == UnitLife.alive;
      case 'SIEGE':
        return dropped > 0 &&
            dropped < TaisenGame.kRansenTickPerSec * 0.5 &&
            chipAlive &&
            cause == '城傷' &&
            (ownLife == UnitLife.retreating || ownLife == UnitLife.inCastleReviving) &&
            ownHp == 0 &&
            enemyHp == TaisenGame.kRansenMaxHp &&
            label == '撤退';
      default:
        return false;
    }
  }
}

/// Drives the five troop paths on a free-match [TaisenGame] (tutorial stays null).
class TroopRetreatVisualVerify {
  TroopRetreatVisualVerify({
    required this.game,
    required this.step,
    required this.hold,
  });

  final TaisenGame game;
  final Future<void> Function() step;
  final Future<void> Function(TroopRetreatVisualShot shot) hold;

  Future<void> run() async {
    if (game.tutorial != null) {
      // ignore: avoid_print
      print('TROOP_RETREAT_VISUAL_VERIFY skip tutorial!=null (free match only)');
      return;
    }
    // ignore: avoid_print
    print(
      'TROOP_RETREAT_VISUAL_VERIFY start free-match '
      'define=TROOP_RETREAT_VISUAL_VERIFY shotPass=false '
      'playtest tick=${TaisenGame.kRansenTickPerSec} '
      'chargeBurst=${TaisenGame.kChargeBurstSec} '
      'bowShot=${TaisenGame.kBowShotBurstSec} '
      'siegeMul=${TaisenGame.kSiegeRansenMul}',
    );
    final sized = await _until(() => game.size.x > 1 && game.size.y > 1);
    if (!sized) {
      // ignore: avoid_print
      print('TROOP_RETREAT_VISUAL_VERIFY FAIL no game size');
      return;
    }
    await _frameCavalryDrop();
    await _frameCavalryKill();
    await _frameSpear();
    await _frameBow();
    await _frameInfantry();
    await _frameSiege();
    // ignore: avoid_print
    print('TROOP_RETREAT_VISUAL_VERIFY done');
  }

  Future<void> _frameCavalryDrop() async {
    await _armAura('zhaoyun');
    final before = game.debugUnitHp(1);
    game.dragTo = null;
    game.fieldPos[1] = game.fieldPos[0];
    await step();
    await _emit(
      id: 'CAV',
      caption: 'CAV 突撃 > 亂戰',
      causeIndex: 1,
      dropped: before - game.debugUnitHp(1),
    );
  }

  Future<void> _frameCavalryKill() async {
    await _armAura('zhaoyun');
    game.dragTo = null;
    game.debugSetUnitHp(1, TaisenGame.kChargeBurstSec * TaisenGame.kRansenTickPerSec);
    game.fieldPos[1] = game.fieldPos[0];
    await step();
    await _emit(id: 'CAVK', caption: 'CAVK 突撃撤退', causeIndex: 1);
  }

  Future<void> _frameSpear() async {
    final at = _mid();
    game.debugRestageOwnEnemy(ownId: 'zhangfei', ownAt: at, enemyAt: at);
    game.fieldPos[1] = game.spearTipAt(0);
    await step();
    await _emit(id: 'SPEAR', caption: 'SPEAR 迎擊', causeIndex: 1);
  }

  Future<void> _frameBow() async {
    final movingSilent = await _bowMovingSilent();
    final scrambleSilent = await _bowScrambleSilent();
    await _place('sunquan', _mid(), _mid() + const Offset(180, 0));
    final first = await _bowShot();
    game.debugSetUnitHp(1, TaisenGame.kRansenMaxHp);
    game.debugSetUnitHp(0, 8);
    final second = await _bowShot();
    final lowHpSame = first > 0 && (first - second).abs() < 0.001 && game.debugUnitHp(0) == 8;
    game.debugSetUnitHp(1, first);
    await _bowShot();
    await _emit(
      id: 'BOW',
      caption: 'BOW 射撤退',
      causeIndex: 1,
      dropped: first,
      movingSilent: movingSilent,
      scrambleSilent: scrambleSilent,
      lowHpSame: lowHpSame,
    );
  }

  Future<void> _frameInfantry() async {
    await _place('zhangliang', _mid(), _mid());
    game.debugSetUnitHp(1, TaisenGame.kRansenTickPerSec * 0.5);
    await _advance(1);
    await _emit(id: 'INF', caption: 'INF 亂戰', causeIndex: 1);
  }

  Future<void> _frameSiege() async {
    final at = _mid();
    await _place('chenlan', at, at);
    final before = game.debugUnitHp(1);
    await _advance(1);
    final scrambleDealt = before - game.debugUnitHp(1);

    final band = game.castleBandRect;
    final siegeAt = Offset(band.left + 64, band.top + band.height * 0.55);
    final enemyAt = Offset(band.right - 64, siegeAt.dy);
    await _place('chenlan', siegeAt, enemyAt);
    var chipAlive = false;
    for (var i = 0; i < 5; i++) {
      await step();
      if (game.debugCastleChipAt(0) && game.debugUnitLife(0) == UnitLife.alive) {
        chipAlive = true;
        break;
      }
    }
    game.debugSetUnitHp(0, 0.05);
    await step();
    await _emit(
      id: 'SIEGE',
      caption: 'SIEGE 城傷',
      causeIndex: 0,
      dropped: scrambleDealt,
      chipAlive: chipAlive,
    );
  }

  Future<void> _armAura(String ownId) async {
    final start = _marchStart();
    game.debugRestageOwnEnemy(ownId: ownId, ownAt: start, enemyAt: _enemyFar());
    game.resumeEngine();
    game.panStart(start);
    game.panEnd(Offset(start.dx + 260, start.dy));
    final lit = await _until(() => game.auraActive && game.dragTo != null);
    if (!lit) {
      // ignore: avoid_print
      print('TROOP_RETREAT_VISUAL_VERIFY FAIL aura never lit');
    }
  }

  Future<bool> _bowMovingSilent() async {
    final from = _mid();
    await _place('sunquan', from, from + const Offset(180, 0));
    game.selectOrDetailAt(from);
    await _advance(_bowWindupSec);
    game.panStart(from);
    game.panEnd(from + const Offset(140, 0));
    game.selectOrDetailAt(from);
    return game.debugUnitHp(1) == TaisenGame.kRansenMaxHp && game.debugRetreatCause(1).isEmpty;
  }

  Future<bool> _bowScrambleSilent() async {
    final at = _mid();
    await _place('sunquan', at, at + const Offset(180, 0));
    game.selectOrDetailAt(at);
    await _advance(_bowWindupSec);
    game.fieldPos[1] = game.fieldPos[0];
    await step();
    final dropped = TaisenGame.kRansenMaxHp - game.debugUnitHp(1);
    return dropped < 1 && !game.debugBowWinding;
  }

  Future<double> _bowShot() async {
    final at = game.tokenCenter(0);
    final before = game.debugUnitHp(1);
    game.selectOrDetailAt(at);
    await _advance(_bowWindupSec);
    game.selectOrDetailAt(at);
    return before - game.debugUnitHp(1);
  }

  double get _bowWindupSec => CClock.secondsPerC * FxWindows.bowStopBeforeShotC + 0.05;

  Future<void> _place(String ownId, Offset ownAt, Offset enemyAt) async {
    game.debugRestageOwnEnemy(ownId: ownId, ownAt: ownAt, enemyAt: enemyAt);
  }

  Future<void> _emit({
    required String id,
    required String caption,
    required int causeIndex,
    double dropped = 0,
    bool movingSilent = false,
    bool scrambleSilent = false,
    bool lowHpSame = false,
    bool chipAlive = false,
  }) async {
    game.visualVerifyCaption = caption;
    final shot = TroopRetreatVisualShot(
      id: id,
      caption: caption,
      hold: kTroopRetreatVisualHold,
      cause: game.debugRetreatCause(causeIndex),
      label: game.debugHitLabel,
      ownLife: game.debugUnitLife(0),
      enemyLife: game.debugUnitLife(1),
      ownHp: game.debugUnitHp(0),
      enemyHp: game.debugUnitHp(1),
      allyRansen: game.debugInRansen(0),
      enemyRansen: game.field.length > 1 && game.debugInRansen(1),
      dropped: dropped,
      movingSilent: movingSilent,
      scrambleSilent: scrambleSilent,
      lowHpSame: lowHpSame,
      chipAlive: chipAlive,
    );
    // ignore: avoid_print
    print(
      'TROOP_RETREAT_VISUAL_VERIFY ${shot.pass ? 'PASS' : 'FAIL'} $id '
      'caption="$caption" cause="${shot.cause}" label="${shot.label}" '
      'life=${shot.ownLife.name}/${shot.enemyLife.name} '
      'hp=${shot.ownHp.toStringAsFixed(1)}/${shot.enemyHp.toStringAsFixed(1)} '
      'ransen=${shot.allyRansen}/${shot.enemyRansen} '
      'dropped=${shot.dropped.toStringAsFixed(2)} '
      'moveSilent=${shot.movingSilent} scrambleSilent=${shot.scrambleSilent} '
      'lowHpSame=${shot.lowHpSame} chipAlive=${shot.chipAlive}',
    );
    await hold(shot);
  }

  Future<void> _advance(double seconds) async {
    final frames = (seconds * kTroopRetreatVerifyFps).round();
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

  Offset _marchStart() {
    final w = game.size.x > 0 ? game.size.x : 390.0;
    final top = game.size.y > 0 ? game.watchH : 120.0;
    final fh = game.size.y > 0 ? game.fieldH : 500.0;
    return Offset(w * 0.18, top + fh * 0.42);
  }

  Offset _mid() {
    final w = game.size.x > 0 ? game.size.x : 390.0;
    final top = game.size.y > 0 ? game.watchH : 120.0;
    final fh = game.size.y > 0 ? game.fieldH : 500.0;
    return Offset(w * 0.42, top + fh * 0.42);
  }

  Offset _enemyFar() {
    final w = game.size.x > 0 ? game.size.x : 390.0;
    final top = game.size.y > 0 ? game.watchH : 120.0;
    return Offset(w * 0.82, top + 40);
  }
}
