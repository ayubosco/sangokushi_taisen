import 'package:flutter/material.dart';

import 'taisen_game.dart';

/// dart-define: RANSEN_VISUAL_VERIFY=true
/// Free-match auto sequence for live field frames. Never sets shotPassMode.
///
/// flutter run --dart-define=RANSEN_VISUAL_VERIFY=true -d <udid>
const bool kRansenVisualVerify = bool.fromEnvironment(
  'RANSEN_VISUAL_VERIFY',
  defaultValue: false,
);

/// How long each prove frame stays put so simctl can screenshot it.
const Duration kRansenVisualHold = Duration(seconds: 4);

/// Shorter hold on the 突撃 flash itself (then the cleared 亂戰 frame).
const Duration kRansenVisualChargeHold = Duration(milliseconds: 2500);

class RansenVisualShot {
  const RansenVisualShot({
    required this.id,
    required this.caption,
    required this.hold,
    required this.travel01,
    required this.aura,
    required this.rings,
    required this.label,
    required this.allyRansen,
    required this.enemyRansen,
    required this.allyHp,
    required this.enemyHp,
  });

  final String id;
  final String caption;
  final Duration hold;
  final double travel01;
  final bool aura;
  final bool rings;
  final String label;
  final bool allyRansen;
  final bool enemyRansen;
  final double allyHp;
  final double enemyHp;

  bool get pass {
    switch (id) {
      case 'A':
        return travel01 >= 0.30 &&
            travel01 < 0.85 &&
            !aura &&
            !rings &&
            label != '突撃' &&
            !allyRansen;
      case 'B':
        return allyRansen &&
            enemyRansen &&
            !aura &&
            !rings &&
            label != '突撃' &&
            allyHp < TaisenGame.kRansenMaxHp &&
            enemyHp < TaisenGame.kRansenMaxHp;
      case 'C1':
        return label == '突撃' && allyRansen && enemyRansen && !aura && travel01 == 0;
      case 'C':
        return label != '突撃' &&
            label.isEmpty &&
            allyRansen &&
            enemyRansen &&
            !aura &&
            travel01 == 0;
      case 'D':
        return !allyRansen && !enemyRansen && label != '突撃';
      default:
        return false;
    }
  }
}

/// Drives frames A–D on a free-match [TaisenGame] (tutorial stays null).
class RansenVisualVerify {
  RansenVisualVerify({
    required this.game,
    required this.step,
    required this.hold,
  });

  final TaisenGame game;
  final Future<void> Function() step;
  final Future<void> Function(RansenVisualShot shot) hold;

  Future<void> run() async {
    if (game.tutorial != null) {
      // ignore: avoid_print
      print('RANSEN_VISUAL_VERIFY skip tutorial!=null (free match only)');
      return;
    }
    // ignore: avoid_print
    print(
      'RANSEN_VISUAL_VERIFY start free-match '
      'define=RANSEN_VISUAL_VERIFY shotPass=false',
    );
    final sized = await _until(
      () => game.size.x > 1 && game.size.y > 1,
      maxSteps: 180,
    );
    if (!sized) {
      // ignore: avoid_print
      print('RANSEN_VISUAL_VERIFY FAIL no game size');
      return;
    }
    await _frameKeepMeter();
    await _frameNoAuraRansen();
    await _frameAuraThenRansen();
    await _frameLeaveRansen();
    // ignore: avoid_print
    print('RANSEN_VISUAL_VERIFY done');
  }

  Future<void> _frameKeepMeter() async {
    final start = _marchStart();
    final landing = Offset(start.dx + 220, start.dy);
    game.debugRestageOwnEnemy(
      ownId: 'zhaoyun',
      ownAt: start,
      enemyAt: _enemyFar(),
    );
    game.pauseEngine();
    game.panStart(start);
    game.panEnd(landing);
    game.resumeEngine();

    final mid = await _until(
      () => game.debugTravel01 >= 0.40 && !game.auraActive && game.dragTo != null,
    );
    game.pauseEngine();
    if (!mid) {
      // ignore: avoid_print
      print('RANSEN_VISUAL_VERIFY FAIL A never reached mid travel');
    }
    final body = game.tokenCenter(0);
    // Gentle retarget, same general heading. Lock A must keep this percent.
    final ahead = Offset(body.dx + 150, body.dy - 12);
    game.panStart(body);
    game.panUpdate(ahead);
    game.panEnd(ahead);
    final pct = (game.debugTravel01 * 100).round();
    await _emit(
      'A',
      'A KEEP $pct%',
      kRansenVisualHold,
    );
  }

