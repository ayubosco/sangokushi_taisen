import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/card_models.dart';
import 'c_clock.dart';
import 'faction_colors.dart';
import 'fx_windows.dart';
import 'troop_sprite_anims.dart';
import 'tutorial_controller.dart';

enum AWindowKind { charge, intercept, bow, stratagem }

/// Offline 1v1 CPU stub — short watch (read-only) + large flat 2D field.
/// Design B: Watch ≤15% of the game band; draggable field is the hero.
/// 3D/perspective ONLY in watch; playfield = gold-border tokens / weapon corners / flat FX.
class TaisenGame extends FlameGame {
  TaisenGame({this.tutorial});

  final TutorialController? tutorial;

  final CClock clock = CClock();
  static const int fieldMax = 5;
  static const double costCap = 6;

  /// A-window debug labels (突撃オーラ / 迎擊槍尖 / 弓停射 / 計略≤1C). Default off.
  static const bool showAWindowDebugLabels = false;

  final List<CardFace> field = [];
  final List<Offset> fieldPos = [];
  /// Parallel to [field]: true = enemy token on lower field (dark outline).
  final List<bool> fieldIsEnemy = [];
  /// Parallel to [field]: own token parked in bottom 己城 band (返城 / heal-redeploy).
  final List<bool> fieldInCastle = [];
  int? selectedIndex;

  /// Drag hover: pointer currently inside own-castle band (highlight).
  bool castleBandHot = false;

  /// Cosmetic castle race fills (0–1). No combat damage numbers invented.
  double ownCastle = 0.78;
  double enemyCastle = 0.64;
  double _shakeLeft = 0;
  /// Shot mode: keep 返城 float visible.
  bool holdReturnFlash = false;

  /// Design assets: weapon corner atlas + lacquer field swatch + 5:8 token art.
  ui.Image? _weaponSheet;
  ui.Image? _fieldLacquer;
  ui.Image? _tokenCards58;
  ui.Image? _tokenSpear58;
  ui.Image? _tokenDao58;
  ui.Image? _tokenBow58;
  /// Flame SpriteAnimation bank (spear/dao/bow/cavalry sheets).
  final TroopSpriteBank troopSprites = TroopSpriteBank();
  /// Shot / debug: force SpriteAnimation pose on [debugForcePoseIndex] (FEEL sheets).
  TroopAnimPose? debugForcePose;
  int? debugForcePoseIndex;

  /// Tutorial token roles (indices into [field]).
  int? tutorialOwnIndex;
  int? tutorialEnemyIndex;
  int? tutorialDropGuideIndex;

  /// Drag state (field-local coords).
  /// Finger-up COMMITS [dragTo]. The full-color card pins on that gold 落點.
  /// [fieldPos] is the translucent shadow, which keeps marching until 合體.
  /// [dragging] only means the finger is still moving the waypoint.
  /// Never teleport the shadow onto the finger.
  bool dragging = false;
  Offset? dragFrom;
  Offset? dragTo;
  /// Continuous walked distance while steering — charge aura accumulates from this.
  double _dragTravelDist = 0;
  /// Last move dir while dragging — sharp turn fades aura like stop.
  Offset? _lastDragDir;
  static const double kChargeTravelNeed = 120.0; // px of walked travel to fill charge aura
  /// Travel fraction that counts as "蓄緊 / charging" (gold guide + percent — ZERO cyan).
  /// Rings do NOT use this; cyan exists only while [auraActive].
  static const double kChargeRingShowTravel01 = 0.04;
  /// Fully lit (auraActive): exaggerated cyan-white punch. Charging never reuses this.
  static const double kChargeRingLitAlphaMin = 0.88;
  static const double kChargeRingLitStroke = 7.0;
  /// 「突撃」 flash duration seconds (non-blocking, hard-cap ≤1.0s).
  static const double kChargeFlashSec = 0.85;
  /// 「氣勢」 snap flash when aura flips true (short, never 「突撃」).
  static const double kKiseiFlashSec = 0.55;
  double get debugTravel01 => (_dragTravelDist / kChargeTravelNeed).clamp(0.0, 1.0);
  /// Cyan-white charge aura fully armed (travel ownership) — charge FX requires this at contact.
  bool get auraActive {
    final travel01 = (_dragTravelDist / kChargeTravelNeed).clamp(0.0, 1.0);
    if (travel01 >= 1.0) return true;
    final t = tutorial;
    if (t != null && t.session == TutorialSession.session1 && t.auraReady) return true;
    if (t == null && _matchChargeIndex != null && _matchChargeC >= 1.0) return true;
    return false;
  }
  /// BINARY playfeel: field + Watch draw cyan rings only while [auraActive].
  bool get showChargeCyanRings => auraActive;
  String get debugHitLabel => _hitFlashLabel;
  /// off / charging (!aura, travel mid) / lit — CHARGE_AUTO_VERIFY mid vs lit proof.
  String get debugChargeFeel {
    if (auraActive) return 'lit';
    if (debugTravel01 > kChargeRingShowTravel01) return 'charging';
    return 'off';
  }
  bool debugInRansen(int i) => _ransenUnits.contains(i);
  double debugUnitHp(int i) =>
      (i >= 0 && i < _unitHp.length) ? _unitHp[i] : kRansenMaxHp;
  bool get debugBowWinding => _bowWindupIndex != null && !_bowDidShoot;
  /// Live prove overlay. Null in normal play. Not a shot freeze.
  String? visualVerifyCaption;

  /// Spear tip glow is on unless that spear is inside 亂戰 (tip retracts).
  bool spearTipExtendedAt(int i) {
    if (i < 0 || i >= field.length) return false;
    if (field[i].troop != TroopType.spear) return false;
    if (_ransenUnits.contains(i)) return false;
    return true;
  }
  /// px between body and gold landing. Mid-drag must stay large (no 1:1 glue).
  double get debugWaypointLagPx {
    if (dragTo == null || selectedIndex == null || selectedIndex! >= fieldPos.length) {
      return 0;
    }
    return (fieldPos[selectedIndex!] - dragTo!).distance;
  }

  /// Combat states (Research/UIUX/Design lock):
  /// MARCH = not touching → zero hit FX; MELEE = contact w/o aura → light bump only;
  /// CHARGE = auraActive && real contact → flash + 「突撃」.
  /// Engagement = token overlap / enter melee — NOT loose proximity-near.
  double get meleeContactDist {
    final sz = tokenCardSize;
    // Half-widths along short+long blended — visual card touch, tighter than old 58px near.
    return (sz.width + sz.height) * 0.38;
  }

  bool inMeleeContact(Offset a, Offset b) => (a - b).distance <= meleeContactDist;

  /// Edge-trigger: which enemy we are currently overlapping (null = MARCH).
  int? _meleeEnemyIndex;
  /// After CHARGE resolves, suppress repeat until leave contact.
  bool _chargeResolvedThisContact = false;
  /// Edge-trigger for 「氣勢」 snap when [auraActive] flips false→true.
  bool _prevAuraActive = false;

  /// Bodies currently in 亂戰 (ally↔enemy hitbox overlap). Exits when overlap ends.
  final Set<int> _ransenUnits = {};
  /// Playtest HP stub. Mutual ticks use [kRansenTickPerSec] — not a locked wiki DPS.
  final List<double> _unitHp = [];

  /// Playtest knob: HP each overlapping body loses per second while in 亂戰.
  static const double kRansenTickPerSec = 6.0;
  static const double kRansenMaxHp = 100.0;
  /// Still able to drag out. Slightly slower than a free march.
  static const double kRansenSpeedScale = 0.75;

  /// Session2 facing: radians; 0 = up (toward enemy).
  double ownFacing = 0;
  double enemyFacing = math.pi;

  /// Enemy-watch telegraph demo cycle (no combat numbers).
  AWindowKind watchKind = AWindowKind.charge;
  double _watchPhaseLeft = FxWindows.toSeconds(FxWindows.chargeAuraVisibleC);
  double _pulse = 0;

  /// Stratagem burst on field (≤1C, non-blocking).
  double _stratLeft = 0;
  Offset? _stratAt;

  /// Optional intercept / charge hit flash on a field token.
  int? _hitFlashIndex;
  double _hitFlashLeft = 0;
  String _hitFlashLabel = '';

  /// 歸城 flash
  double _returnFlashLeft = 0;

  /// Free-match cavalry: after drag-drop, wait aura ≥1C before 突撃 hit (visual only).
  int? _matchChargeIndex;
  double _matchChargeC = 0;

  /// Free-match bow: still windup ~1C; moving cancels; first shot only after ready.
  int? _bowWindupIndex;
  double _bowWindupC = 0;
  bool _bowShotReady = false;
  bool _bowDidShoot = false;
  bool _verifyLoggedAura = false;
  bool _verifyLoggedTurn = false;
  bool _verifyLoggedBowReady = false;

  /// Free-match enemy charge aura (for spear intercept practice) — visual only.
  int? _matchEnemyChargeIndex;
  double _matchEnemyChargeC = 0;

  /// Free-match intercept: turn window after enemy aura ≥1C.
  bool _matchTurnWindowOpen = false;
  bool _matchFacingCorrect = false;
  int? _matchSpearIndex;

  void Function(CardFace card)? onRequestDetail;
  VoidCallback? onTutorialChanged;

