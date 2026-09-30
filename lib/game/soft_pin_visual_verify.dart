import 'package:flutter/material.dart';

import 'taisen_game.dart';

/// dart-define: SOFT_PIN_VISUAL_VERIFY=true
/// Free-match place → release → march. Never sets shotPassMode / DEMO_SHOT.
///
/// One release, four holds. Player overlay is 落點釘＋部隊追上
/// (JP カード先・部隊追いつき).
/// 1-mid 落點釘 with 影子行軍 still behind, 4-charge zero cyan,
/// 4-lit SNAP on the troop body, 2-arrive the body coincides with the card.
///
/// flutter run --dart-define=SOFT_PIN_VISUAL_VERIFY=true -d <udid>
const bool kSoftPinVisualVerify = bool.fromEnvironment(
  'SOFT_PIN_VISUAL_VERIFY',
  defaultValue: false,
);

/// How long each prove frame stays put so simctl / Air can grab it.
const Duration kSoftPinVisualHold = Duration(seconds: 4);

class SoftPinVisualShot {
  const SoftPinVisualShot({
    required this.id,
    required this.caption,
    required this.hold,
    required this.travel01,
    required this.aura,
    required this.rings,
    required this.label,
    required this.dragging,
    required this.pinned,
    required this.shadowOpacity,
    required this.pinGap,
    required this.ringOnShadow,
  });

  final String id;
  final String caption;
  final Duration hold;
  final double travel01;
  final bool aura;
  final bool rings;
  final String label;
  final bool dragging;
  final bool pinned;
  final double shadowOpacity;
  final double pinGap;
  final bool ringOnShadow;

  bool get pass {
    switch (id) {
      case '1-mid':
        // ① Released march: 落點釘 ahead, 影子行軍 still catching up.
        return !dragging &&
            pinned &&
            travel01 >= 0.30 &&
            travel01 < 0.60 &&
            !aura &&
            !rings &&
            shadowOpacity > 0.30 &&
            pinGap > 80 &&
            label != '突撃' &&
            !TaisenGame.kMarchShadowFullColor;
      case '4-charge':
        // ④ charging half: 部隊追上 still short of the card, zero cyan.
        return !dragging &&
            pinned &&
            travel01 >= 0.68 &&
            travel01 < 1.0 &&
            !aura &&
            !rings &&
            shadowOpacity > 0.20 &&
            pinGap > 50 &&
            label != '突撃';
      case '4-lit':
        // ④ lit half: SNAP rings on 影子行軍, 落點釘 still ahead.
        return !dragging &&
            pinned &&
            aura &&
            rings &&
            ringOnShadow &&
            pinGap > 36 &&
            label == '氣勢';
      case '2-arrive':
        // ② 部隊追上: card position and troop body coincide.
        return !dragging &&
            !pinned &&
            shadowOpacity == 0 &&
            pinGap < 0.5 &&
            !aura &&
            !rings &&
            travel01 == 0 &&
            label != '突撃';
      default:
        return false;
    }
  }
}

/// Drives ① / ④ / ② on a free-match [TaisenGame] (tutorial stays null).
class SoftPinVisualVerify {
  SoftPinVisualVerify({
    required this.game,
    required this.step,
    required this.hold,
  });

  final TaisenGame game;
  final Future<void> Function() step;
  final Future<void> Function(SoftPinVisualShot shot) hold;

  /// Straight release long enough to light the aura before 部隊追上.
  static const double kReleasePx = 240;

  Future<void> run() async {
    if (game.tutorial != null) {
      // ignore: avoid_print
      print('SOFT_PIN_VISUAL_VERIFY skip tutorial!=null (free match only)');
      return;
    }
    // ignore: avoid_print
    print(
      'SOFT_PIN_VISUAL_VERIFY start free-match '
      'define=SOFT_PIN_VISUAL_VERIFY shotPass=false',
    );
    final sized = await _until(
      () => game.size.x > 1 && game.size.y > 1,
      maxSteps: 180,
    );
    if (!sized) {
      // ignore: avoid_print
      print('SOFT_PIN_VISUAL_VERIFY FAIL no game size');
      return;
    }
    await _releaseAndMarch();
    // ignore: avoid_print
    print('SOFT_PIN_VISUAL_VERIFY done');
  }