  Future<void> _frameNoAuraRansen() async {
    final at = _midField();
    game.debugRestageOwnEnemy(
      ownId: 'zhangliang',
      ownAt: at,
      enemyAt: at,
    );
    game.resumeEngine();
    await _until(() => game.debugInRansen(0) && game.debugInRansen(1));
    // Existing tick knob only — long enough that the HP chip is visibly short.
    for (var i = 0; i < 90; i++) {
      await step();
    }
    final hp = game.debugUnitHp(0).round();
    await _emit(
      'B',
      'B 亂戰 HP $hp no 突撃',
      kRansenVisualHold,
    );
  }

  Future<void> _frameAuraThenRansen() async {
    final start = _marchStart();
    game.debugRestageOwnEnemy(
      ownId: 'zhaoyun',
      ownAt: start,
      enemyAt: _enemyFar(),
    );
    game.pauseEngine();
    game.panStart(start);
    game.panEnd(Offset(start.dx + 260, start.dy));
    game.resumeEngine();
    final lit = await _until(() => game.auraActive && game.dragTo != null);
    game.pauseEngine();
    if (!lit) {
      // ignore: avoid_print
      print('RANSEN_VISUAL_VERIFY FAIL C aura never lit');
    }
    game.dragTo = null;
    game.fieldPos[1] = game.fieldPos[0];
    game.resumeEngine();
    await _until(
      () => game.debugHitLabel == '突撃' && game.debugInRansen(0) && !game.auraActive,
    );
    await _emit('C1', 'C1 突撃', kRansenVisualChargeHold);
    game.resumeEngine();
    await _until(
      () => game.debugHitLabel.isEmpty && game.debugInRansen(0) && !game.auraActive,
    );
    await _emit('C', 'C 亂戰 after 突撃', kRansenVisualHold);
  }

  Future<void> _frameLeaveRansen() async {
    final body = game.tokenCenter(0);
    final away = Offset(body.dx + 220, body.dy);
    game.pauseEngine();
    game.panStart(body);
    game.panEnd(away);
    game.resumeEngine();
    await _until(() => !game.debugInRansen(0) && !game.debugInRansen(1));
    await _emit('D', 'D 亂戰 gone', kRansenVisualHold);
  }

  Future<void> _emit(String id, String caption, Duration holdFor) async {
    game.visualVerifyCaption = caption;
    final shot = RansenVisualShot(
      id: id,
      caption: caption,
      hold: holdFor,
      travel01: game.debugTravel01,
      aura: game.auraActive,
      rings: game.showChargeCyanRings,
      label: game.debugHitLabel,
      allyRansen: game.debugInRansen(0),
      enemyRansen: game.field.length > 1 && game.debugInRansen(1),
      allyHp: game.debugUnitHp(0),
      enemyHp: game.debugUnitHp(1),
    );
    // ignore: avoid_print
    print(
      'RANSEN_VISUAL_VERIFY ${shot.pass ? 'PASS' : 'FAIL'} $id '
      'caption="$caption" travel=${(shot.travel01 * 100).round()}% '
      'aura=${shot.aura} rings=${shot.rings} label="${shot.label}" '
      'ransen=${shot.allyRansen}/${shot.enemyRansen} '
      'hp=${shot.allyHp.round()}/${shot.enemyHp.round()} '
      'holdSec=${holdFor.inMilliseconds / 1000}',
    );
    await hold(shot);
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

  Offset _midField() {
    final start = _marchStart();
    return Offset(start.dx + 40, start.dy);
  }

  Offset _enemyFar() {
    final w = game.size.x > 0 ? game.size.x : 390.0;
    final top = game.size.y > 0 ? game.watchH : 120.0;
    return Offset(w * 0.78, top + 36);
  }
}