  @override
  Color backgroundColor() => FactionColors.lacquer;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.anchor = Anchor.topLeft;
    // Preserve pause: reset() sets running=true; FEEL/TutorialShell may already have paused.
    final wasRunning = clock.running;
    clock.reset();
    if (!wasRunning) clock.pause();
    _weaponSheet = await _loadUiImage('assets/ui/token-weapons-sheet.png');
    _fieldLacquer = await _loadUiImage('assets/field/field-lacquer-swatch.png');
    _tokenCards58 = await _loadUiImage('assets/ui/token-cards-58-moodboard.png');
    _tokenSpear58 = await _loadUiImage('assets/ui/token-card-spear-58.png');
    _tokenDao58 = await _loadUiImage('assets/ui/token-card-dao-58.png');
    _tokenBow58 = await _loadUiImage('assets/ui/token-card-bow-58.png');
    await troopSprites.loadAll();
  }

  Future<ui.Image> _loadUiImage(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  /// Design B: watch fraction of [GameWidget] height.
  /// HUD (~36px) + 計略 bar (~62px) sit outside this widget. At 0.15 of the
  /// game band, Watch is ≤15% of a phone screen and the drag field stays ≥62%.
  static const double kWatchFractionOfGame = 0.15;

  /// Field shadow while the full-color card is pinned on 落點. Not full opacity.
  static const double kMarchShadowOpacity = 0.38;

  /// Castle strip height inside the game band (~3–4% screen after shell chrome).
  static const double kCastleStripPx = 22.0;

  double get watchH => size.y * kWatchFractionOfGame;

  /// Flat operable field below watch (excludes watch; castle sits on divider).
  double get fieldH => (size.y - watchH).clamp(0.0, double.infinity);

  /// Own-castle bottom band ≈12% of drag field (Bosco: 10–14%).
  static const double kCastleBandFracOfField = 0.12;

  /// Real-card 54×86 ≈ 5:8. Short-side (width) as fraction of field width (UIUX gate 0.10–0.11, max 0.12).
  static const double kTokenWidthFracOfField = 0.10; // Bosco eye: still too big at 0.12; try 0.10
  static const double kTokenAspectWH = 5 / 8; // W/H

  double get castleBandH => fieldH * kCastleBandFracOfField;

  Rect get castleBandRect {
    final h = size.y;
    final bh = castleBandH;
    return Rect.fromLTWH(0, h - bh, size.x, bh);
  }

  bool inCastleBand(Offset p) => castleBandRect.contains(p);

  /// Field token art size (5:8). Hit target may be larger (≥48dp).
  Size get tokenCardSize {
    final w = size.x * kTokenWidthFracOfField;
    return Size(w, w / kTokenAspectWH);
  }

  double get tokenHitR {
    final s = tokenCardSize;
    // Transparent hit ≥48dp diameter — may exceed smaller 0.10 art.
    final halfDiag = 0.5 * math.sqrt(s.width * s.width + s.height * s.height);
    return math.max(halfDiag + 4, 24.0);
  }

  /// Debug metrics for H0 gate (printed once when size known).
  bool _loggedH0Metrics = false;

  void _maybeLogH0Metrics() {
    if (_loggedH0Metrics || size.y <= 0 || size.x <= 0) return;
    _loggedH0Metrics = true;
    final wh = watchH;
    final fh = fieldH;
    final tw = size.x * kTokenWidthFracOfField;
    // ignore: avoid_print
    print(
      'H0_MEASURE gameW=${size.x.toStringAsFixed(1)} gameH=${size.y.toStringAsFixed(1)} '
      'watchH=${wh.toStringAsFixed(1)} fieldH=${fh.toStringAsFixed(1)} '
      'watch/game=${(wh / size.y).toStringAsFixed(3)} field/game=${(fh / size.y).toStringAsFixed(3)} '
      'dragAspect=${(size.x / fh).toStringAsFixed(3)} '
      'tokenW=${tw.toStringAsFixed(1)} tokenW/fieldW=${(tw / size.x).toStringAsFixed(3)} '
      'tokenAspect=${kTokenAspectWH.toStringAsFixed(3)} castleBand/field=${kCastleBandFracOfField.toStringAsFixed(2)}',
    );
  }

  /// Cavalry base march in field-widths per second (wiki 騎 1.1).
  /// Half the operable field depth (fieldH/2) on the 390×844 reference is ~2.57s,
  /// including the 1.32 aura after [kChargeTravelNeed] px (band 1.5–3.0s). Aura stays
  /// travel-distance gated — this scale does not turn it into a wall clock.
  /// 0.62·W glued onto a normal drag (Bosco teleport Fail); do not raise this
  /// without re-measuring that half-field run.
  static const double kCavalryPursuitWidthsPerSec = 0.32;

  /// Body rests on the waypoint once it is this close, then [dragTo] clears.
  static const double kArrivalEpsilon = 2.0;

  /// 天 wiki base speeds — https://w.atwiki.jp/taisendsten/pages/119.html
  /// 騎 1.1, 歩 0.9, 弓 0.8, 槍 0.7, 攻城 0.5. Not the oral order 騎>弓>歩＝槍.
  /// Bow 走射 0.96 is not a waypoint state (stop-then-shot stays 0.8 while marching).
  static double pursuitWikiBase(TroopType troop) {
    return switch (troop) {
      TroopType.cavalry => 1.1,
      TroopType.infantry => 0.9,
      TroopType.bow => 0.8,
      TroopType.spear => 0.7,
      TroopType.siege => 0.5,
    };
  }

  /// Wiki 限界速度. Base march and the cavalry aura 1.32 sit under these.
  static double pursuitWikiCap(TroopType troop) {
    return switch (troop) {
      TroopType.cavalry => 3.3,
      TroopType.infantry => 2.7,
      TroopType.bow => 2.4,
      TroopType.spear => 2.1,
      TroopType.siege => 2.0,
    };
  }

  /// 騎 base 1.1 × 1.2 while the charge aura is on. Locked value, not a derived guess.
  static const double kCavalryAuraSpeed = 1.32;

  /// px/s toward the gold landing. Wiki base, cavalry → 1.32 only while [auraActive].
  double _troopSpeedPx(TroopType troop) {
    var wiki = pursuitWikiBase(troop);
    if (troop == TroopType.cavalry && auraActive) {
      wiki = kCavalryAuraSpeed;
    }
    final cap = pursuitWikiCap(troop);
    if (wiki > cap) wiki = cap;
    final w = size.x > 0 ? size.x : 390.0;
    return w * kCavalryPursuitWidthsPerSec * (wiki / pursuitWikiBase(TroopType.cavalry));
  }

  /// Hard cap so a dt hitch cannot consume the whole waypoint in one frame.
  static const double kPursuitMinFps = 24.0;

  Offset _clampFieldPos(Offset p) {
    final minY = watchH + 36;
    final maxY = size.y > 0 ? size.y - 16 : minY + 400;
    final maxX = size.x > 0 ? size.x - 36 : 360.0;
    return Offset(p.dx.clamp(36.0, maxX), p.dy.clamp(minY, maxY));
  }

  /// Facing 0 = up (−Y). Movement (dx,dy) → atan2(dx, −dy).
  double _facingFromDelta(Offset delta) {
    if (delta.distance < 0.5) return ownFacing;
    return math.atan2(delta.dx, -delta.dy);
  }

  /// Speed-limited walk toward [dragTo]. Never assigns body = finger.
  /// Marches while a waypoint is committed ([dragTo] != null), including after
  /// finger-up. [dragging] only means the finger is still moving that waypoint.
  /// Returns true if the unit actually stepped this tick.
  bool _pursueWaypoint(double dt) {
    if (selectedIndex == null || dragTo == null) return false;
    final i = selectedIndex!;
    if (i >= fieldPos.length || isEnemyAt(i)) return false;
    final pos = fieldPos[i];
    final target = dragTo!;
    final delta = target - pos;
    final dist = delta.distance;
    if (dist <= kArrivalEpsilon) {
      _completeMarch(i, _clampFieldPos(target));
      return false;
    }
    final coach = tutorial;
    var speed = _troopSpeedPx(field[i].troop);
    if (_ransenUnits.contains(i)) speed *= kRansenSpeedScale;
    final dtCap = speed / kPursuitMinFps;
    final step = math.min(dist, math.min(speed * dt, dtCap));
    final dir = Offset(delta.dx / dist, delta.dy / dist);
    if (_lastDragDir != null) {
      final dot = (_lastDragDir!.dx * dir.dx + _lastDragDir!.dy * dir.dy).clamp(-1.0, 1.0);
      final ang = math.acos(dot);
      // ~70° still drops the meter. Retarget alone does not — panStart keeps it.
      if (ang > 1.22) {
        _dragTravelDist = 0;
        if (coach != null && coach.session == TutorialSession.session1) {
          coach.auraReady = false;
          if (coach.s1 == S1Phase.hitCharge || coach.s1 == S1Phase.waitAura) {
            coach.s1 = S1Phase.dragGuide;
          }
        } else if (coach == null) {
          _matchChargeIndex = null;
          _matchChargeC = 0;
        }
      }
    }
    _lastDragDir = dir;
    final next = _clampFieldPos(pos + dir * step);
    final walked = (next - pos).distance;
    // Clamp ate the step (waypoint off the board): rest where the body already is.
    if (dt > 0 && walked < 0.01) {
      _completeMarch(i, pos);
      return false;
    }
    fieldPos[i] = next;
    // 亂戰: cavalry must not build or keep filling aura while bodies overlap.
    // Contact resolution itself runs in [_tickRansen], once per frame.
    final scrambled = _ransenUnits.contains(i);
    if (!scrambled) {
      _dragTravelDist += walked;
    }
    ownFacing = _facingFromDelta(dir);
    castleBandHot = inCastleBand(next);

    if (!scrambled) {
      final travel01 = (_dragTravelDist / kChargeTravelNeed).clamp(0.0, 1.0);
      if (field[i].troop == TroopType.cavalry) {
        if (coach != null && coach.session == TutorialSession.session1) {
          coach.onChargeTravelProgress(travel01);
        } else if (coach == null) {
          if (travel01 >= 1.0) {
            _matchChargeIndex = i;
            _matchChargeC = 1.0;
          } else if (_matchChargeIndex == i) {
            _matchChargeC = travel01;
          } else if (travel01 > kChargeRingShowTravel01) {
            _matchChargeIndex = i;
            _matchChargeC = travel01;
          }
        }
      }
    }
    return walked > 0.5;
  }

  /// Arrival: body rests on the reachable target, then the waypoint is cleared.
  /// A released march that ends inside 己城 parks there (歸城). Finger-down arrival
  /// does not 歸城 — release still owns that.
  void _completeMarch(int i, Offset rest) {
    fieldPos[i] = rest;
    final park = !dragging && tutorial == null && !isEnemyAt(i) && inCastleBand(rest);
    dragTo = null;
    _lastDragDir = null;
    if (park) _parkInCastle(i, rest);
  }

  /// Intentional 歸城. Clears the march so the parked body does not walk back out.
  void _parkInCastle(int i, Offset at) {
    final band = castleBandRect;
    final maxX = size.x > 48 ? size.x - 48 : 48.0;
    fieldPos[i] = Offset(
      at.dx.clamp(48.0, maxX),
      band.top + band.height * 0.55,
    );
    while (fieldInCastle.length <= i) {
      fieldInCastle.add(false);
    }
    fieldInCastle[i] = true;
    triggerReturnCityFx();
    _cancelBowWindup();
    _matchChargeIndex = null;
    _matchChargeC = 0;
    dragTo = null;
    _lastDragDir = null;
    castleBandHot = false;
  }

  void _maybeSnapKiseiFlash() {
    final nowAura = auraActive;
    if (nowAura && !_prevAuraActive) {
      final idx = (selectedIndex != null &&
              selectedIndex! < field.length &&
              !isEnemyAt(selectedIndex!))
          ? selectedIndex!
          : (tutorialOwnIndex ?? 0);
      if (_hitFlashLabel != '突撃') {
        flashHit(idx, '氣勢');
      }
    }
    _prevAuraActive = nowAura;
  }

  /// Free-match layout for the visual prove. Clears travel, 亂戰, and hit text.
  /// Does not set shotPassMode — [tutorial] is left untouched.
  void debugRestageOwnEnemy({
    required String ownId,
    required Offset ownAt,
    required Offset enemyAt,
  }) {
    final own = Cost6Roster.all.firstWhere((c) => c.id == ownId);
    final enemy = Cost6Roster.all.firstWhere((c) => c.id == 'caocao');
    field.clear();
    fieldPos.clear();
    fieldIsEnemy.clear();
    fieldInCastle.clear();
    field.add(own);
    field.add(enemy);
    fieldIsEnemy.addAll([false, true]);
    fieldInCastle.addAll([false, false]);
    fieldPos.add(ownAt);
    fieldPos.add(enemyAt);
    selectedIndex = 0;
    tutorialOwnIndex = null;
    tutorialEnemyIndex = null;
    dragging = false;
    dragFrom = null;
    dragTo = null;
    _dragTravelDist = 0;
    _lastDragDir = null;
    _matchChargeIndex = null;
    _matchChargeC = 0;
    _meleeEnemyIndex = null;
    _chargeResolvedThisContact = false;
    _prevAuraActive = false;
    _ransenUnits.clear();
    _unitHp
      ..clear()
      ..add(kRansenMaxHp)
      ..add(kRansenMaxHp);
    _hitFlashIndex = null;
    _hitFlashLeft = 0;
    _hitFlashLabel = '';
    _cancelBowWindup();
  }

  /// Test hook: pursuit + 亂戰 contact + 氣勢 snap without Flame's component tree.
  /// Stop-fade stays in [debugDecayStoppedCharge] so arrival-frame travel stays lit.
  void debugStepPursuit(double dt) {
    _pulse += dt;
    _pursueWaypoint(dt);
    _tickRansen(dt);
    _maybeSnapKiseiFlash();
  }

  /// Stop fade only. Arrival clears the waypoint; this drains travel / aura.
  void debugDecayStoppedCharge(double dt) => _decayChargeAfterStop(dt);

  /// Flash timer only, so tests can show 突撃 ending while overlap continues.
  void debugDecayCombatFx(double dt) {
    if (_hitFlashLeft <= 0) return;
    _hitFlashLeft -= dt;
    if (_hitFlashLeft <= 0) {
      _hitFlashLeft = 0;
      _hitFlashIndex = null;
      _hitFlashLabel = '';
    }
  }

  /// Same-distance straight waypoint (tests + SPEED_COMPARE_VERIFY).
  /// Default length stays under [kChargeTravelNeed] so the compare is wiki base
  /// (騎 1.1 vs 歩 0.9), not the aura 1.32 boost.
  /// Body stays put until [update] / [debugStepPursuit]. Does not teleport.
  /// Returns the gold-landing lag after the arm (0 if the drag did not start).
  double debugArmSpeedCompare(TroopType troop, {double distancePx = 96}) {
    final card = Cost6Roster.all.firstWhere((c) => c.troop == troop);
    field.clear();
    fieldPos.clear();
    fieldIsEnemy.clear();
    fieldInCastle.clear();
    final w = size.x > 0 ? size.x : 390.0;
    final top = size.y > 0 ? watchH : 152.0;
    final fh = size.y > 0 ? fieldH : 400.0;
    final start = Offset(w * 0.16, top + fh * 0.48);
    final landing = Offset(start.dx + distancePx, start.dy);
    field.add(card);
    fieldIsEnemy.add(false);
    fieldInCastle.add(false);
    fieldPos.add(start);
    selectedIndex = 0;
    tutorialOwnIndex = 0;
    tutorialEnemyIndex = null;
    dragging = false;
    dragFrom = null;
    dragTo = null;
    _dragTravelDist = 0;
    _lastDragDir = null;
    _meleeEnemyIndex = null;
    _chargeResolvedThisContact = false;
    _matchChargeIndex = null;
    _matchChargeC = 0;

    final coach = tutorial;
    if (coach != null &&
        coach.session == TutorialSession.session1 &&
        coach.s1 != S1Phase.highlightSelect &&
        coach.s1 != S1Phase.dragGuide &&
        coach.s1 != S1Phase.waitAura &&
        coach.s1 != S1Phase.hitCharge) {
      coach.s1 = S1Phase.dragGuide;
    }
    panStart(start);
    panUpdate(landing);
    return debugWaypointLagPx;
  }

  /// Map a field-space point onto the Watch perspective lane (live, every frame).
  Offset mapFieldToWatch(Offset field, Rect band) {
    final w = size.x > 0 ? size.x : math.max(band.width, 1.0);
    final fieldTop = size.y > 0 ? watchH : 200.0;
    final fh = size.y > 0 ? fieldH.clamp(1.0, double.infinity) : 280.0;
    final x01 = (field.dx / w).clamp(0.0, 1.0);
    final yAlong = ((field.dy - fieldTop) / fh).clamp(0.0, 1.0);
    final far01 = (1.0 - yAlong).clamp(0.0, 1.0);
    final horizonY = band.top + band.height * 0.22;
    final nearY = band.bottom - band.height * 0.10;
    final y = nearY + (horizonY + 18 - nearY) * far01;
    final inset = 0.10 + 0.32 * far01;
    final left = band.left + band.width * inset;
    final right = band.right - band.width * inset;
    final x = left + (right - left) * x01;
    return Offset(x, y);
  }

  double watchDepth01(Offset field) {
    final fieldTop = size.y > 0 ? watchH : 200.0;
    final fh = size.y > 0 ? fieldH.clamp(1.0, double.infinity) : 280.0;
    final yAlong = ((field.dy - fieldTop) / fh).clamp(0.0, 1.0);
    return (1.0 - yAlong).clamp(0.0, 1.0);
  }

  Offset tokenCenter(int i) {
    if (i >= 0 && i < fieldPos.length) return fieldPos[i];
    const tokenR = 28.0;
    return Offset(48.0 + i * (tokenR * 2 + 20), watchH + 110);
  }

  /// Waypoint is ahead of the body: card pins on [dragTo], shadow is [fieldPos].
  bool pinnedMarchAt(int i) {
    if (dragTo == null || selectedIndex != i || i < 0 || i >= fieldPos.length) return false;
    return (fieldPos[i] - dragTo!).distance > kArrivalEpsilon;
  }

  /// Full-color field card. Pinned on the gold 落點 during a march; the card after 合體.
  Offset pinnedCardAt(int i) => pinnedMarchAt(i) ? dragTo! : tokenCenter(i);

  /// Translucent march body. Gameplay, aura rings, and the Watch solid unit use this.
  Offset shadowAt(int i) => tokenCenter(i);

  void setupSession1Field() {
    field.clear();
    fieldPos.clear();
    fieldIsEnemy.clear();
    fieldInCastle.clear();
    selectedIndex = null;
    final zhao = Cost6Roster.all.firstWhere((c) => c.id == 'zhaoyun');
    final cao = Cost6Roster.all.firstWhere((c) => c.id == 'caocao');
    // Layout lock: lower field shows BOTH own + enemy (not own-only).
    field.addAll([zhao, cao]);
    fieldIsEnemy.addAll([false, true]);
    fieldInCastle.addAll([false, false]);
    final wh = size.y > 0 ? watchH : 200.0;
    final w = size.x > 0 ? size.x : 390.0;
    fieldPos.addAll([
      Offset(w * 0.28, wh + (size.y > 0 ? (size.y - wh) * 0.55 : 140)), // own cavalry
      Offset(w * 0.62, wh + (size.y > 0 ? (size.y - wh) * 0.28 : 90)), // enemy
    ]);
    tutorialOwnIndex = 0;
    tutorialEnemyIndex = 1;
    selectedIndex = null;
    ownFacing = -0.2;
    enemyFacing = math.pi + 0.3;
  }

  void setupSession2Field() {
    field.clear();
    fieldPos.clear();
    fieldIsEnemy.clear();
    fieldInCastle.clear();
    selectedIndex = null;
    final spear = Cost6Roster.all.firstWhere((c) => c.id == 'zhanghe');
    final enemyCav = Cost6Roster.all.firstWhere((c) => c.id == 'caocao');
    field.addAll([spear, enemyCav]);
    fieldIsEnemy.addAll([false, true]);
    fieldInCastle.addAll([false, false]);
    final wh = size.y > 0 ? watchH : 200.0;
    final w = size.x > 0 ? size.x : 390.0;
    final fh = size.y > 0 ? (size.y - wh) : 280.0;
    fieldPos.addAll([
      Offset(w * 0.35, wh + fh * 0.58), // own spear
      Offset(w * 0.70, wh + fh * 0.28), // enemy cavalry
    ]);
    tutorialOwnIndex = 0;
    tutorialEnemyIndex = 1;
    ownFacing = 0; // wrong initially until turn
    enemyFacing = math.pi;
    selectedIndex = 0;
  }

  void setupMatchDemoField() {
    field.clear();
    fieldPos.clear();
    fieldIsEnemy.clear();
    fieldInCastle.clear();
    selectedIndex = null;
    tutorialOwnIndex = null;
    tutorialEnemyIndex = null;
    final ownCards = [
      Cost6Roster.all.firstWhere((c) => c.id == 'zhaoyun'),
      Cost6Roster.all.firstWhere((c) => c.troop == TroopType.spear),
      Cost6Roster.all.firstWhere((c) => c.troop == TroopType.bow),
    ];
    final enemyCards = [
      Cost6Roster.all.firstWhere((c) => c.id == 'caocao'),
      Cost6Roster.all.firstWhere((c) => c.id == 'caoren'),
    ];
    final wh = size.y > 0 ? watchH : 200.0;
    final w = size.x > 0 ? size.x : 390.0;
    final fh = size.y > 0 ? (size.y - wh) : 280.0;
    for (var i = 0; i < ownCards.length; i++) {
      field.add(ownCards[i]);
      fieldIsEnemy.add(false);
      fieldInCastle.add(false);
      fieldPos.add(Offset(w * (0.22 + i * 0.22), wh + fh * 0.62));
    }
    for (var i = 0; i < enemyCards.length; i++) {
      field.add(enemyCards[i]);
      fieldIsEnemy.add(true);
      fieldInCastle.add(false);
      fieldPos.add(Offset(w * (0.35 + i * 0.28), wh + fh * 0.22));
    }
    // Cap visual stack: never more than fieldMax total, no stack-shadow.
    while (field.length > fieldMax) {
      field.removeLast();
      fieldPos.removeLast();
      fieldIsEnemy.removeLast();
      if (fieldInCastle.isNotEmpty) fieldInCastle.removeLast();
    }
    selectedIndex = 0;
    tutorialOwnIndex = 0;
    ownCastle = 0.72;
    enemyCastle = 0.58;
    // Enemy cavalry auto-charges so spear intercept is manually verifiable (≥1C aura).
    _matchEnemyChargeIndex = null;
    _matchEnemyChargeC = 0;
    _matchTurnWindowOpen = false;
    _matchFacingCorrect = false;
    _matchSpearIndex = null;
    for (var i = 0; i < field.length; i++) {
      if (fieldIsEnemy[i] && field[i].troop == TroopType.cavalry && _matchEnemyChargeIndex == null) {
        _matchEnemyChargeIndex = i;
      }
      if (!fieldIsEnemy[i] && field[i].troop == TroopType.spear && _matchSpearIndex == null) {
        _matchSpearIndex = i;
      }
    }
    _matchEnemyChargeC = 0;
    ownFacing = 0.85; // wrong until player turns
    _bowWindupIndex = null;
    _bowWindupC = 0;
    _bowShotReady = false;
    _bowDidShoot = false;
  }

  void setupFeelCastleField() {
    setupMatchDemoField();
    ownCastle = 0.82;
    enemyCastle = 0.45;
    selectedIndex = 0;
    holdReturnFlash = true;
    _returnFlashLeft = 1.0;
    // UIUX: 5:8 cards @12% field_w + 己城 band highlight (drag-in 返城).
    final wh = size.y > 0 ? watchH : 200.0;
    final w = size.x > 0 ? size.x : 390.0;
    final fh = size.y > 0 ? (size.y - wh) : 280.0;
    final band = size.y > 0
        ? castleBandRect
        : Rect.fromLTWH(0, wh + fh * 0.88, w, fh * 0.12);
    if (fieldPos.isNotEmpty) {
      fieldPos[0] = Offset(w * 0.28, band.top + band.height * 0.55);
      while (fieldInCastle.length < field.length) {
        fieldInCastle.add(false);
      }
      fieldInCastle[0] = true;
    }
    dragging = true;
    castleBandHot = true;
    dragFrom = Offset(w * 0.28, wh + fh * 0.55);
    dragTo = fieldPos.isNotEmpty ? fieldPos[0] : Offset(w * 0.28, band.top + band.height * 0.55);
  }

  /// FEEL_SHOT=drag-live: freeze mid-drag rubber-band toward drop (enemy outlined).
  /// Mid charging pose: travel filling, auraActive=false — ZERO cyan (蓄緊 only).
  void setupChargeAuraLivePose() {
    setupSession1Field();
    if (tutorialOwnIndex != null) {
      final i = tutorialOwnIndex!;
      selectedIndex = i;
      // Mid-fill (~45%) — charging binary proof (no rings until aura snaps).
      _dragTravelDist = kChargeTravelNeed * 0.45;
      ownFacing = -0.35; // slight turn so Watch facing sync is obvious
      final from = tokenCenter(i);
      final drop = dropGuidePoint;
      fieldPos[i] = Offset(
        from.dx + (drop.dx - from.dx) * 0.45,
        from.dy + (drop.dy - from.dy) * 0.45,
      );
      dragFrom = tokenCenter(i);
      dragTo = drop;
      dragging = true; // hold steer so fade does not eat the shot
    }
    watchKind = AWindowKind.charge;
  }

  void setupFeelDragLivePose() {

    setupSession1Field();
    if (tutorialOwnIndex != null) {
      selectedIndex = tutorialOwnIndex;
      dragFrom = tokenCenter(tutorialOwnIndex!);
      final drop = dropGuidePoint;
      // Midway — clearly mid-drag, not yet on 落點.
      dragTo = Offset(
        dragFrom!.dx + (drop.dx - dragFrom!.dx) * 0.55,
        dragFrom!.dy + (drop.dy - dragFrom!.dy) * 0.55,
      );
      dragging = true;
    }
    watchKind = AWindowKind.charge;
  }

  /// FEEL_SHOT=drag-hit: own at drop, 突撃 flash held after aura gate.
  void setupFeelDragHitPose() {
    setupSession1Field();
    if (tutorialOwnIndex != null) {
      fieldPos[tutorialOwnIndex!] = dropGuidePoint;
      selectedIndex = tutorialOwnIndex;
    }
    dragging = false;
    dragFrom = null;
    dragTo = null;
    watchKind = AWindowKind.charge;
    flashHit(tutorialOwnIndex ?? 0, '突撃');
  }

  /// FEEL_SHOT=charge-no-aura-bump: MELEE contact WITHOUT aura — light bump, NO 「突撃」.
  void setupChargeNoAuraBumpPose() {
    setupSession1Field();
    _dragTravelDist = 0;
    _matchChargeIndex = null;
    _matchChargeC = 0;
    _chargeResolvedThisContact = false;
    dragging = false;
    dragFrom = null;
    dragTo = null;
    if (tutorialOwnIndex != null && tutorialEnemyIndex != null) {
      final enemy = tokenCenter(tutorialEnemyIndex!);
      // True card overlap (melee), not proximity-near.
      final d = meleeContactDist * 0.55;
      fieldPos[tutorialOwnIndex!] = Offset(enemy.dx - d * 0.7, enemy.dy + d * 0.5);
      selectedIndex = tutorialOwnIndex;
      _meleeEnemyIndex = tutorialEnemyIndex;
    }
    watchKind = AWindowKind.charge;
    bumpMelee(tutorialOwnIndex ?? 0); // light bump only — empty label, no 突撃
  }

  /// FEEL_SHOT=charge-aura-hit: CHARGE = auraActive && real contact — flash + 「突撃」.
  void setupChargeAuraHitPose() {
    setupSession1Field();
    _dragTravelDist = kChargeTravelNeed;
    dragging = false;
    dragFrom = null;
    dragTo = null;
    if (tutorialOwnIndex != null && tutorialEnemyIndex != null) {
      final enemy = tokenCenter(tutorialEnemyIndex!);
      final d = meleeContactDist * 0.55;
      fieldPos[tutorialOwnIndex!] = Offset(enemy.dx - d * 0.7, enemy.dy + d * 0.5);
      selectedIndex = tutorialOwnIndex;
      _matchChargeIndex = tutorialOwnIndex;
      _matchChargeC = 1.0;
      _meleeEnemyIndex = tutorialEnemyIndex;
      _chargeResolvedThisContact = true;
    }
    watchKind = AWindowKind.charge;
    flashHit(tutorialOwnIndex ?? 0, '突撃');
  }

  /// FEEL_SHOT=drag-samefaction: Wei cavalry vs Wei cavalry mid-drag (Design outline check).
  void setupFeelDragSameFactionPose() {
    field.clear();
    fieldPos.clear();
    fieldIsEnemy.clear();
    fieldInCastle.clear();
    final own = Cost6Roster.all.firstWhere((c) => c.id == 'caoren'); // 魏騎
    final enemy = Cost6Roster.all.firstWhere((c) => c.id == 'caocao'); // 魏騎
    field.addAll([own, enemy]);
    fieldIsEnemy.addAll([false, true]);
    fieldInCastle.addAll([false, false]);
    final wh = size.y > 0 ? watchH : 200.0;
    final w = size.x > 0 ? size.x : 390.0;
    final fh = size.y > 0 ? (size.y - wh) : 280.0;
    fieldPos.addAll([
      Offset(w * 0.28, wh + fh * 0.58),
      Offset(w * 0.62, wh + fh * 0.30),
    ]);
    tutorialOwnIndex = 0;
    tutorialEnemyIndex = 1;
    selectedIndex = 0;
    ownFacing = -0.25;
    enemyFacing = math.pi + 0.25;
    watchKind = AWindowKind.charge;
    dragFrom = fieldPos[0];
    final drop = Offset(w * 0.55, wh + fh * 0.42);
    dragTo = Offset(
      dragFrom!.dx + (drop.dx - dragFrom!.dx) * 0.55,
      dragFrom!.dy + (drop.dy - dragFrom!.dy) * 0.55,
    );
    dragging = true;
  }

  /// FEEL_SHOT=spear-idle: own spear SpriteAnimation idle loop (5:8 @0.10 field_w).
  /// Tip glow FX stays on (槍尖光常在) even in idle pose.
  void setupFeelSpearIdlePose() {
    setupSession2Field();
    debugForcePose = TroopAnimPose.idle;
    debugForcePoseIndex = tutorialOwnIndex;
    ownFacing = -0.2; // idle facing — tip glow still drawn via telegraph
    selectedIndex = tutorialOwnIndex;
    watchKind = AWindowKind.intercept;
  }

  /// FEEL_SHOT=spear-attack: row3 tip-glow attack loop readable for UIUX.
  void setupFeelSpearAttackPose() {
    setupSession2Field();
    debugForcePose = TroopAnimPose.attack;
    debugForcePoseIndex = tutorialOwnIndex;
    ownFacing = -0.35;
    selectedIndex = tutorialOwnIndex;
    watchKind = AWindowKind.intercept;
  }

  /// FEEL_SHOT=cav-idle: own cavalry sheet idle @0.10 field_w.
  void setupFeelCavalryIdlePose() {
    setupMatchDemoField();
    _matchEnemyChargeIndex = null;
    _matchChargeIndex = null;
    int? cavI;
    for (var i = 0; i < field.length; i++) {
      if (!fieldIsEnemy[i] && field[i].troop == TroopType.cavalry) {
        cavI = i;
        break;
      }
    }
    cavI ??= 0;
    selectedIndex = cavI;
    debugForcePose = TroopAnimPose.idle;
    debugForcePoseIndex = cavI;
    watchKind = AWindowKind.charge;
  }

  /// FEEL_SHOT=cav-attack: cavalry charge/attack row readable for UIUX.
  void setupFeelCavalryAttackPose() {
    setupMatchDemoField();
    _matchEnemyChargeIndex = null;
    int? cavI;
    for (var i = 0; i < field.length; i++) {
      if (!fieldIsEnemy[i] && field[i].troop == TroopType.cavalry) {
        cavI = i;
        break;
      }
    }
    cavI ??= 0;
    selectedIndex = cavI;
    _matchChargeIndex = cavI;
    _matchChargeC = 1.0;
    debugForcePose = TroopAnimPose.attack;
    debugForcePoseIndex = cavI;
    watchKind = AWindowKind.charge;
  }

  /// FEEL_SHOT=bow-idle: own bow sheet idle @0.10 field_w (no windup FX clutter).
  void setupFeelBowIdlePose() {
    setupMatchDemoField();
    _matchEnemyChargeIndex = null;
    int? bowI;
    for (var i = 0; i < field.length; i++) {
      if (!fieldIsEnemy[i] && field[i].troop == TroopType.bow) {
        bowI = i;
        break;
      }
    }
    bowI ??= 0;
    selectedIndex = bowI;
    _bowWindupIndex = null;
    _bowWindupC = 0;
    _bowShotReady = false;
    _bowDidShoot = false;
    debugForcePose = TroopAnimPose.idle;
    debugForcePoseIndex = bowI;
    watchKind = AWindowKind.bow;
  }

  /// FEEL_SHOT=bow-attack: bow attack/windup row (+ light 蓄勢) for UIUX.
  void setupFeelBowAttackPose() {
    setupMatchDemoField();
    _matchEnemyChargeIndex = null;
    int? bowI;
    for (var i = 0; i < field.length; i++) {
      if (!fieldIsEnemy[i] && field[i].troop == TroopType.bow) {
        bowI = i;
        break;
      }
    }
    bowI ??= 0;
    selectedIndex = bowI;
    _bowWindupIndex = bowI;
    _bowWindupC = 0.85;
    _bowShotReady = true;
    _bowDidShoot = false;
    debugForcePose = TroopAnimPose.attack;
    debugForcePoseIndex = bowI;
    watchKind = AWindowKind.bow;
  }

  /// FEEL_SHOT=intercept-window: enemy aura on, spear tip glow, facing still wrong (count C).
  void setupFeelInterceptWindowPose() {
    setupSession2Field();
    ownFacing = 0.9; // wrong facing — player must turn after ≥1C
    enemyFacing = math.pi;
    watchKind = AWindowKind.intercept;
    selectedIndex = tutorialOwnIndex;
  }

  /// FEEL_SHOT=bow: own bow mid windup (ground seal + aim dash + reticle), still ~1C.
  void setupFeelBowWindupPose() {
    setupMatchDemoField();
    int? bowI;
    for (var i = 0; i < field.length; i++) {
      if (!fieldIsEnemy[i] && field[i].troop == TroopType.bow) {
        bowI = i;
        break;
      }
    }
    bowI ??= 0;
    selectedIndex = bowI;
    _bowWindupIndex = bowI;
    _bowWindupC = 0.72; // mid windup readable
    _bowShotReady = false;
    _bowDidShoot = false;
    watchKind = AWindowKind.bow;
    // Pause enemy charge noise for clean bow shot.
    _matchEnemyChargeIndex = null;
  }

  Offset get dropGuidePoint {
    final wh = size.y > 0 ? watchH : 200.0;
    final w = size.x > 0 ? size.x : 390.0;
    // Mid field, clear of bottom bar (bar is outside GameWidget).
    return Offset(w * 0.55, wh + (size.y - wh) * 0.42);
  }

  @override
  void update(double dt) {
    super.update(dt);
    // C clock runs whenever [CClock.running] — FEEL_SHOT/TutorialShell pause for freezes only.
    clock.update(dt);
    _pulse += dt;
    // Troop SpriteAnimations — independent of drag/buttons; never blocks input.
    troopSprites.update(dt);
    tutorial?.tick(dt);

    _watchPhaseLeft -= dt;
    if (_watchPhaseLeft <= 0) {
      watchKind = switch (watchKind) {
        AWindowKind.charge => AWindowKind.intercept,
        AWindowKind.intercept => AWindowKind.bow,
        AWindowKind.bow => AWindowKind.charge,
        AWindowKind.stratagem => AWindowKind.charge,
      };
      _watchPhaseLeft = FxWindows.toSeconds(switch (watchKind) {
        AWindowKind.charge => FxWindows.chargeAuraVisibleC,
        AWindowKind.intercept => FxWindows.interceptTurnAfterAuraC,
        AWindowKind.bow => FxWindows.bowStopBeforeShotC,
        AWindowKind.stratagem => FxWindows.strategyFxMaxC,
      });
    }

    // Tutorial coaching: keep watch telegraph aligned with current gate (aura / spear).
    final coach = tutorial;

    // UIUX lock: drag = WAYPOINT. Body walks at troop speed — never 1:1 glue / teleport.
    // Finger-up commits the waypoint; marching continues until arrival.
    // Aura from continuous straight travel. Waypoint retarget keeps the meter.
    // Clear travel on arrived-stop, sharp turn (~70°), or after 突撃.
    // Overlap: aura+contact → 突撃 once then 亂戰; no aura → 亂戰 directly.
    _pursueWaypoint(dt);
    _tickRansen(dt);
    _decayChargeAfterStop(dt);

    // Every frame: Watch telegraph follows live field charge facing + aura (not demo cycle alone).
    final liveCharge01 = (_dragTravelDist / kChargeTravelNeed).clamp(0.0, 1.0);
    final liveChargeOn = liveCharge01 > kChargeRingShowTravel01 ||
        (coach != null &&
            coach.session == TutorialSession.session1 &&
            (coach.auraReady ||
                coach.s1 == S1Phase.waitAura ||
                coach.s1 == S1Phase.hitCharge ||
                coach.s1 == S1Phase.tipNext)) ||
        (coach == null && _matchChargeIndex != null && _matchChargeC > kChargeRingShowTravel01);
    if (coach != null) {
      if (coach.session == TutorialSession.session1 &&
          (liveChargeOn ||
              coach.s1 == S1Phase.waitAura ||
              coach.s1 == S1Phase.hitCharge ||
              coach.s1 == S1Phase.tipNext ||
              (coach.shotPassMode && coach.s1 == S1Phase.waitAura))) {
        watchKind = AWindowKind.charge;
      } else if (coach.session == TutorialSession.session2) {
        watchKind = AWindowKind.intercept;
      }
    } else if (liveChargeOn) {
      watchKind = AWindowKind.charge;
    }

    // Shot modes freeze FX so Simulator captures stay readable.
    final holdFx = tutorial?.shotPassMode ?? false;
    if (_stratLeft > 0 && !holdFx) {
      _stratLeft -= dt;
      if (_stratLeft <= 0) {
        _stratLeft = 0;
        _stratAt = null;
      }
    }
    if (_hitFlashLeft > 0 && !holdFx) {
      _hitFlashLeft -= dt;
      if (_hitFlashLeft <= 0) {
        _hitFlashLeft = 0;
        _hitFlashIndex = null;
        _hitFlashLabel = '';
      }
    }
    if (_returnFlashLeft > 0 && !holdFx && !holdReturnFlash) {
      _returnFlashLeft -= dt;
      if (_returnFlashLeft <= 0) _returnFlashLeft = 0;
    }
    if (_shakeLeft > 0 && !holdFx) {
      _shakeLeft -= dt;
      if (_shakeLeft < 0) _shakeLeft = 0;
    }

    // Free-match charge fade is driven by _dragTravelDist decay above (no wait-auto 突撃).

    // Free-match: enemy charge aura visible; after ≥1C tip-hit → auto 迎擊 (no button).
    if (tutorial == null && _matchEnemyChargeIndex != null) {
      _matchEnemyChargeC += dt / CClock.secondsPerC;
      if (_matchEnemyChargeC >= FxWindows.interceptTurnAfterAuraC && !_matchTurnWindowOpen) {
        _matchTurnWindowOpen = true;
        _matchFacingCorrect = true; // spear tip always on toward threat
      }
      if (_matchTurnWindowOpen &&
          _matchFacingCorrect &&
          _matchSpearIndex != null &&
          _matchEnemyChargeIndex != null) {
        flashHit(_matchSpearIndex!, '迎擊');
        _matchEnemyChargeIndex = null;
        _matchTurnWindowOpen = false;
      }
    }

    _maybeSnapKiseiFlash();

    // Tutorial S1: 突撃 only on collide while aura ready (handled in walk / panEnd).

    // Tutorial S2: auto 迎擊 when aura hits tip (facingCorrect + turnWindow).
    if (coach != null &&
        coach.session == TutorialSession.session2 &&
        !coach.shotPassMode &&
        coach.turnWindowOpen &&
        coach.facingCorrect &&
        !coach.interceptDone &&
        (coach.s2 == S2Phase.interceptHit || coach.s2 == S2Phase.waitTurn)) {
      flashHit(tutorialOwnIndex ?? 0, '迎擊');
      coach.onAutoIntercept(facingWasCorrect: true);
      onTutorialChanged?.call();
    }

    // LIVE_VERIFY: HUD C when S2 aura / turn window edge fires.
    if (coach != null && coach.session == TutorialSession.session2) {
      if (coach.enemyAuraVisible && !_verifyLoggedAura) {
        _verifyLoggedAura = true;
        // ignore: avoid_print
        print('VERIFY_S2 auraHUD remainingC=${clock.remainingC} phaseC=${coach.phaseC.toStringAsFixed(2)}');
      }
      if (coach.turnWindowOpen && !_verifyLoggedTurn) {
        _verifyLoggedTurn = true;
        // ignore: avoid_print
        print('VERIFY_S2 turnHUD remainingC=${clock.remainingC} phaseC=${coach.phaseC.toStringAsFixed(2)}');
      }
    }

    // Free-match bow: accumulate still time toward ~1C; first shot only when ready.
    // 亂戰 stops the shot — windup does not advance while the bow is overlapping.
    if (tutorial == null && _bowWindupIndex != null && _ransenUnits.contains(_bowWindupIndex)) {
      _cancelBowWindup();
    } else if (tutorial == null && _bowWindupIndex != null && !_bowDidShoot) {
      _bowWindupC += dt / CClock.secondsPerC;
      if (_bowWindupC >= FxWindows.bowStopBeforeShotC) {
        if (!_bowShotReady && !_verifyLoggedBowReady) {
          _verifyLoggedBowReady = true;
          // ignore: avoid_print
          print('VERIFY_BOW readyC=${clock.remainingC} windupC=${_bowWindupC.toStringAsFixed(2)}');
        }
        _bowShotReady = true;
      }
    }

    // Session2 / match: facing drives spear tip — player sets facingCorrect / _matchFacingCorrect.
    final t = tutorial;
    if (t != null && t.session == TutorialSession.session2) {
      if (t.facingCorrect) {
        ownFacing = -0.35; // tip toward enemy
      } else {
        ownFacing = 0.9; // wrong facing until player turns
      }
    } else if (tutorial == null && _matchSpearIndex != null) {
      if (_matchFacingCorrect) {
        ownFacing = -0.35;
      } else {
        ownFacing = 0.85;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _maybeLogH0Metrics();
    final w = size.x;
    final h = size.y;
    final wh = watchH;
    final fieldTop = wh;

    // Short hit shake ≤0.3C (visual only).
    if (_shakeLeft > 0) {
      final mag = 3.0 * (_shakeLeft / FxWindows.toSeconds(FxWindows.interceptHitFlashC));
      canvas.save();
      canvas.translate(mag * math.sin(_pulse * 40), mag * math.cos(_pulse * 33));
    }

    // Top short watch (H0 ≤18% game): full battlefield — BOTH sides, READ-ONLY. 3D/perspective OK here.
    canvas.drawRect(Rect.fromLTWH(0, 0, w, wh), Paint()..color = const Color(0xFF141414));
    _drawLacquerGrain(canvas, Rect.fromLTWH(0, 0, w, wh), alpha: 0.08);
    _drawText(canvas, '全戰場（只睇）', const Offset(12, 8), FactionColors.gold, 13);
    _drawWatchFullField(canvas, Rect.fromLTWH(0, 0, w, wh));

    // Mid divider: thicker dual castle bars + 99C zone edge.
    _drawCastleRaceBars(canvas, w, fieldTop);

    // Bottom flat ortho playfield (H0 ≥55%): lacquer + ortho gold grid — NO perspective/vanishing.
    final fieldRect = Rect.fromLTWH(0, fieldTop, w, h - wh);
    canvas.drawRect(fieldRect, Paint()..color = const Color(0xFF0A0A0A));
    _drawFieldLacquer(canvas, fieldRect);
    _drawOrthoFieldGrid(canvas, fieldRect);
    _drawLacquerGrain(canvas, fieldRect, alpha: 0.04);
    _drawOwnCastleBand(canvas, fieldRect);

    final t = tutorial;
    // Light vertical padding (tip is overlay; keep dragH ≥0.55).
    _drawText(canvas, '雙方動向（可操作）', Offset(16, fieldTop + 14), FactionColors.gold, 16);
    if (t == null) {
      final ownN = fieldIsEnemy.where((e) => !e).length;
      final enN = fieldIsEnemy.where((e) => e).length;
      _drawText(
        canvas,
        'Cost $costCap · 場上 ${field.length}/$fieldMax（己$ownN／敵$enN）',
        Offset(16, fieldTop + 34),
        Colors.white54,
        12,
      );
    }

    // Session1 / feel: drop guide + dashed path (not after tipNext / hit)
    if (t != null &&
        t.session == TutorialSession.session1 &&
        (t.s1 == S1Phase.dragGuide ||
            t.s1 == S1Phase.waitAura ||
            t.s1 == S1Phase.hitCharge ||
            (t.shotPassMode &&
                (t.s1 == S1Phase.dragGuide ||
                    t.s1 == S1Phase.waitAura ||
                    t.s1 == S1Phase.hitCharge)))) {
      final drop = dropGuidePoint;
      // Soft gold landing disc + label — NEVER cyan concentric charge rings.
      canvas.drawCircle(drop, 22, Paint()..color = FactionColors.gold.withValues(alpha: 0.16));
      canvas.drawCircle(
        drop,
        22,
        Paint()
          ..color = FactionColors.gold.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
      canvas.drawCircle(drop, 6, Paint()..color = FactionColors.gold.withValues(alpha: 0.9));
      _drawText(canvas, '落點', Offset(drop.dx - 14, drop.dy + 28), FactionColors.gold.withValues(alpha: 0.85), 12);
      if (tutorialOwnIndex != null) {
        final from = tokenCenter(tutorialOwnIndex!);
        _drawGoldWaypointGuide(canvas, from, drop, drawLanding: false);
      }
    }

    // Ghost path from the marching shadow to the pinned card. Low opacity.
    if (selectedIndex != null && pinnedMarchAt(selectedIndex!)) {
      _drawGoldWaypointGuide(
        canvas,
        shadowAt(selectedIndex!),
        dragTo!,
        ghostTrail: true,
        labelLanding: true,
      );
    }

    // Real-card 5:8; width ≈10% field (UIUX gate 0.10–0.11, max 0.12).
    // Own + enemy share ONE tokenSize — faction via outline/facing/color only, never scale.
    final tokenSize = tokenCardSize;
    for (var i = 0; i < field.length; i++) {
      final card = field[i];
      final center = tokenCenter(i);
      final selected = selectedIndex == i;
      final isEnemy = i < fieldIsEnemy.length
          ? fieldIsEnemy[i]
          : (tutorialEnemyIndex == i);
      final dim = t != null &&
          t.session == TutorialSession.session1 &&
          isEnemy == false &&
          tutorialOwnIndex != i &&
          (t.s1 == S1Phase.highlightSelect ||
              t.s1 == S1Phase.dragGuide ||
              t.s1 == S1Phase.waitAura ||
              t.s1 == S1Phase.hitCharge);

      // Aura rings bind to the shadow (march position), never the pinned card.
      _drawFieldTelegraph(canvas, center, card, i, isOwn: !isEnemy && tutorialOwnIndex == i, isEnemy: isEnemy);

      final inCastle = i < fieldInCastle.length && fieldInCastle[i];
      final pinned = pinnedMarchAt(i);
      if (pinned) {
        _drawCardLikeToken(
          canvas,
          center,
          card,
          index: i,
          cardW: tokenSize.width,
          cardH: tokenSize.height,
          selected: false,
          isEnemy: false,
          dim: false,
          pulseOwn: false,
          opacity: kMarchShadowOpacity,
        );
        _drawFacingArrow(canvas, center, ownFacing, FactionColors.gold);
      } else {
        _drawCardLikeToken(
          canvas,
          center,
          card,
          index: i,
          cardW: tokenSize.width,
          cardH: tokenSize.height,
          selected: selected || (tutorialOwnIndex == i && t != null),
          isEnemy: isEnemy,
          dim: dim || inCastle,
          pulseOwn: tutorialOwnIndex == i && t != null && t.session == TutorialSession.session1,
        );

        // Facing follows travel direction every frame (own while selected; enemy always).
        if (isEnemy) {
          _drawFacingArrow(canvas, center, enemyFacing, const Color(0xFFFFF59D), enemyHard: true);
        } else if (selected || tutorialOwnIndex == i) {
          _drawFacingArrow(canvas, center, ownFacing, FactionColors.gold);
        }

        final labelY = center.dy + tokenSize.height / 2 + 4;
        _drawText(
          canvas,
          card.nameZh,
          Offset(center.dx - 18, labelY),
          dim ? FactionColors.gold.withValues(alpha: 0.35) : FactionColors.gold,
          11,
        );
        _drawCostStars(canvas, Offset(center.dx - 18, labelY + 16), card.cost);
      }
    }

    // Full-color card pinned on the gold 落點. Shadow merges here on arrival (合體).
    if (selectedIndex != null && pinnedMarchAt(selectedIndex!)) {
      final i = selectedIndex!;
      final card = field[i];
      final cardAt = dragTo!;
      _drawCardLikeToken(
        canvas,
        cardAt,
        card,
        index: i,
        cardW: tokenSize.width,
        cardH: tokenSize.height,
        selected: true,
        isEnemy: false,
        dim: false,
        pulseOwn: tutorialOwnIndex == i && t != null && t.session == TutorialSession.session1,
      );
      final labelY = cardAt.dy + tokenSize.height / 2 + 4;
      _drawText(canvas, card.nameZh, Offset(cardAt.dx - 18, labelY), FactionColors.gold, 11);
      _drawCostStars(canvas, Offset(cardAt.dx - 18, labelY + 16), card.cost);
    }

    // 亂戰 is a local stamp + HP chip. Never a full-screen cut-in.
    if (_ransenUnits.isNotEmpty && tutorial?.shotPassMode != true) {
      var sx = 0.0;
      var sy = 0.0;
      var n = 0;
      for (final i in _ransenUnits) {
        if (i < 0 || i >= fieldPos.length) continue;
        final c = tokenCenter(i);
        sx += c.dx;
        sy += c.dy;
        n++;
        final hp01 = (debugUnitHp(i) / kRansenMaxHp).clamp(0.0, 1.0);
        final bar = Rect.fromCenter(
          center: Offset(c.dx, c.dy + tokenSize.height / 2 + 8),
          width: 36,
          height: 4,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(bar, const Radius.circular(2)),
          Paint()..color = const Color(0xFF3E2723),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(bar.left, bar.top, bar.width * hp01, bar.height),
            const Radius.circular(2),
          ),
          Paint()..color = const Color(0xFFEF9A9A),
        );
      }
      if (n > 0) {
        _drawFatFloatText(
          canvas,
          '亂戰',
          Offset(sx / n, sy / n - tokenSize.height * 0.72),
          fontSize: 16,
        );
      }
    }

    // BINARY charging caption on field — gold only, never cyan rings/arcs.
    if (!auraActive) {
      final travel01 = (_dragTravelDist / kChargeTravelNeed).clamp(0.0, 1.0);
      final captionIdx = tutorialOwnIndex ??
          (selectedIndex != null && selectedIndex! < field.length && !isEnemyAt(selectedIndex!)
              ? selectedIndex
              : null);
      if (travel01 > kChargeRingShowTravel01 && captionIdx != null) {
        final oc = tokenCenter(captionIdx);
        _drawFatFloatText(
          canvas,
          '蓄緊 ${(travel01 * 100).round()}%',
          Offset(oc.dx, oc.dy - tokenSize.height / 2 - 22),
          fontSize: 18,
        );
      }
    }

    // Design lock: NO floating「突撃」/「迎擊」buttons.
    // Charge = drag far → aura → collide (auto flash). Intercept = tip always on × enemy aura (auto).

    // Temporary charge-pipeline debug (travel% / aura on) — Bosco fail triage.
    if (t != null && t.session == TutorialSession.session1) {
      final travel01 = (_dragTravelDist / kChargeTravelNeed).clamp(0.0, 1.0);
      final pct = (travel01 * 100).round();
      final aura = auraActive;
      // Match field look: off / charging (travel fill) / ON (auraActive).
      final auraDbg = aura
          ? 'ON'
          : (travel01 > kChargeRingShowTravel01 ? 'charging' : 'off');
      _drawText(
        canvas,
        'DBG travel $pct%  aura $auraDbg  lag ${debugWaypointLagPx.round()}  ${t.s1.name}',
        Offset(12, fieldTop + 36),
        const Color(0xFF00E5FF),
        11,
      );
    }

    if (_hitFlashLeft > 0 && _hitFlashIndex != null && _hitFlashIndex! < field.length) {
      final c = tokenCenter(_hitFlashIndex!);
      if (_hitFlashLabel.isNotEmpty) {
        // CHARGE punch / 氣勢 snap / intercept — never show 「突撃」 unless aura+contact.
        final isChargePunch = _hitFlashLabel == '突撃';
        final isKisei = _hitFlashLabel == '氣勢';
        _drawFatFloatText(
          canvas,
          _hitFlashLabel,
          Offset(c.dx, c.dy - (isChargePunch ? 92 : isKisei ? 86 : 78)),
          alpha: 1,
          fontSize: isChargePunch ? 36 : isKisei ? 32 : 22,
        );
        if (!isKisei) {
          // 氣勢 uses snapped charge rings (already on). Extra cyan circle is 突撃/迎擊 only.
          canvas.drawCircle(
            c,
            isChargePunch ? 58 : 42,
            Paint()
              ..color = const Color(0xFF80DEEA).withValues(
                alpha: (isChargePunch
                        ? (_hitFlashLeft / kChargeFlashSec) * 0.85
                        : (_hitFlashLeft * 2))
                    .clamp(0, isChargePunch ? 0.85 : 0.55),
              )
              ..style = PaintingStyle.stroke
              ..strokeWidth = isChargePunch ? 5.5 : 3.5,
          );
        }
      } else {
        // MELEE light bump — soft ring only, never 「突撃」
        canvas.drawCircle(
          c,
          30,
          Paint()
            ..color = const Color(0xFFFFFFFF).withValues(alpha: (_hitFlashLeft * 1.6).clamp(0, 0.28))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
      }
    }

    if (_stratLeft > 0 && _stratAt != null) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, fieldTop, w, h - fieldTop));
      _drawStratagemBurst(canvas, _stratAt!, _stratLeft / FxWindows.toSeconds(FxWindows.strategyFxMaxC));
      canvas.restore();
    }

    if (_returnFlashLeft > 0) {
      final a = (_returnFlashLeft / 0.6).clamp(0.0, 1.0);
      canvas.drawRect(
        Rect.fromLTWH(0, fieldTop, w, h - fieldTop),
        Paint()..color = FactionColors.gold.withValues(alpha: 0.10 * a),
      );
      _drawFatFloatText(canvas, '返城', Offset(w * 0.5, fieldTop + 56), alpha: a);
    }

    if (_shakeLeft > 0) {
      canvas.restore();
    }

    final prove = visualVerifyCaption;
    if (prove != null && prove.isNotEmpty) {
      _drawFatFloatText(
        canvas,
        prove,
        Offset(w * 0.5, fieldTop + 22),
        fontSize: 18,
      );
    }
  }

  /// Removed: floating charge/intercept buttons (Design/UIUX lock).
  Rect floatingActionHitRect(String label) => Rect.zero;

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    final d = b - a;
    final len = d.distance;
    if (len < 1) return;
    final dir = d / len;
    for (double t = 0; t < len; t += 10) {
      final s = a + dir * t;
      final e = a + dir * math.min(t + 5, len);
      canvas.drawLine(s, e, paint);
    }
  }

  /// Gold dashed arrow + soft gold landing disc — waypoint / 落點 guide.
  /// Distinct from cyan concentric charge rings (Design soft-fail lock).
  /// [ghostTrail]: in-transit path stays low-opacity so the body is not the destination.
  void _drawGoldWaypointGuide(
    Canvas canvas,
    Offset from,
    Offset to, {
    bool drawLanding = true,
    bool ghostTrail = false,
    bool labelLanding = false,
  }) {
    const gold = FactionColors.gold;
    final trailAlpha = ghostTrail ? 0.28 : 0.75;
    final arrowAlpha = ghostTrail ? 0.36 : 0.90;
    if (ghostTrail) {
      canvas.drawLine(
        from,
        to,
        Paint()
          ..color = gold.withValues(alpha: 0.12)
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round,
      );
    }
    _drawDashedLine(canvas, from, to, gold.withValues(alpha: trailAlpha));
    final d = to - from;
    final len = d.distance;
    if (len > 8) {
      final dir = d / len;
      final perp = Offset(-dir.dy, dir.dx);
      final tip = to;
      final left = tip - dir * 14 + perp * 7;
      final right = tip - dir * 14 - perp * 7;
      final arrow = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(right.dx, right.dy)
        ..close();
      canvas.drawPath(arrow, Paint()..color = gold.withValues(alpha: arrowAlpha));
    }
    if (drawLanding) {
      canvas.drawCircle(to, 18, Paint()..color = gold.withValues(alpha: 0.14));
      canvas.drawCircle(
        to,
        18,
        Paint()
          ..color = gold.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
      canvas.drawCircle(to, 5, Paint()..color = gold.withValues(alpha: 0.85));
      if (labelLanding) {
        _drawText(canvas, '落點', Offset(to.dx - 14, to.dy + 22), gold.withValues(alpha: 0.75), 12);
      }
    }
  }


  void _drawFieldLacquer(Canvas canvas, Rect rect) {
    final img = _fieldLacquer;
    if (img == null) return;
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    // Cover-fit texture only (no baked perspective grid — ortho drawn in code).
    final scale = math.max(rect.width / src.width, rect.height / src.height);
    final dw = src.width * scale;
    final dh = src.height * scale;
    final dx = rect.left + (rect.width - dw) / 2;
    final dy = rect.top + (rect.height - dh) / 2;
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawImageRect(
      img,
      src,
      Rect.fromLTWH(dx, dy, dw, dh),
      Paint()..filterQuality = FilterQuality.medium,
    );
    // Soft vignette so gold tokens separate from field.
    canvas.drawRect(rect, Paint()..color = const Color(0xFF000000).withValues(alpha: 0.18));
    canvas.restore();
  }

  /// Flat orthographic gold grid on operable field — parallel lines, equal cells, no vanishing point.
  void _drawOrthoFieldGrid(Canvas canvas, Rect rect) {
    const cols = 8;
    const rows = 10;
    const inset = 10.0;
    final left = rect.left + inset;
    final right = rect.right - inset;
    final top = rect.top + inset;
    final bottom = rect.bottom - inset;
    final cellW = (right - left) / cols;
    final cellH = (bottom - top) / rows;
    final line = Paint()
      ..color = FactionColors.gold.withValues(alpha: 0.42)
      ..strokeWidth = 1.15
      ..isAntiAlias = true;
    final soft = Paint()
      ..color = FactionColors.gold.withValues(alpha: 0.16)
      ..strokeWidth = 2.4
      ..isAntiAlias = true;
    for (var r = 0; r <= rows; r++) {
      final y = top + r * cellH;
      canvas.drawLine(Offset(left, y), Offset(right, y), soft);
      canvas.drawLine(Offset(left, y), Offset(right, y), line);
    }
    for (var c = 0; c <= cols; c++) {
      final x = left + c * cellW;
      canvas.drawLine(Offset(x, top), Offset(x, bottom), soft);
      canvas.drawLine(Offset(x, top), Offset(x, bottom), line);
    }
    final dot = Paint()..color = FactionColors.gold.withValues(alpha: 0.7);
    for (var r = 0; r <= rows; r++) {
      for (var c = 0; c <= cols; c++) {
        canvas.drawCircle(Offset(left + c * cellW, top + r * cellH), 1.6, dot);
      }
    }
  }

  /// Bottom own-castle band (drag-in = 返城, drag-out = 出陣). Lacquer + pale gold.
  void _drawOwnCastleBand(Canvas canvas, Rect fieldRect) {
    final band = castleBandRect;
    // Fill
    canvas.drawRect(band, Paint()..color = const Color(0xFF0C0C0C));
    // Top pale-gold edge
    final edge = Paint()
      ..color = FactionColors.gold.withValues(alpha: castleBandHot ? 0.95 : 0.45)
      ..strokeWidth = castleBandHot ? 2.6 : 1.4;
    canvas.drawLine(Offset(band.left + 8, band.top), Offset(band.right - 8, band.top), edge);
    // Soft inner wash when hot
    if (castleBandHot) {
      canvas.drawRect(
        band,
        Paint()..color = FactionColors.gold.withValues(alpha: 0.14),
      );
      canvas.drawRect(
        Rect.fromLTWH(band.left, band.top, band.width, 3),
        Paint()..color = FactionColors.gold.withValues(alpha: 0.55),
      );
    }
    // Corner ticks
    final tick = Paint()
      ..color = FactionColors.gold.withValues(alpha: castleBandHot ? 0.85 : 0.35)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(band.left + 10, band.top + 6), Offset(band.left + 10, band.top + 18), tick);
    canvas.drawLine(Offset(band.right - 10, band.top + 6), Offset(band.right - 10, band.top + 18), tick);
    _drawText(
      canvas,
      castleBandHot ? '歸城區' : '己城',
      Offset(16, band.top + 10),
      FactionColors.gold.withValues(alpha: castleBandHot ? 0.95 : 0.55),
      12,
    );
  }

  void _drawLacquerGrain(Canvas canvas, Rect rect, {double alpha = 0.12}) {
    final paint = Paint()
      ..color = FactionColors.gold.withValues(alpha: alpha * 0.28)
      ..strokeWidth = 1;
    for (var i = 0; i < 10; i++) {
      final y = rect.top + (i + 1) * (rect.height / 11);
      canvas.drawLine(Offset(rect.left + 8, y), Offset(rect.right - 8, y), paint);
    }
  }

  void _drawCastleRaceBars(Canvas canvas, double w, double fieldTop) {
    // Thicker dual castle bars sitting on the mid divider (does not block drag).
    final band = Rect.fromLTWH(0, fieldTop - 22, w, 22);
    canvas.drawRect(band, Paint()..color = const Color(0xFF0C0C0C));
    canvas.drawLine(
      Offset(0, fieldTop),
      Offset(w, fieldTop),
      Paint()
        ..color = FactionColors.gold
        ..strokeWidth = 2.2,
    );
    const barH = 10.0;
    final left = Rect.fromLTWH(16, fieldTop - 16, (w * 0.38), barH);
    final right = Rect.fromLTWH(w - 16 - (w * 0.38), fieldTop - 16, (w * 0.38), barH);
    canvas.drawRRect(RRect.fromRectAndRadius(left, const Radius.circular(3)), Paint()..color = const Color(0xFF2A2A2A));
    canvas.drawRRect(RRect.fromRectAndRadius(right, const Radius.circular(3)), Paint()..color = const Color(0xFF2A2A2A));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(left.left, left.top, left.width * ownCastle.clamp(0, 1), barH), const Radius.circular(3)),
      Paint()..color = FactionColors.shu,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(right.left, right.top, right.width * enemyCastle.clamp(0, 1), barH), const Radius.circular(3)),
      Paint()..color = FactionColors.wei,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(left, const Radius.circular(3)),
      Paint()
        ..color = FactionColors.gold.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(right, const Radius.circular(3)),
      Paint()
        ..color = FactionColors.gold.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    _drawText(canvas, '己城', Offset(left.left, left.top - 14), FactionColors.gold, 11);
    _drawText(canvas, '敵城', Offset(right.left, right.top - 14), FactionColors.gold, 11);
  }

  /// Top watch: both sides in frame — live field position / facing / aura every frame.
  void _drawWatchFullField(Canvas canvas, Rect band) {
    final t = tutorial;
    _drawWatchPerspectiveLane(canvas, band);

    final ownIdx = tutorialOwnIndex ??
        (fieldIsEnemy.isEmpty ? null : fieldIsEnemy.indexWhere((e) => !e));
    final enemyIdx = tutorialEnemyIndex ??
        (fieldIsEnemy.isEmpty ? null : fieldIsEnemy.indexWhere((e) => e));
    final ownSafe = (ownIdx != null && ownIdx >= 0 && ownIdx < fieldPos.length) ? ownIdx : null;
    final enemySafe =
        (enemyIdx != null && enemyIdx >= 0 && enemyIdx < fieldPos.length) ? enemyIdx : null;

    final ownFallback = Offset(band.width * 0.34, band.top + band.height * 0.72);
    final enemyFallback = Offset(band.width * 0.62, band.top + band.height * 0.38);
    final ownField = ownSafe != null ? fieldPos[ownSafe] : ownFallback;
    final enemyField = enemySafe != null ? fieldPos[enemySafe] : enemyFallback;
    final ownC = ownSafe != null ? mapFieldToWatch(ownField, band) : ownFallback;
    final enemyC = enemySafe != null ? mapFieldToWatch(enemyField, band) : enemyFallback;
    final ownScale = (1.0 - 0.28 * watchDepth01(ownField)).clamp(0.68, 1.0);
    final enemyScale = (0.82 - 0.22 * watchDepth01(enemyField)).clamp(0.55, 0.82);

    var kind = watchKind;
    if (t != null) {
      if (t.session == TutorialSession.session1) {
        kind = AWindowKind.charge;
      } else if (t.session == TutorialSession.session2) {
        kind = AWindowKind.intercept;
      }
    }

    switch (kind) {
      case AWindowKind.charge:
        final travel01 = (_dragTravelDist / kChargeTravelNeed).clamp(0.0, 1.0);
        final match01 = (_matchChargeIndex != null ? _matchChargeC : 0.0).clamp(0.0, 1.0);
        final live01 = math.max(travel01, match01);
        // BINARY: Watch mirrors field. Charging = ZERO cyan. Lit = SNAP thick rings.
        if (auraActive) {
          _drawChargeRings(
            canvas,
            ownC,
            52 * ownScale,
            const Color(0xFF00E5FF),
            whiteCore: true,
            facing: ownFacing,
            fullyLit: true,
          );
        } else if (live01 > kChargeRingShowTravel01) {
          _drawText(
            canvas,
            '蓄緊 ${(live01 * 100).round()}%',
            Offset(ownC.dx - 22, ownC.dy - 28),
            FactionColors.gold,
            11,
          );
        }
        final showEnemyCharge = (t != null && t.enemyAuraVisible) ||
            (t == null &&
                _matchEnemyChargeIndex != null &&
                _matchEnemyChargeC >= 1.0);
        if (showEnemyCharge) {
          _drawChargeRings(
            canvas,
            enemyC,
            32 * enemyScale,
            const Color(0xFF00E5FF).withValues(alpha: 0.85),
            whiteCore: true,
            facing: enemyFacing,
            fullyLit: true,
          );
        }
        break;
      case AWindowKind.intercept:
        final retractSpear = ownSafe != null &&
            ownSafe < field.length &&
            field[ownSafe].troop == TroopType.spear &&
            !spearTipExtendedAt(ownSafe);
        if (!retractSpear) {
          _drawInterceptStance(canvas, ownC, 42 * ownScale, const Color(0xFF26C6DA), facing: ownFacing);
        }
        if (t == null || t.enemyAuraVisible) {
          _drawChargeRings(
            canvas,
            enemyC,
            26 * enemyScale,
            const Color(0xFF00E5FF).withValues(alpha: 0.8),
            whiteCore: true,
            facing: enemyFacing,
          );
        }
        break;
      case AWindowKind.bow:
        _drawBowWindup(canvas, ownC, ownC.dx + 70, const Color(0xFFFFAB40), progress01: 0.85, ready: false);
        break;
      case AWindowKind.stratagem:
        break;
    }

    Color ownFill = FactionColors.shu;
    Color enemyFill = FactionColors.wei;
    var ownTroop = TroopType.cavalry;
    var enemyTroop = TroopType.cavalry;
    if (ownSafe != null && ownSafe < field.length) {
      ownFill = _tokenFill(field[ownSafe]);
      ownTroop = field[ownSafe].troop;
    }
    if (enemySafe != null && enemySafe < field.length) {
      enemyFill = _tokenFill(field[enemySafe]);
      enemyTroop = field[enemySafe].troop;
    }

    // Watch solid unit is march progress (shadow / fieldPos): position, facing, 氣勢.
    // It is not pinned on the field 落點.
    _drawMiniToken(canvas, ownC, ownFill, enemy: false, scale: ownScale, troop: ownTroop);
    _drawMiniToken(canvas, enemyC, enemyFill, enemy: true, scale: enemyScale, troop: enemyTroop);
    _drawFacingArrow(canvas, ownC, ownFacing, FactionColors.gold);
    _drawFacingArrow(canvas, enemyC, enemyFacing, const Color(0xFFFFF59D), enemyHard: true);
    if (showAWindowDebugLabels) {
      final label = switch (kind) {
        AWindowKind.charge => '突撃氣場 蓄勢',
        AWindowKind.intercept => '迎擊 槍尖常駐',
        AWindowKind.bow => '弓停射 蓄勢',
        AWindowKind.stratagem => '計略',
      };
      _drawText(canvas, label, Offset(16, band.top + 42), const Color(0xFF80DEEA), 12);
    }
  }

  /// Simple perspective battlefield lane for top watch (both sides readable).
  void _drawWatchPerspectiveLane(Canvas canvas, Rect band) {
    final horizonY = band.top + band.height * 0.22;
    final vanishing = Offset(band.width * 0.5, horizonY);
    // Sky wash
    canvas.drawRect(
      Rect.fromLTRB(band.left, band.top, band.right, horizonY),
      Paint()..color = const Color(0xFF1A2228),
    );
    // Ground trapezoid (road)
    final ground = Path()
      ..moveTo(band.left - 20, band.bottom)
      ..lineTo(band.right + 20, band.bottom)
      ..lineTo(vanishing.dx + band.width * 0.08, horizonY)
      ..lineTo(vanishing.dx - band.width * 0.08, horizonY)
      ..close();
    canvas.drawPath(ground, Paint()..color = const Color(0xFF2A2118));
    // Center lane lines converging
    final lanePaint = Paint()
      ..color = FactionColors.gold.withValues(alpha: 0.35)
      ..strokeWidth = 1.6;
    canvas.drawLine(Offset(band.width * 0.42, band.bottom - 4), vanishing, lanePaint);
    canvas.drawLine(Offset(band.width * 0.58, band.bottom - 4), vanishing, lanePaint);
    // Side rails
    final rail = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(band.width * 0.08, band.bottom), Offset(vanishing.dx - 18, horizonY), rail);
    canvas.drawLine(Offset(band.width * 0.92, band.bottom), Offset(vanishing.dx + 18, horizonY), rail);
    // Far hills / depth cue
    canvas.drawOval(
      Rect.fromCenter(center: Offset(band.width * 0.5, horizonY - 6), width: band.width * 0.7, height: 18),
      Paint()..color = const Color(0xFF0E1418).withValues(alpha: 0.8),
    );
    _drawText(canvas, '遠', Offset(band.width * 0.72, horizonY + 4), Colors.white38, 10);
    _drawText(canvas, '近', Offset(band.width * 0.12, band.bottom - 18), Colors.white38, 10);
  }

  void _drawMiniToken(
    Canvas canvas,
    Offset c,
    Color fill, {
    required bool enemy,
    double scale = 1,
    TroopType troop = TroopType.cavalry,
  }) {
    final w = 34.0 * scale;
    final h = 42.0 * scale;
    final rect = RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: w, height: h), Radius.circular(6 * scale));
    // Lacquer card + thin faction stripe (not a flat color block body)
    canvas.drawRRect(rect, Paint()..color = const Color(0xFF161616));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(c.dx - w / 2, c.dy - h / 2, w, h * 0.22), Radius.circular(5 * scale)),
      Paint()..color = fill.withValues(alpha: 0.95),
    );
    if (enemy) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: w + 14, height: h + 14), Radius.circular(9 * scale)),
        Paint()
          ..color = const Color(0xFFECEFF1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2 * scale,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: w + 8, height: h + 8), Radius.circular(8 * scale)),
        Paint()
          ..color = const Color(0xFF000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.5 * scale,
      );
    }
    canvas.drawRRect(
      rect,
      Paint()
        ..color = enemy ? const Color(0xFF000000) : FactionColors.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = enemy ? 3.8 * scale : 2.4 * scale,
    );
    if (enemy) {
      canvas.drawRRect(
        rect,
        Paint()
          ..color = const Color(0xFFB0BEC5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4 * scale,
      );
    }
    // Weapons-only glyph
    _drawWeapon(canvas, c.translate(0, 2 * scale), troop, Colors.white.withValues(alpha: 0.9), scale: 0.85 * scale);
  }

  void _drawCardLikeToken(
    Canvas canvas,
    Offset center,
    CardFace card, {
    required int index,
    required double cardW,
    required double cardH,
    required bool selected,
    required bool isEnemy,
    required bool dim,
    required bool pulseOwn,
    double opacity = 1,
  }) {
    // Design 5:8 gold-border cards (real-card 54×86).
    final dest = Rect.fromCenter(center: center, width: cardW, height: cardH);
    final rrect = RRect.fromRectAndRadius(dest, Radius.circular(cardW * 0.08));
    final ghost = opacity < 0.999;
    if (ghost) {
      canvas.saveLayer(dest.inflate(14), Paint()..color = Color.fromRGBO(255, 255, 255, opacity));
    }

    final hasAnim = troopSprites.has(card.troop);
    if (hasAnim) {
      // Prefer readable SpriteAnimation on field; 5:8 chrome under / wraps.
      canvas.drawRRect(
        rrect,
        Paint()..color = const Color(0xFF141414).withValues(alpha: dim ? 0.45 : 0.97),
      );
      // Dim 5:8 weapon token as under-chrome (not the hero read).
      _drawTokenCardFace(canvas, dest, card, dim: true);
      final pose = _poseForToken(index, card, isEnemy: isEnemy);
      // Cover-fit anim into card so spear tip glow / body stay readable at 0.10 width.
      final inset = dest.deflate(cardW * 0.04);
      troopSprites.render(
        canvas,
        inset,
        card.troop,
        pose,
        opacity: dim ? 0.5 : 1.0,
        fit: BoxFit.cover,
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = FactionColors.gold.withValues(alpha: dim ? 0.45 : 0.95)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4,
      );
    } else {
      final painted = _drawTokenCardFace(canvas, dest, card, dim: dim);
      if (!painted) {
        // Procedural 5:8 lacquer + gold border + weapon fallback.
        final base = _tokenFill(card);
        final fill = dim ? base.withValues(alpha: 0.35) : base;
        canvas.drawRRect(rrect, Paint()..color = const Color(0xFF141414).withValues(alpha: dim ? 0.4 : 0.96));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(dest.left, dest.top, cardW, cardH * 0.18),
            Radius.circular(cardW * 0.07),
          ),
          Paint()..color = fill,
        );
        _drawWeapon(
          canvas,
          Offset(center.dx, center.dy + cardH * 0.02),
          card.troop,
          dim ? Colors.white38 : Colors.white,
          scale: (cardW / 54.0) * 1.1,
        );
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = FactionColors.gold
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4,
        );
      }
    }

    if (isEnemy) {
      // Faction ID = hard outline color only. Same cardW/cardH as own — NEVER scale
      // or inflate the chrome (old +20/+12 halos read as a bigger enemy token at 0.10).
      final hard = RRect.fromRectAndRadius(
        dest.inflate(2.0),
        Radius.circular(cardW * 0.09),
      );
      canvas.drawRRect(
        hard,
        Paint()
          ..color = const Color(0xFFECEFF1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4,
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = const Color(0xFF0A0A0A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.6,
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = const Color(0xFFB0BEC5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }

    final bowWinding = !isEnemy &&
        selected &&
        card.troop == TroopType.bow &&
        _bowWindupIndex != null &&
        selectedIndex == _bowWindupIndex;
    if (selected && !isEnemy && !bowWinding) {
      // Selection ring tracks card (Design: 跟卡縮) — keep ≤+4 so own ≠ bigger than enemy.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: cardW + 4, height: cardH + 4),
          Radius.circular(cardW * 0.10),
        ),
        Paint()
          ..color = FactionColors.gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8,
      );
    }
    if (pulseOwn) {
      final pulse = 0.5 + 0.5 * math.sin(_pulse * 3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center,
            width: cardW + 6 + pulse * 2,
            height: cardH + 6 + pulse * 2,
          ),
          Radius.circular(cardW * 0.11),
        ),
        Paint()
          ..color = FactionColors.gold.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }
    if (ghost) canvas.restore();
  }

  /// Single-card 5:8 gold-frame crops inside 1280×720 canvases (Design token-*-58).
  static Rect _tokenCard58Src(TroopType troop) {
    switch (troop) {
      case TroopType.spear:
        return const Rect.fromLTWH(436, 12, 412, 676);
      case TroopType.infantry:
      case TroopType.siege:
        return const Rect.fromLTWH(444, 8, 396, 690);
      case TroopType.bow:
        return const Rect.fromLTWH(762, 12, 382, 692);
      case TroopType.cavalry:
        // No single cavalry-58 yet — moodboard card 4 (CAVALRY LANCE TIP).
        return const Rect.fromLTWH(970, 52, 270, 476);
    }
  }

  ui.Image? _tokenImageFor(TroopType troop) {
    switch (troop) {
      case TroopType.spear:
        return _tokenSpear58;
      case TroopType.infantry:
      case TroopType.siege:
        return _tokenDao58;
      case TroopType.bow:
        return _tokenBow58;
      case TroopType.cavalry:
        return _tokenCards58;
    }
  }

  /// Moodboard 5:8 crops: SPEAR / DAO / BOW / CAVALRY (fallback).
  static Rect _tokenCard58MoodSrc(TroopType troop) {
    switch (troop) {
      case TroopType.spear:
        return const Rect.fromLTWH(45, 52, 267, 475);
      case TroopType.infantry:
      case TroopType.siege:
        return const Rect.fromLTWH(349, 52, 266, 508);
      case TroopType.bow:
        return const Rect.fromLTWH(629, 38, 326, 522);
      case TroopType.cavalry:
        return const Rect.fromLTWH(970, 52, 270, 476);
    }
  }

  /// Draw 5:8 token face from Design *-58 art (cover-fit). False → procedural.
  bool _drawTokenCardFace(Canvas canvas, Rect dest, CardFace card, {required bool dim}) {
    final troop = card.troop;
    var img = _tokenImageFor(troop);
    var src = _tokenCard58Src(troop);
    if (img == null && _tokenCards58 != null) {
      img = _tokenCards58;
      src = _tokenCard58MoodSrc(troop);
    }
    if (img == null) return false;
    final scale = math.max(dest.width / src.width, dest.height / src.height);
    final dw = src.width * scale;
    final dh = src.height * scale;
    final dx = dest.left + (dest.width - dw) / 2;
    final dy = dest.top + (dest.height - dh) / 2;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(dest, Radius.circular(dest.width * 0.08)));
    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true
      ..color = Color.fromRGBO(255, 255, 255, dim ? 0.42 : 1.0);
    canvas.drawImageRect(img, src, Rect.fromLTWH(dx, dy, dw, dh), paint);
    canvas.restore();
    canvas.drawRRect(
      RRect.fromRectAndRadius(dest, Radius.circular(dest.width * 0.08)),
      Paint()
        ..color = FactionColors.gold.withValues(alpha: dim ? 0.45 : 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    return true;
  }

  /// Active SpriteAnimation pose for a field token (never blocks drag/buttons).
  TroopAnimPose _poseForToken(int index, CardFace card, {required bool isEnemy}) {
    if (debugForcePose != null && debugForcePoseIndex == index) {
      return debugForcePose!;
    }
    // March pose while a waypoint is committed, not only while the finger is down.
    if (dragTo != null && selectedIndex == index) return TroopAnimPose.move;
    if (_hitFlashLeft > 0 && _hitFlashIndex == index) return TroopAnimPose.attack;
    switch (card.troop) {
      case TroopType.spear:
        if (_ransenUnits.contains(index)) return TroopAnimPose.idle;
        final tipLive = (!isEnemy) && (
          (tutorial != null && tutorial!.session == TutorialSession.session2) ||
          (_matchSpearIndex == index) ||
          (_matchEnemyChargeIndex != null)
        );
        if (tipLive) return TroopAnimPose.attack;
        return TroopAnimPose.idle;
      case TroopType.cavalry:
        if (_matchChargeIndex == index || (isEnemy && _matchEnemyChargeIndex == index)) {
          return TroopAnimPose.attack;
        }
        return TroopAnimPose.idle;
      case TroopType.bow:
        if (_ransenUnits.contains(index)) return TroopAnimPose.idle;
        if (_bowWindupIndex == index) {
          return _bowShotReady ? TroopAnimPose.attack : TroopAnimPose.move;
        }
        return TroopAnimPose.idle;
      case TroopType.infantry:
      case TroopType.siege:
        return TroopAnimPose.idle;
    }
  }

  void _drawFacingArrow(Canvas canvas, Offset c, double facing, Color color, {bool enemyHard = false}) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(facing);
    // Enemy: ALWAYS white/yellow tip — never faction fill alone.
    final tipColor = enemyHard ? const Color(0xFFFFF59D) : color;
    final tipY = enemyHard ? -54.0 : -38.0;
    final baseY = enemyHard ? -28.0 : -22.0;
    final half = enemyHard ? 13.0 : 8.0;
    final path = Path()
      ..moveTo(0, tipY)
      ..lineTo(-half, baseY)
      ..lineTo(half, baseY)
      ..close();
    if (enemyHard) {
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6.0
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawLine(
        Offset(0, baseY + 2),
        const Offset(0, -2),
        Paint()
          ..color = const Color(0xFF000000)
          ..strokeWidth = 6.5
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawPath(path, Paint()..color = tipColor.withValues(alpha: 0.98));
    canvas.drawLine(
      Offset(0, baseY + 2),
      Offset(0, enemyHard ? -2 : -6),
      Paint()
        ..color = tipColor
        ..strokeWidth = enemyHard ? 4.0 : 2.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  void _drawFatFloatText(Canvas canvas, String text, Offset center, {double alpha = 1, double fontSize = 22}) {
    final style = TextStyle(
      color: Colors.white.withValues(alpha: alpha),
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.2,
      shadows: [
        Shadow(color: FactionColors.gold.withValues(alpha: alpha), blurRadius: 0, offset: const Offset(-1.5, 0)),
        Shadow(color: FactionColors.gold.withValues(alpha: alpha), blurRadius: 0, offset: const Offset(1.5, 0)),
        Shadow(color: FactionColors.gold.withValues(alpha: alpha), blurRadius: 0, offset: const Offset(0, -1.5)),
        Shadow(color: FactionColors.gold.withValues(alpha: alpha), blurRadius: 0, offset: const Offset(0, 1.5)),
        Shadow(color: FactionColors.gold.withValues(alpha: alpha * 0.8), blurRadius: 6),
      ],
    );
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  void _drawFieldTelegraph(
    Canvas canvas,
    Offset c,
    CardFace card,
    int index, {
    bool isOwn = false,
    bool isEnemy = false,
  }) {
    final t = tutorial;
    if (t != null && t.session == TutorialSession.session1 && isOwn) {
      // BINARY: cyan rings ONLY when auraActive. Charging = gold waypoint + 蓄緊 (render).
      if (auraActive) {
        _drawChargeRings(
          canvas,
          c,
          58.0,
          const Color(0xFF00E5FF),
          whiteCore: true,
          facing: ownFacing,
          fullyLit: true,
        );
      }
      return;
    }
    if (t != null && t.session == TutorialSession.session2) {
      if (isOwn && card.troop == TroopType.spear) {
        // Tip stays out for coaching, and retracts for the whole overlap (亂戰).
        if (spearTipExtendedAt(index)) {
          _drawInterceptStance(canvas, c, 44, const Color(0xFFB2EBF2).withValues(alpha: 0.88), facing: ownFacing);
        }
        return;
      }
      if (isEnemy && t.enemyAuraVisible) {
        _drawChargeRings(
          canvas,
          c,
          40,
          const Color(0xFF00E5FF).withValues(alpha: 0.8),
          whiteCore: true,
        );
        return;
      }
    }

    // Match / demo telegraph by troop
    switch (card.troop) {
      case TroopType.cavalry:
        // 「見環先撞」BINARY: cyan only when fully armed (auraActive). Mid-fill = no rings.
        if (_matchChargeIndex == index && auraActive) {
          _drawChargeRings(
            canvas,
            c,
            56.0,
            const Color(0xFF00E5FF),
            whiteCore: true,
            facing: ownFacing,
            fullyLit: true,
          );
        }
        // Enemy charge aura for intercept turn window — visible only when fully lit.
        if (isEnemy && _matchEnemyChargeIndex == index && _matchEnemyChargeC >= 1.0) {
          _drawChargeRings(
            canvas,
            c,
            42.0,
            const Color(0xFF00E5FF),
            whiteCore: true,
            facing: enemyFacing,
            fullyLit: true,
          );
        }
        break;
      case TroopType.spear:
        // Idle facing still shows tip glow (槍尖光常在) — retracted during 亂戰.
        if (!spearTipExtendedAt(index)) break;
        _drawInterceptStance(
          canvas,
          c,
          42,
          const Color(0xFFB2EBF2).withValues(alpha: 0.82),
          facing: ownFacing,
        );
        break;
      case TroopType.bow:
        // 亂戰: stop the shot vocabulary for as long as the bodies overlap.
        if (_ransenUnits.contains(index)) break;
        // FEEL bow-idle: show sheet only (no 蓄勢 clutter).
        if (debugForcePoseIndex == index && debugForcePose == TroopAnimPose.idle) {
          break;
        }
        final winding = _bowWindupIndex == index;
        final prog = winding ? (_bowWindupC / FxWindows.bowStopBeforeShotC).clamp(0.0, 1.0) : 0.35;
        final ready = winding && _bowShotReady;
        // Amber-cyan 蓄勢 (≠ gold select ring).
        _drawBowWindup(
          canvas,
          c,
          c.dx + 78,
          const Color(0xFFFFAB40).withValues(alpha: ready ? 0.98 : 0.82),
          progress01: prog,
          ready: ready,
        );
        break;
      default:
        break;
    }
  }

  void _drawChargeRings(
    Canvas canvas,
    Offset c,
    double baseR,
    Color color, {
    bool whiteCore = false,
    double facing = 0,
    /// BINARY: false = draw nothing. true = SNAP thick cyan-white full rings.
    bool fullyLit = true,
  }) {
    if (!fullyLit) return; // charging / mid-fill: no arcs, no faint rings, no aura-like cyan
    final t = (_pulse % 1.2) / 1.2;
    // Gold waypoint/landing disc stays separate (_drawGoldWaypointGuide).
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(facing);
    canvas.translate(-c.dx, -c.dy);

    // Fully lit SNAP: exaggerated thick cyan-white rings (eye-obvious vs 蓄緊).
    final baseA = (color.a > 0.01 ? color.a : 1.0).clamp(kChargeRingLitAlphaMin, 1.0);
    canvas.drawCircle(
      c,
      baseR + 8,
      Paint()..color = color.withValues(alpha: 0.22),
    );
    for (var i = 0; i < 5; i++) {
      final r = baseR + i * 14 + t * 22;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = color.withValues(alpha: (baseA - i * 0.07).clamp(0.50, 1.0))
          ..style = PaintingStyle.stroke
          ..strokeWidth = kChargeRingLitStroke - i * 0.4,
      );
    }
    if (whiteCore) {
      canvas.drawCircle(
        c,
        baseR - 2 + t * 8,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.78 + 0.18 * math.sin(_pulse * 5))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.6,
      );
    }
    final wave = Path()
      ..moveTo(c.dx - baseR * 0.95, c.dy - baseR * 0.05)
      ..quadraticBezierTo(c.dx, c.dy - baseR * 1.85, c.dx + baseR * 0.95, c.dy - baseR * 0.05);
    canvas.drawPath(
      wave,
      Paint()
        ..color = color.withValues(alpha: (baseA * 0.95).clamp(0.62, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.4,
    );
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 + _pulse * 0.35;
      canvas.drawLine(
        Offset(c.dx + math.cos(a) * (baseR - 6), c.dy + math.sin(a) * (baseR - 6)),
        Offset(c.dx + math.cos(a) * (baseR + 42), c.dy + math.sin(a) * (baseR + 42)),
        Paint()
          ..color = color.withValues(alpha: (baseA * 0.88).clamp(0.5, 0.98))
          ..strokeWidth = 3.1,
      );
    }
    canvas.restore();
  }


  void _drawInterceptStance(Canvas canvas, Offset c, double rx, Color color, {double facing = 0}) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(facing);
    canvas.translate(-c.dx, -c.dy);

    final oval = Rect.fromCenter(center: c, width: rx * 2.6, height: rx * 1.35);
    canvas.drawOval(
      oval,
      Paint()
        ..color = color.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6,
    );
    // Spear-tip wedge — bottom field larger via tipScale below.
    final wedgeScale = rx >= 40 ? 1.22 : 1.0;
    final wedge = Path()
      ..moveTo(c.dx, c.dy - 52 * wedgeScale)
      ..lineTo(c.dx - 28 * wedgeScale, c.dy + 10)
      ..lineTo(c.dx + 28 * wedgeScale, c.dy + 10)
      ..close();
    canvas.drawPath(wedge, Paint()..color = color.withValues(alpha: 0.5));
    canvas.drawPath(
      wedge,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    // Persistent spear tip / 槍尖光 — always on (idle facing too). Cyan-white + gold-lacquer (less neon green).
    final glow = 0.65 + 0.35 * math.sin(_pulse * 4);
    final tipScale = rx >= 40 ? 1.28 : (rx / 36.0).clamp(0.75, 1.05);
    final tip = Offset(c.dx, c.dy - 48 * tipScale);
    const cyanSoft = Color(0xFFB2EBF2);
    const cyanCore = Color(0xFFE0F7FA);
    canvas.drawCircle(tip, 30 * tipScale, Paint()..color = cyanSoft.withValues(alpha: 0.38 * glow));
    canvas.drawCircle(tip, 20 * tipScale, Paint()..color = cyanCore.withValues(alpha: 0.55 * glow));
    canvas.drawCircle(tip, 11 * tipScale, Paint()..color = Colors.white.withValues(alpha: 0.96));
    // Thin gold-lacquer rim — A-window palette, not neon green.
    canvas.drawCircle(
      tip,
      14 * tipScale,
      Paint()
        ..color = FactionColors.gold.withValues(alpha: 0.42 * glow)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 * tipScale,
    );
    canvas.drawLine(
      Offset(c.dx, c.dy + 26 * tipScale),
      Offset(c.dx, c.dy - 52 * tipScale),
      Paint()
        ..color = Color.lerp(color, cyanCore, 0.35)!.withValues(alpha: 0.92)
        ..strokeWidth = 4.2 * tipScale
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  /// Bow stop vocabulary: 蓄勢暈 (ground) + arrow aim preview + reticle — NOT gold select ring.
  /// [progress01] 0→1 over ~1C still; move cancels (郁即斷).
  void _drawBowWindup(Canvas canvas, Offset c, double aimX, Color color, {double progress01 = 0.55, bool ready = false}) {
    final p = progress01.clamp(0.0, 1.0);
    final glow = ready ? 1.0 : (0.5 + 0.5 * p);
    final amber = color;
    const cyan = Color(0xFF80DEEA);
    // Ground 蓄勢暈 — wide oval seal under feet (distinct from card select rect).
    final sealR = 28.0 + 22.0 * p;
    for (var i = 0; i < 3; i++) {
      final expand = i * 10.0 * (0.4 + 0.6 * p);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(c.dx, c.dy + 32),
          width: (sealR + expand) * 2.4,
          height: (sealR * 0.42 + expand * 0.35),
        ),
        Paint()
          ..color = (i.isEven ? amber : cyan).withValues(alpha: (0.22 - i * 0.05) * glow)
          ..style = PaintingStyle.stroke
          ..strokeWidth = ready ? 2.8 : (2.0 - i * 0.3),
      );
    }
    canvas.drawOval(
      Rect.fromCenter(center: Offset(c.dx, c.dy + 32), width: sealR * 2.1, height: sealR * 0.55),
      Paint()..color = amber.withValues(alpha: 0.18 * glow),
    );
    // Progress arc (not a fat gold card ring)
    const arcR = 34.0;
    final sweep = (math.pi * 1.6) * p;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: arcR),
      -math.pi * 0.8,
      sweep,
      false,
      Paint()
        ..color = cyan.withValues(alpha: 0.75 * glow)
        ..style = PaintingStyle.stroke
        ..strokeWidth = ready ? 3.2 : 2.4
        ..strokeCap = StrokeCap.round,
    );
    if (ready) {
      canvas.drawCircle(
        c,
        arcR + 4,
        Paint()
          ..color = cyan.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }
    // Solid arrow aim / preview line toward reticle (郁即斷 cancels this whole windup).
    final y = c.dy - 4;
    final start = Offset(c.dx + 18, y);
    final endX = c.dx + 22 + (aimX - c.dx - 22) * (0.4 + 0.6 * p);
    final end = Offset(endX, y);
    final shaft = Paint()
      ..color = amber.withValues(alpha: 0.55 + 0.45 * p)
      ..strokeWidth = ready ? 3.4 : 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, shaft);
    // Arrowhead
    final head = Path()
      ..moveTo(end.dx + 10, end.dy)
      ..lineTo(end.dx - 4, end.dy - 7)
      ..lineTo(end.dx - 4, end.dy + 7)
      ..close();
    canvas.drawPath(head, Paint()..color = amber.withValues(alpha: 0.7 + 0.3 * p));
    // Soft dashed ghost behind solid shaft
    final ghost = Paint()
      ..color = cyan.withValues(alpha: 0.35 * glow)
      ..strokeWidth = 1.2;
    for (var x = start.dx; x < end.dx - 8; x += 9) {
      canvas.drawLine(Offset(x, y + 6), Offset(x + 4, y + 6), ghost);
    }
    // Reticle
    final rt = Offset(aimX, y);
    final rr = ready ? 13.0 : 9.0;
    canvas.drawCircle(rt, rr, Paint()..color = cyan.withValues(alpha: 0.22 * glow));
    canvas.drawCircle(
      rt,
      rr,
      Paint()
        ..color = amber.withValues(alpha: 0.9 * glow)
        ..style = PaintingStyle.stroke
        ..strokeWidth = ready ? 2.4 : 1.7,
    );
    canvas.drawLine(Offset(rt.dx - rr - 5, rt.dy), Offset(rt.dx - rr + 2, rt.dy), shaft);
    canvas.drawLine(Offset(rt.dx + rr - 2, rt.dy), Offset(rt.dx + rr + 5, rt.dy), shaft);
    canvas.drawLine(Offset(rt.dx, rt.dy - rr - 5), Offset(rt.dx, rt.dy - rr + 2), shaft);
    canvas.drawLine(Offset(rt.dx, rt.dy + rr - 2), Offset(rt.dx, rt.dy + rr + 5), shaft);
  }

  void _drawStratagemBurst(Canvas canvas, Offset at, double life01) {
    // Translucent gold burst ≤1C — canvas paint only (field clip); never blocks 歸城/計略.
    final a = (life01.clamp(0.0, 1.0));
    final alpha = a * 0.55;
    // Fan / cone preview distinct from spear intercept wedge (opens right-up).
    final cone = Path()
      ..moveTo(at.dx + 8, at.dy)
      ..lineTo(at.dx + 110, at.dy - 56)
      ..lineTo(at.dx + 110, at.dy + 56)
      ..close();
    canvas.drawPath(cone, Paint()..color = FactionColors.gold.withValues(alpha: alpha * 0.55));
    canvas.drawPath(
      cone,
      Paint()
        ..color = FactionColors.gold.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    for (var i = 0; i < 3; i++) {
      final r = 22.0 + i * 14 + (1 - a) * 18;
      canvas.drawCircle(
        at,
        r,
        Paint()
          ..color = FactionColors.gold.withValues(alpha: alpha * (0.9 - i * 0.22))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6 - i * 0.4,
      );
    }
    canvas.drawCircle(
      at,
      16,
      Paint()..color = Colors.white.withValues(alpha: alpha * 0.45),
    );
    // Short 飛字 — readable coaching, not a full-screen cut-in.
    _drawText(
      canvas,
      '計略',
      Offset(at.dx + 36, at.dy - 64),
      FactionColors.gold.withValues(alpha: 0.55 + 0.45 * a),
      16,
    );
  }

  bool spawnCard(CardFace card, {bool enemy = false}) {
    if (field.length >= fieldMax) return false;
    final tw = size.x > 0 ? size.x * kTokenWidthFracOfField : 64.0;
    final i = field.length;
    field.add(card);
    fieldIsEnemy.add(enemy);
    fieldInCastle.add(false);
    fieldPos.add(Offset(48.0 + i * (tw * 1.35), watchH + 120));
    return true;
  }

  bool isEnemyAt(int i) => i >= 0 && i < fieldIsEnemy.length && fieldIsEnemy[i];

  int? hitTokenAt(Offset local) {
    if (local.dy < watchH) return null; // watch band read-only
    final hitR = tokenHitR;
    for (var i = 0; i < field.length; i++) {
      final c = tokenCenter(i);
      final dx = local.dx - c.dx;
      final dy = local.dy - c.dy;
      if (dx * dx + dy * dy <= hitR * hitR) return i;
      // Pinned full-color card is the visible grab target while the shadow marches.
      if (pinnedMarchAt(i)) {
        final p = dragTo!;
        final px = local.dx - p.dx;
        final py = local.dy - p.dy;
        if (px * px + py * py <= hitR * hitR) return i;
      }
    }
    return null;
  }

  void selectOrDetailAt(Offset local) {
    // Watch band is read-only — ignore taps in short watch
    if (local.dy < watchH) return;

    final t = tutorial;
    // No floating「突撃」/「迎擊」— charge/intercept resolve automatically.

    final i = hitTokenAt(local);
    if (i == null) {
      selectedIndex = null;
      return;
    }

    if (t != null && t.session == TutorialSession.session1) {
      if (i == tutorialOwnIndex) {
        selectedIndex = i;
        t.onSelectOwnCavalry();
        onTutorialChanged?.call();
        return;
      }
      // Enemy / dimmed: ignore select during coaching drag phases
      if (t.s1 == S1Phase.highlightSelect || t.s1 == S1Phase.dragGuide) return;
      if (isEnemyAt(i)) return;
    }

    // Session2: tap own spear to change facing once turn window open (or fail if early).
    if (t != null && t.session == TutorialSession.session2 && i == tutorialOwnIndex) {
      selectedIndex = i;
      t.onTapTurnFacing();
      onTutorialChanged?.call();
      return;
    }

    if (isEnemyAt(i)) {
      // Can highlight enemy for read, but no gold ownership ring actions
      selectedIndex = i;
      return;
    }

    // Match: tap spear to turn facing when intercept window open.
    if (t == null &&
        _matchSpearIndex != null &&
        i == _matchSpearIndex &&
        _matchEnemyChargeIndex != null) {
      selectedIndex = i;
      if (_matchTurnWindowOpen) {
        _matchFacingCorrect = true;
      }
      return;
    }

    // Match bow: select starts still windup; re-tap when ready fires first shot.
    if (t == null && field[i].troop == TroopType.bow) {
      if (_ransenUnits.contains(i)) {
        selectedIndex = i;
        _cancelBowWindup();
        return;
      }
      if (selectedIndex == i && _bowShotReady && !_bowDidShoot && _bowWindupIndex == i) {
        flashHit(i, '射');
        _bowDidShoot = true;
        _bowShotReady = false;
        return;
      }
      selectedIndex = i;
      _startBowWindup(i);
      return;
    }

    if (selectedIndex == i) {
      onRequestDetail?.call(field[i]);
    } else {
      selectedIndex = i;
      // Selecting non-bow cancels any bow windup.
      _cancelBowWindup();
    }
  }

  void _startBowWindup(int index) {
    _bowWindupIndex = index;
    _bowWindupC = 0;
    _bowShotReady = false;
    _bowDidShoot = false;
  }

  void _cancelBowWindup() {
    _bowWindupIndex = null;
    _bowWindupC = 0;
    _bowShotReady = false;
  }

  void panStart(Offset local) {
    if (local.dy < watchH) return;
    final t = tutorial;
    final i = hitTokenAt(local);
    if (i == null) return;
    if (isEnemyAt(i)) return; // enemy tokens not draggable
    if (t != null) {
      if (t.session != TutorialSession.session1) return;
      // Allow waitAura/hitCharge so stop→fade→drag-again rebuilds travel/aura.
      // (1c43843 fade left s1=waitAura; old gate blocked re-drag until full decay.)
      final canSteer = t.s1 == S1Phase.highlightSelect ||
          t.s1 == S1Phase.dragGuide ||
          t.s1 == S1Phase.waitAura ||
          t.s1 == S1Phase.hitCharge;
      if (!canSteer) return;
      if (i != tutorialOwnIndex) return;
      // Taisen-delta deferred: Research wanted clear-on-redirect.
      final keepMeter = _retargetKeepsMeter(i);
      selectedIndex = i;
      if (t.shotPassMode) {
        // FEEL/DEMO freezes own coaching — steer only, never reset shot pose.
      } else if (keepMeter) {
        // Mid-march retarget: keep travel, aura, and the coaching percent.
      } else if (t.s1 == S1Phase.highlightSelect || t.s1 == S1Phase.dragGuide) {
        t.onSelectOwnCavalry();
      } else {
        // Fresh march after a stop: rebuild from 0. Not a redirect.
        t.auraReady = false;
        t.didDragDrop = false;
        t.s1 = S1Phase.dragGuide;
        t.tipText = '蓄緊 0% — 跟住手指拖行，未亮唔好撞';
        t.tipSkippable = false;
      }
      dragging = true;
      if (!keepMeter) _resetMeterForFreshMarch();
      dragFrom = tokenCenter(i);
      dragTo = local;
      onTutorialChanged?.call();
      return;
    }
    // Free match: waypoint steer — unit walks at troop speed (no 1:1 glue).
    // Taisen-delta deferred: Research wanted clear-on-redirect.
    final keepMeter = _retargetKeepsMeter(i);
    selectedIndex = i;
    dragging = true;
    if (!keepMeter) _resetMeterForFreshMarch();
    dragFrom = tokenCenter(i);
    dragTo = local;
  }

  /// Same unit, waypoint still committed — a new 落點 is a retarget, not a stop.
  bool _retargetKeepsMeter(int i) => selectedIndex == i && dragTo != null;

  void _resetMeterForFreshMarch() {
    _dragTravelDist = 0;
    _lastDragDir = null;
    _meleeEnemyIndex = null;
    _chargeResolvedThisContact = false;
    _matchChargeIndex = null;
    _matchChargeC = 0;
  }

  void panUpdate(Offset local) {
    if (!dragging) return;
    // Finger = waypoint only; update() walks at troop speed + aura travel.
    final y = local.dy < watchH + 8 ? watchH + 8 : local.dy;
    dragTo = Offset(local.dx, y);
  }

  void panEnd(Offset local) {
    if (!dragging) return;
    dragging = false;
    final t = tutorial;
    final y = local.dy < watchH + 8 ? watchH + 8 : local.dy;
    // Release COMMITS the waypoint. Body keeps marching at troop speed.
    // Never snap/teleport the body to the finger.
    dragTo = Offset(local.dx, y);
    if (selectedIndex != null && selectedIndex! < fieldPos.length) {
      final i = selectedIndex!;
      final at = fieldPos[i];
      final bandHot = inCastleBand(at);

      if (t != null && t.session == TutorialSession.session1 && i == tutorialOwnIndex) {
        // Contact resolves in _tickRansen. Shot freeze still drops the waypoint below.
      } else if (t == null && !isEnemyAt(i)) {
        final wasInCastle = i < fieldInCastle.length && fieldInCastle[i];
        while (fieldInCastle.length <= i) {
          fieldInCastle.add(false);
        }
        if (bandHot) {
          // Body is already in 己城: park and drop the waypoint. Do not keep marching.
          _parkInCastle(i, at);
        } else {
          castleBandHot = inCastleBand(dragTo!);
          if (wasInCastle) {
            fieldInCastle[i] = false;
            flashHit(i, '出陣');
          }
          if (field[i].troop == TroopType.bow && _dragTravelDist > 8) {
            _cancelBowWindup();
          }
          // Cavalry: keep aura telegraph; engagement resolves on contact.
          // March target stays until arrival.
          if (field[i].troop == TroopType.cavalry && _dragTravelDist > kChargeRingShowTravel01 * kChargeTravelNeed) {
            _matchChargeIndex = i;
            _matchChargeC = (_dragTravelDist / kChargeTravelNeed).clamp(0.0, 1.0);
          }
        }
      }
    }
    dragFrom = null;
    // Captures stay frozen. Playfeel marches on the committed dragTo.
    if (t != null && t.shotPassMode) {
      dragTo = null;
      _lastDragDir = null;
    }
    _tickRansen(0);
  }

  void flashHit(int index, String label) {
    // 「氣勢」 must never overwrite an in-flight 「突撃」.
    if (label == '氣勢' && _hitFlashLeft > 0 && _hitFlashLabel == '突撃') {
      return;
    }
    _hitFlashIndex = index;
    _hitFlashLabel = label;
    // Big board text punch ≤1.0s, non-blocking (UIUX lock).
    // 「突撃」 uses kChargeFlashSec; 「氣勢」 is a short snap; others keep ~0.3C cap.
    final flashSec = switch (label) {
      '突撃' => kChargeFlashSec,
      '氣勢' => kKiseiFlashSec,
      _ => math.min(1.0, FxWindows.toSeconds(FxWindows.interceptHitFlashC)),
    };
    _hitFlashLeft = flashSec;
    _shakeLeft = label == '突撃'
        ? math.min(0.45, flashSec)
        : (label == '氣勢' ? 0.10 : flashSec);
  }

  /// MELEE: real contact without aura — light bump / micro-shake, NEVER big 「突撃」.
  void bumpMelee(int index) {
    _hitFlashIndex = index;
    _hitFlashLabel = ''; // no big combat text
    _hitFlashLeft = 0.22;
    _shakeLeft = 0.14;
  }

  /// Arrived / parked (waypoint gone). Sharp turns already zero travel in the walk.
  void _decayChargeAfterStop(double dt) {
    if (dragTo != null || _dragTravelDist <= 0) return;
    final coach = tutorial;
    _dragTravelDist = math.max(0.0, _dragTravelDist - 95.0 * dt);
    final fade01 = (_dragTravelDist / kChargeTravelNeed).clamp(0.0, 1.0);
    if (coach != null && coach.session == TutorialSession.session1) {
      if (fade01 < 1.0 &&
          (coach.auraReady || coach.s1 == S1Phase.hitCharge) &&
          coach.s1 != S1Phase.tipNext &&
          coach.s1 != S1Phase.passed) {
        final wasReady = coach.auraReady || coach.s1 == S1Phase.hitCharge;
        coach.auraReady = false;
        coach.didDragDrop = false;
        if (coach.s1 == S1Phase.hitCharge || coach.s1 == S1Phase.waitAura) {
          coach.s1 = S1Phase.waitAura;
        }
        if (wasReady) {
          const next = '停低氣勢散咗 — 再拖行重新累積光環';
          if (coach.tipText != next) {
            coach.tipText = next;
            coach.tipSkippable = false;
            onTutorialChanged?.call();
          }
        }
      }
      if (fade01 <= kChargeRingShowTravel01 &&
          (coach.s1 == S1Phase.waitAura || coach.s1 == S1Phase.dragGuide)) {
        if (coach.s1 != S1Phase.dragGuide) {
          coach.s1 = S1Phase.dragGuide;
          coach.didDragDrop = false;
          coach.auraReady = false;
          coach.tipText = '蓄緊 — 跟住手指拖行，未亮唔好撞';
          coach.tipSkippable = false;
          onTutorialChanged?.call();
        }
      }
    } else if (coach == null) {
      if (fade01 > kChargeRingShowTravel01) {
        _matchChargeIndex = selectedIndex ?? _matchChargeIndex;
        _matchChargeC = fade01;
      } else {
        _matchChargeIndex = null;
        _matchChargeC = 0;
      }
    }
  }

  void _ensureHpSlots() {
    while (_unitHp.length < field.length) {
      _unitHp.add(kRansenMaxHp);
    }
    if (_unitHp.length > field.length) {
      _unitHp.removeRange(field.length, _unitHp.length);
      _ransenUnits.removeWhere((i) => i >= field.length);
    }
  }

  bool _ownsLiveCharge(int i) {
    if (i < 0 || i >= field.length || isEnemyAt(i)) return false;
    if (field[i].troop != TroopType.cavalry) return false;
    if (selectedIndex == i || _matchChargeIndex == i) return true;
    final t = tutorial;
    return t != null &&
        t.session == TutorialSession.session1 &&
        tutorialOwnIndex == i;
  }

  /// Body overlap. Spear tip alone does not count — [inMeleeContact] is center distance.
  void _tickRansen(double dt) {
    // Frozen FEEL/DEMO poses keep their staged aura / bump. Playfeel never sets this.
    if (tutorial?.shotPassMode == true) return;
    _ensureHpSlots();

    final overlapping = <int>{};
    int? chargeAlly;
    int? chargeEnemy;
    for (var a = 0; a < field.length; a++) {
      if (isEnemyAt(a)) continue;
      for (var e = 0; e < field.length; e++) {
        if (!isEnemyAt(e)) continue;
        if (!inMeleeContact(tokenCenter(a), tokenCenter(e))) continue;
        overlapping.add(a);
        overlapping.add(e);
        final repeat = _chargeResolvedThisContact && _meleeEnemyIndex == e;
        if (chargeAlly == null && !repeat && _ownsLiveCharge(a) && auraActive) {
          chargeAlly = a;
          chargeEnemy = e;
        }
      }
    }

    if (chargeAlly != null && chargeEnemy != null) {
      _fireChargeHit(chargeAlly, chargeEnemy);
    }

    if (overlapping.isEmpty) {
      _ransenUnits.clear();
      _meleeEnemyIndex = null;
      _chargeResolvedThisContact = false;
      return;
    }

    _ransenUnits
      ..clear()
      ..addAll(overlapping);
    _suppressRansenActions();

    if (dt <= 0) return;
    for (final i in _ransenUnits) {
      if (i < 0 || i >= _unitHp.length) continue;
      _unitHp[i] = math.max(0.0, _unitHp[i] - kRansenTickPerSec * dt);
    }
  }

  /// 突撃 once, then the caller keeps the pair in 亂戰 if they still overlap.
  void _fireChargeHit(int ally, int enemy) {
    _chargeResolvedThisContact = true;
    _meleeEnemyIndex = enemy;
    final coach = tutorial;
    if (coach != null &&
        coach.session == TutorialSession.session1 &&
        ally == tutorialOwnIndex &&
        !coach.shotPassMode) {
      if (!coach.auraReady || !coach.didDragDrop) {
        coach.auraReady = true;
        coach.didDragDrop = true;
        coach.s1 = S1Phase.hitCharge;
      }
      flashHit(ally, '突撃');
      coach.onAutoCharge();
      onTutorialChanged?.call();
      coach.auraReady = false;
    } else {
      flashHit(ally, '突撃');
    }
    _matchChargeIndex = null;
    _matchChargeC = 0;
    _dragTravelDist = 0;
    _prevAuraActive = false;
  }

  /// Bow stops shooting, spear tip is a draw-time retract, cavalry drops a live aura.
  void _suppressRansenActions() {
    for (final i in _ransenUnits) {
      if (i < 0 || i >= field.length || isEnemyAt(i)) continue;
      switch (field[i].troop) {
        case TroopType.bow:
          if (_bowWindupIndex == i) _cancelBowWindup();
          break;
        case TroopType.cavalry:
          if (auraActive && _ownsLiveCharge(i)) {
            _matchChargeIndex = null;
            _matchChargeC = 0;
            _dragTravelDist = 0;
            _prevAuraActive = false;
            final coach = tutorial;
            if (coach != null && coach.session == TutorialSession.session1) {
              coach.auraReady = false;
            }
          }
          break;
        case TroopType.spear:
        case TroopType.infantry:
        case TroopType.siege:
          break;
      }
    }
  }

  /// Stratagem FX ≤1C on field; non-blocking (board stays tappable).
  /// [notifyTutorial] false = visual-only (shot modes / preview without advancing).
  void triggerStrategyFx({bool notifyTutorial = true}) {
    final t = tutorial;
    if (selectedIndex != null && selectedIndex! < field.length) {
      final i = selectedIndex!;
      _stratAt = tokenCenter(i);
      // Don't flash 迎擊 during pure stratagem coaching shot — tip is strategyOrReturn.
      if (notifyTutorial && field[i].troop == TroopType.spear) {
        flashHit(i, '迎擊');
      }
    } else if (tutorialOwnIndex != null) {
      _stratAt = tokenCenter(tutorialOwnIndex!);
    } else {
      _stratAt = Offset(size.x * 0.45, watchH + 130);
    }
    _stratLeft = FxWindows.toSeconds(FxWindows.strategyFxMaxC);
    if (notifyTutorial) {
      t?.onStrategy();
      onTutorialChanged?.call();
    }
  }

  void triggerReturnCityFx() {
    _returnFlashLeft = 0.6;
    final t = tutorial;
    if (t != null && t.session == TutorialSession.session2) {
      t.onReturnCity();
      onTutorialChanged?.call();
    }
    selectedIndex = null;
  }

  /// Brighter field fill so Shu green reads on lacquer (lock RGB kept for chrome).
  Color _tokenFill(CardFace card) {
    switch (card.faction) {
      case Faction.wei:
        return const Color(0xFF1E88E5);
      case Faction.shu:
        return const Color(0xFF2E7D32); // deep Shu green core
      case Faction.wu:
        return const Color(0xFFE53935);
      case Faction.other:
        return const Color(0xFFFFCA28);
    }
  }

  /// Cost: exactly 3 star glyphs (full/half/empty), >=8dp — match Detail CostStars.
  void _drawCostStars(Canvas canvas, Offset origin, double cost) {
    var rem = cost.clamp(0.0, 3.0);
    const r = 4.5; // diameter 9 >= 8dp
    const gap = 11.0;
    for (var i = 0; i < 3; i++) {
      double fill;
      if (rem >= 1.0) {
        fill = 1.0;
        rem -= 1.0;
      } else if (rem >= 0.5) {
        fill = 0.5;
        rem = 0;
      } else {
        fill = 0;
      }
      _drawStar(canvas, Offset(origin.dx + i * gap + r, origin.dy + r), r, fill);
    }
  }

  void _drawStar(Canvas canvas, Offset c, double r, double fill) {
    final path = Path();
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 5;
      final b = a + math.pi / 5;
      final ox = c.dx + r * math.cos(a);
      final oy = c.dy + r * math.sin(a);
      final ix = c.dx + r * 0.45 * math.cos(b);
      final iy = c.dy + r * 0.45 * math.sin(b);
      if (i == 0) {
        path.moveTo(ox, oy);
      } else {
        path.lineTo(ox, oy);
      }
      path.lineTo(ix, iy);
    }
    path.close();
    if (fill >= 1) {
      canvas.drawPath(path, Paint()..color = FactionColors.gold);
    } else if (fill >= 0.5) {
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white70
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(c.dx - r - 0.5, c.dy - r - 0.5, c.dx, c.dy + r + 0.5));
      canvas.drawPath(path, Paint()..color = FactionColors.gold);
      canvas.restore();
    } else {
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white70
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3,
      );
    }
  }

  /// Sheet is 1280×720, 4 cells (騎／槍／弓／刀). Crop circular badge (skip gold「騎」label below).
  static const double _weaponCellW = 320;
  static const double _weaponSrcPad = 30;
  static const double _weaponSrcY = 150;
  static const double _weaponSrcSize = 260; // circle only

  Rect _weaponSrcRect(TroopType troop) {
    final col = switch (troop) {
      TroopType.cavalry => 0,
      TroopType.spear => 1,
      TroopType.bow => 2,
      TroopType.infantry => 3,
      TroopType.siege => 3, // 刀角標
    };
    return Rect.fromLTWH(
      col * _weaponCellW + _weaponSrcPad,
      _weaponSrcY,
      _weaponSrcSize,
      _weaponSrcSize,
    );
  }

  void _drawWeapon(Canvas canvas, Offset c, TroopType troop, Color color, {double scale = 1}) {
    final sheet = _weaponSheet;
    final dstSize = 40.0 * scale;
    final dst = Rect.fromCenter(center: c, width: dstSize, height: dstSize);
    if (sheet != null) {
      final src = _weaponSrcRect(troop);
      final paint = Paint()
        ..filterQuality = FilterQuality.high
        ..colorFilter = color.a < 0.95
            ? ColorFilter.mode(Colors.white.withValues(alpha: color.a), BlendMode.modulate)
            : null;
      canvas.drawImageRect(sheet, src, dst, paint);
      return;
    }
    // Fallback procedural (assets not loaded yet) — never grey-circle slash.
    final s = scale;
    final p = Paint()
      ..color = color
      ..strokeWidth = 2.5 * s
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    switch (troop) {
      case TroopType.cavalry:
        canvas.drawArc(Rect.fromCenter(center: c, width: 22 * s, height: 26 * s), 0.4, 2.3, false, p);
        break;
      case TroopType.spear:
        canvas.drawLine(Offset(c.dx, c.dy + 16 * s), Offset(c.dx, c.dy - 16 * s), p);
        final tip = Path()
          ..moveTo(c.dx, c.dy - 18 * s)
          ..lineTo(c.dx - 7 * s, c.dy - 8 * s)
          ..lineTo(c.dx + 7 * s, c.dy - 8 * s)
          ..close();
        canvas.drawPath(tip, Paint()..color = color);
        break;
      case TroopType.bow:
        final arc = Path()
          ..moveTo(c.dx - 10 * s, c.dy - 14 * s)
          ..quadraticBezierTo(c.dx + 14 * s, c.dy, c.dx - 10 * s, c.dy + 14 * s);
        canvas.drawPath(arc, p);
        canvas.drawLine(Offset(c.dx - 8 * s, c.dy), Offset(c.dx + 12 * s, c.dy), p);
        break;
      case TroopType.siege:
      case TroopType.infantry:
        canvas.drawLine(Offset(c.dx - 10 * s, c.dy + 8 * s), Offset(c.dx + 12 * s, c.dy - 12 * s), p);
        canvas.drawLine(Offset(c.dx - 2 * s, c.dy + 2 * s), Offset(c.dx - 12 * s, c.dy + 6 * s), p);
        break;
    }
  }

  void _drawText(Canvas canvas, String text, Offset at, Color color, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.x - at.dx - 8);
    tp.paint(canvas, at);
  }
}