  /// panEnd commits the 落點. The body marches; the finger does not stay down.
  Future<void> _releaseAndMarch() async {
    final start = _marchStart();
    final landing = Offset(start.dx + kReleasePx, start.dy);
    game.debugRestageOwnEnemy(
      ownId: 'zhaoyun',
      ownAt: start,
      enemyAt: _enemyFar(),
    );
    game.pauseEngine();
    game.panStart(start);
    game.panEnd(landing);
    if (game.dragging || game.dragTo == null) {
      // ignore: avoid_print
      print(
        'SOFT_PIN_VISUAL_VERIFY FAIL release '
        'dragging=${game.dragging} dragTo=${game.dragTo}',
      );
    }
    game.resumeEngine();

    final mid = await _until(
      () =>
          !game.dragging &&
          game.pinnedMarchAt(0) &&
          game.debugTravel01 >= 0.32 &&
          game.debugTravel01 < 0.58 &&
          !game.auraActive &&
          !game.showChargeCyanRings,
    );
    if (!mid) {
      // ignore: avoid_print
      print('SOFT_PIN_VISUAL_VERIFY FAIL 1-mid never reached');
    }
    final midPct = (game.debugTravel01 * 100).round();
    await _emit('1-mid', '① 落點釘＋部隊追上 $midPct%', kSoftPinVisualHold);

    final charging = await _until(
      () =>
          !game.dragging &&
          game.pinnedMarchAt(0) &&
          game.debugTravel01 >= 0.72 &&
          game.debugTravel01 < 0.98 &&
          !game.auraActive &&
          !game.showChargeCyanRings,
    );
    if (!charging) {
      // ignore: avoid_print
      print('SOFT_PIN_VISUAL_VERIFY FAIL 4-charge never reached');
    }
    final chargePct = (game.debugTravel01 * 100).round();
    await _emit('4-charge', '④ 落點釘＋部隊追上 零青 $chargePct%', kSoftPinVisualHold);

    final lit = await _until(
      () =>
          !game.dragging &&
          game.pinnedMarchAt(0) &&
          game.auraActive &&
          game.showChargeCyanRings &&
          (game.pinnedCardAt(0) - game.shadowAt(0)).distance > 36,
    );
    if (!lit) {
      // ignore: avoid_print
      print('SOFT_PIN_VISUAL_VERIFY FAIL 4-lit never snapped');
    }
    await _emit('4-lit', '④ 部隊追上 SNAP', kSoftPinVisualHold);

    final arrived = await _until(
      () =>
          !game.dragging &&
          game.dragTo == null &&
          !game.pinnedMarchAt(0) &&
          game.marchShadowOpacityAt(0) == 0 &&
          !game.auraActive,
    );
    if (!arrived) {
      // ignore: avoid_print
      print('SOFT_PIN_VISUAL_VERIFY FAIL 2-arrive 部隊未追上');
    }
    await _emit('2-arrive', '② カード先・部隊追いつき', kSoftPinVisualHold);
  }

  Future<void> _emit(String id, String caption, Duration holdFor) async {
    game.visualVerifyCaption = caption;
    final shot = SoftPinVisualShot(
      id: id,
      caption: caption,
      hold: holdFor,
      travel01: game.debugTravel01,
      aura: game.auraActive,
      rings: game.showChargeCyanRings,
      label: game.debugHitLabel,
      dragging: game.dragging,
      pinned: game.pinnedMarchAt(0),
      shadowOpacity: game.marchShadowOpacityAt(0),
      pinGap: (game.pinnedCardAt(0) - game.shadowAt(0)).distance,
      ringOnShadow: (game.chargeRingAnchor(0) - game.shadowAt(0)).distance < 0.5,
    );
    // ignore: avoid_print
    print(
      'SOFT_PIN_VISUAL_VERIFY ${shot.pass ? 'PASS' : 'FAIL'} $id '
      'caption="$caption" travel=${(shot.travel01 * 100).round()}% '
      'aura=${shot.aura} rings=${shot.rings} label="${shot.label}" '
      'dragging=${shot.dragging} pinned=${shot.pinned} '
      'shadow=${shot.shadowOpacity.toStringAsFixed(2)} '
      'pinGap=${shot.pinGap.toStringAsFixed(1)} '
      'ringOnShadow=${shot.ringOnShadow} '
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
    return Offset(w * 0.16, top + fh * 0.48);
  }

  Offset _enemyFar() {
    final w = game.size.x > 0 ? game.size.x : 390.0;
    final top = game.size.y > 0 ? game.watchH : 120.0;
    return Offset(w * 0.78, top + 36);
  }
}
