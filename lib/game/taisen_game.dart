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

/// Offline 1v1 CPU stub — H0 Plan A: short watch (read-only) + large flat 2D field.
/// Watch ≤18% of game band (~15–18% screen); draggable field is the hero (≥55% screen).
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
  /// Shot / debug: force spear pose for Simulator captures.
  TroopAnimPose? debugForceSpearPose;

  /// Tutorial token roles (indices into [field]).
  int? tutorialOwnIndex;
  int? tutorialEnemyIndex;
  int? tutorialDropGuideIndex;

  /// Drag state (field-local coords).
  bool dragging = false;
  Offset? dragFrom;
  Offset? dragTo;

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

  /// H0 Plan A: watch fraction of [GameWidget] height (not old top-⅓).
  /// GameWidget sits between slim HUD (~≤6% screen) and bottom bar (~8–10%),
  /// so ~0.18 of game ≈ 15–17% of full screen; hard cap still ≤0.20 screen.
  static const double kWatchFractionOfGame = 0.18;

  /// Castle strip height inside the game band (~3–4% screen after shell chrome).
  static const double kCastleStripPx = 22.0;

  double get watchH => size.y * kWatchFractionOfGame;

  /// Flat operable field below watch (excludes watch; castle sits on divider).
  double get fieldH => (size.y - watchH).clamp(0.0, double.infinity);

  /// Own-castle bottom band ≈12% of drag field (Bosco: 10–14%).
  static const double kCastleBandFracOfField = 0.12;

  /// Real-card 54×86 ≈ 5:8. Short-side (width) as fraction of field width (Bosco 0.11–0.13, hard max 0.14).
  static const double kTokenWidthFracOfField = 0.12; // Bosco eye: 0.11–0.13 (hard max 0.14); was 0.16 Fail
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
    // Transparent hit ≥48dp diameter — may exceed smaller 0.12 art.
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

  Offset tokenCenter(int i) {
    if (i >= 0 && i < fieldPos.length) return fieldPos[i];
    const tokenR = 28.0;
    return Offset(48.0 + i * (tokenR * 2 + 20), watchH + 110);
  }

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

  /// FEEL_SHOT=spear-idle: own spear SpriteAnimation idle loop (5:8 @0.12 field_w).
  void setupFeelSpearIdlePose() {
    setupSession2Field();
    debugForceSpearPose = TroopAnimPose.idle;
    ownFacing = -0.2;
    selectedIndex = tutorialOwnIndex;
    watchKind = AWindowKind.intercept;
  }

  /// FEEL_SHOT=spear-attack: row3 tip-glow attack loop readable for UIUX.
  void setupFeelSpearAttackPose() {
    setupSession2Field();
    debugForceSpearPose = TroopAnimPose.attack;
    ownFacing = -0.35;
    selectedIndex = tutorialOwnIndex;
    watchKind = AWindowKind.intercept;
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
    if (coach != null) {
      if (coach.session == TutorialSession.session1 &&
          (coach.s1 == S1Phase.waitAura ||
              coach.s1 == S1Phase.hitCharge ||
              coach.s1 == S1Phase.tipNext ||
              (coach.shotPassMode && coach.s1 == S1Phase.waitAura))) {
        watchKind = AWindowKind.charge;
      } else if (coach.session == TutorialSession.session2) {
        watchKind = AWindowKind.intercept;
      }
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

    // Free-match: cavalry drop → wait aura ≥1C → 突撃 flash (no combat numbers).
    if (tutorial == null && _matchChargeIndex != null) {
      _matchChargeC += dt / CClock.secondsPerC;
      if (_matchChargeC >= 1.0) {
        final i = _matchChargeIndex!;
        flashHit(i, '突撃');
        _matchChargeIndex = null;
        _matchChargeC = 0;
      }
    }

    // Free-match: enemy charge aura visible; after ≥1C open spear turn/intercept window.
    if (tutorial == null && _matchEnemyChargeIndex != null) {
      _matchEnemyChargeC += dt / CClock.secondsPerC;
      if (_matchEnemyChargeC >= FxWindows.interceptTurnAfterAuraC && !_matchTurnWindowOpen) {
        _matchTurnWindowOpen = true;
      }
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
    if (tutorial == null && _bowWindupIndex != null && !_bowDidShoot) {
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
      canvas.drawCircle(
        drop,
        24,
        Paint()
          ..color = FactionColors.gold.withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      canvas.drawCircle(drop, 7, Paint()..color = FactionColors.gold.withValues(alpha: 0.8));
      _drawText(canvas, '落點', Offset(drop.dx - 14, drop.dy + 28), FactionColors.gold.withValues(alpha: 0.85), 12);
      if (tutorialOwnIndex != null) {
        final from = tokenCenter(tutorialOwnIndex!);
        _drawDashedLine(canvas, from, drop, FactionColors.gold.withValues(alpha: 0.65));
      }
    }

    // Free-match drag guide when dragging own cavalry
    if (dragging && dragFrom != null && dragTo != null) {
      _drawDashedLine(canvas, dragFrom!, dragTo!, const Color(0xFF80DEEA));
      canvas.drawCircle(
        dragTo!,
        16,
        Paint()
          ..color = const Color(0xFF80DEEA).withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Real-card 5:8; width ≈12% field (Bosco 0.11–0.13, max 0.14).
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

      _drawFieldTelegraph(canvas, center, card, i, isOwn: !isEnemy && tutorialOwnIndex == i, isEnemy: isEnemy);

      final inCastle = i < fieldInCastle.length && fieldInCastle[i];
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

      // Enemy facing arrow (lower field)
      if (isEnemy) {
        _drawFacingArrow(canvas, center, enemyFacing, const Color(0xFFFFF59D), enemyHard: true);
      } else if (t != null && t.session == TutorialSession.session2 && tutorialOwnIndex == i) {
        _drawFacingArrow(canvas, center, ownFacing, FactionColors.gold);
      }

      // Labels sit just under 5:8 card.
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

    // Floating 突撃 (session1) — not a tip-skip; requires auraReady after drag.
    // Suppress when fat-float hit label is 突撃 (one label only).
    final suppressFloatCharge = _hitFlashLeft > 0 && _hitFlashLabel == '突撃';
    if (t != null &&
        t.session == TutorialSession.session1 &&
        !suppressFloatCharge &&
        (t.s1 == S1Phase.hitCharge || t.s1 == S1Phase.waitAura)) {
      final at = tutorialOwnIndex != null ? tokenCenter(tutorialOwnIndex!) : dropGuidePoint;
      final ready = t.auraReady || t.shotPassMode;
      _drawFloatingAction(canvas, Offset(at.dx, at.dy - 58), '突撃', ready);
    }

    // Floating 迎擊 — single fat float; dim while waiting / wrong facing; NEVER stack with hit 飛字.
    final suppressFloatIntercept = _hitFlashLeft > 0 && _hitFlashLabel == '迎擊';
    if (t != null &&
        t.session == TutorialSession.session2 &&
        !suppressFloatIntercept &&
        (t.s2 == S2Phase.interceptHit ||
            t.s2 == S2Phase.waitTurn ||
            t.s2 == S2Phase.enemyApproach ||
            (t.shotPassMode && t.enemyAuraVisible))) {
      final at = tutorialOwnIndex != null ? tokenCenter(tutorialOwnIndex!) : Offset(w * 0.35, wh + 160);
      final ready = (t.facingCorrect && t.turnWindowOpen) || (t.shotPassMode && t.facingCorrect);
      _drawFloatingAction(canvas, Offset(at.dx, at.dy - 58), '迎擊', ready);
    }
    // Match intercept float when turn window open.
    if (t == null &&
        !suppressFloatIntercept &&
        _matchSpearIndex != null &&
        _matchEnemyChargeIndex != null &&
        (_matchTurnWindowOpen || _matchFacingCorrect)) {
      final at = tokenCenter(_matchSpearIndex!);
      _drawFloatingAction(canvas, Offset(at.dx, at.dy - 58), '迎擊', _matchFacingCorrect);
    }

    if (_hitFlashLeft > 0 && _hitFlashIndex != null && _hitFlashIndex! < field.length) {
      final c = tokenCenter(_hitFlashIndex!);
      _drawFatFloatText(canvas, _hitFlashLabel, Offset(c.dx, c.dy - 78));
      canvas.drawCircle(
        c,
        42,
        Paint()
          ..color = const Color(0xFF80DEEA).withValues(alpha: (_hitFlashLeft * 2).clamp(0, 0.55))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5,
      );
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
  }

  void _drawFloatingAction(Canvas canvas, Offset at, String label, bool ready) {
    final bg = ready ? FactionColors.gold : Colors.white24;
    final fg = ready ? FactionColors.lacquer : Colors.white54;
    final fat = label == '迎擊' || label == '突撃';
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: at, width: fat ? 100.0 : 86.0, height: fat ? 40.0 : 36.0),
      const Radius.circular(10),
    );
    canvas.drawRRect(r, Paint()..color = bg);
    if (ready) {
      canvas.drawRRect(
        r,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }
    _drawText(canvas, label, Offset(at.dx - 20, at.dy - 9), fg, 16);
  }

  Rect floatingActionHitRect(String label) {
    if (label == '突撃' && tutorialOwnIndex != null) {
      final at = tokenCenter(tutorialOwnIndex!);
      return Rect.fromCenter(center: Offset(at.dx, at.dy - 56), width: 96, height: 44);
    }
    if (label == '迎擊') {
      final idx = tutorial?.session == TutorialSession.session2
          ? tutorialOwnIndex
          : _matchSpearIndex;
      if (idx != null) {
        final at = tokenCenter(idx);
        return Rect.fromCenter(center: Offset(at.dx, at.dy - 56), width: 96, height: 44);
      }
    }
    return Rect.zero;
  }

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

  /// Top watch: both sides in frame, same telegraph kind/timing as lower field.
  void _drawWatchFullField(Canvas canvas, Rect band) {
    final t = tutorial;
    // Fake-3D lane (perspective) — both sides in frame; not flat color blocks.
    _drawWatchPerspectiveLane(canvas, band);

    // Near = own (larger), far = enemy (smaller) along the lane.
    final ownC = Offset(band.width * 0.34, band.top + band.height * 0.72);
    final enemyC = Offset(band.width * 0.62, band.top + band.height * 0.38);
    const ownScale = 1.0;
    const enemyScale = 0.72;

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
        final showCharge = t == null ||
            t.session != TutorialSession.session1 ||
            t.s1 == S1Phase.waitAura ||
            t.s1 == S1Phase.hitCharge ||
            t.s1 == S1Phase.tipNext;
        if (showCharge) {
          _drawChargeRings(canvas, ownC, 34 * ownScale, const Color(0xFF00E5FF), whiteCore: true);
        }
        if (showCharge && (t == null || t.enemyAuraVisible || t.session == TutorialSession.session1 || t.shotPassMode)) {
          _drawChargeRings(canvas, enemyC, 28 * enemyScale, const Color(0xFF00E5FF).withValues(alpha: 0.75), whiteCore: true);
        }
        break;
      case AWindowKind.intercept:
        _drawInterceptStance(canvas, ownC, 42 * ownScale, const Color(0xFF26C6DA), facing: ownFacing);
        if (t == null || t.enemyAuraVisible || t.shotPassMode) {
          _drawChargeRings(canvas, enemyC, 26 * enemyScale, const Color(0xFF00E5FF).withValues(alpha: 0.8), whiteCore: true);
        }
        break;
      case AWindowKind.bow:
        _drawBowWindup(canvas, ownC, ownC.dx + 70, const Color(0xFFFFAB40), progress01: 0.85, ready: false);
        break;
      case AWindowKind.stratagem:
        break;
    }

    // Watch fills: match field factions when possible (same-faction check uses Wei/Wei).
    Color ownFill = FactionColors.shu;
    Color enemyFill = FactionColors.wei;
    if (field.isNotEmpty && tutorialOwnIndex != null && tutorialOwnIndex! < field.length) {
      ownFill = _tokenFill(field[tutorialOwnIndex!]);
    }
    if (field.isNotEmpty && tutorialEnemyIndex != null && tutorialEnemyIndex! < field.length) {
      enemyFill = _tokenFill(field[tutorialEnemyIndex!]);
    } else if (field.length >= 2 && fieldIsEnemy.contains(true)) {
      enemyFill = _tokenFill(field[fieldIsEnemy.indexOf(true)]);
    }

    _drawMiniToken(canvas, ownC, ownFill, enemy: false, scale: ownScale);
    _drawMiniToken(canvas, enemyC, enemyFill, enemy: true, scale: enemyScale);
    // ALWAYS white/yellow facing arrow on enemy — never faction-fill alone.
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

  void _drawMiniToken(Canvas canvas, Offset c, Color fill, {required bool enemy, double scale = 1}) {
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
    _drawWeapon(canvas, c.translate(0, 2 * scale), TroopType.cavalry, Colors.white.withValues(alpha: 0.9), scale: 0.85 * scale);
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
  }) {
    // Design 5:8 gold-border cards (real-card 54×86). Finger = card.
    final dest = Rect.fromCenter(center: center, width: cardW, height: cardH);
    final rrect = RRect.fromRectAndRadius(dest, Radius.circular(cardW * 0.08));

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
      // Cover-fit anim into card so spear tip glow / body stay readable at 0.12 width.
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
      final halo = RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: cardW + 20, height: cardH + 20),
        Radius.circular(cardW * 0.14),
      );
      canvas.drawRRect(
        halo,
        Paint()
          ..color = const Color(0xFFECEFF1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: cardW + 12, height: cardH + 12),
          Radius.circular(cardW * 0.12),
        ),
        Paint()
          ..color = const Color(0xFF000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8.0,
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = const Color(0xFF0A0A0A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.5,
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = const Color(0xFFB0BEC5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }

    final bowWinding = !isEnemy &&
        selected &&
        card.troop == TroopType.bow &&
        _bowWindupIndex != null &&
        selectedIndex == _bowWindupIndex;
    if (selected && !isEnemy && !bowWinding) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: cardW + 10, height: cardH + 10),
          Radius.circular(cardW * 0.12),
        ),
        Paint()
          ..color = FactionColors.gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.2,
      );
    }
    if (pulseOwn) {
      final pulse = 0.5 + 0.5 * math.sin(_pulse * 3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center,
            width: cardW + 14 + pulse * 3,
            height: cardH + 14 + pulse * 3,
          ),
          Radius.circular(cardW * 0.13),
        ),
        Paint()
          ..color = FactionColors.gold.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    }
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
    if (card.troop == TroopType.spear && debugForceSpearPose != null) {
      return debugForceSpearPose!;
    }
    if (dragging && selectedIndex == index) return TroopAnimPose.move;
    if (_hitFlashLeft > 0 && _hitFlashIndex == index) return TroopAnimPose.attack;
    switch (card.troop) {
      case TroopType.spear:
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

  void _drawFatFloatText(Canvas canvas, String text, Offset center, {double alpha = 1}) {
    final style = TextStyle(
      color: Colors.white.withValues(alpha: alpha),
      fontSize: 22,
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
      // Charge cyan/white aura — only after drop (waitAura+). Mid-drag FEEL shots stay ring-free.
      if (t.s1 == S1Phase.waitAura ||
          t.s1 == S1Phase.hitCharge ||
          t.s1 == S1Phase.tipNext) {
        final readyBoost = (t.auraReady || (t.shotPassMode && t.auraReady)) ? 1.0 : 0.72;
        _drawChargeRings(
          canvas,
          c,
          48,
          const Color(0xFF00E5FF).withValues(alpha: 0.85 * readyBoost),
          whiteCore: true,
        );
      }
      return;
    }
    if (t != null && t.session == TutorialSession.session2) {
      if (isOwn && card.troop == TroopType.spear) {
        // Persistent spear-tip glow (not a countdown bar) for all S2 coaching phases.
        _drawInterceptStance(canvas, c, 44, const Color(0xFF26C6DA).withValues(alpha: 0.85), facing: ownFacing);
        return;
      }
      if (isEnemy && (t.enemyAuraVisible || t.shotPassMode)) {
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
        // 「見環先撞」: bright aura only after drag-drop while waiting ≥1C.
        if (_matchChargeIndex == index) {
          final readyBoost = _matchChargeC >= 1.0 ? 1.0 : (0.55 + 0.35 * (_matchChargeC.clamp(0, 1)));
          _drawChargeRings(
            canvas,
            c,
            44,
            const Color(0xFF00E5FF).withValues(alpha: 0.85 * readyBoost),
            whiteCore: true,
          );
        }
        // Enemy charge aura for intercept turn window (≥1C visible).
        if (isEnemy && _matchEnemyChargeIndex == index) {
          final readyBoost = _matchEnemyChargeC >= 1.0 ? 1.0 : (0.55 + 0.4 * (_matchEnemyChargeC.clamp(0, 1)));
          _drawChargeRings(
            canvas,
            c,
            42,
            const Color(0xFF00E5FF).withValues(alpha: 0.85 * readyBoost),
            whiteCore: true,
          );
        }
        break;
      case TroopType.spear:
        _drawInterceptStance(
          canvas,
          c,
          42,
          const Color(0xFF26C6DA).withValues(alpha: 0.75),
          facing: ownFacing,
        );
        break;
      case TroopType.bow:
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

  void _drawChargeRings(Canvas canvas, Offset c, double baseR, Color color, {bool whiteCore = false}) {
    final t = (_pulse % 1.2) / 1.2;
    final baseA = color.a.clamp(0.25, 1.0);
    for (var i = 0; i < 3; i++) {
      final r = baseR + i * 12 + t * 16;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = color.withValues(alpha: (baseA - i * 0.12).clamp(0.12, 1.0))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0 - i * 0.35,
      );
    }
    if (whiteCore) {
      canvas.drawCircle(
        c,
        baseR - 4 + t * 6,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.28 + 0.12 * math.sin(_pulse * 5))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4,
      );
    }
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 + _pulse;
      canvas.drawLine(
        Offset(c.dx + math.cos(a) * (baseR - 6), c.dy + math.sin(a) * (baseR - 6)),
        Offset(c.dx + math.cos(a) * (baseR + 22), c.dy + math.sin(a) * (baseR + 22)),
        Paint()
          ..color = color.withValues(alpha: (baseA * 0.55).clamp(0.15, 0.7))
          ..strokeWidth = 1.8,
      );
    }
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
    // Persistent spear tip / 槍衾 glow — bottom field (rx≥40) one size larger; watch (scaled rx) stays OK.
    final glow = 0.65 + 0.35 * math.sin(_pulse * 4);
    final tipScale = rx >= 40 ? 1.28 : (rx / 36.0).clamp(0.75, 1.05);
    final tip = Offset(c.dx, c.dy - 48 * tipScale);
    canvas.drawCircle(tip, 28 * tipScale, Paint()..color = const Color(0xFF80DEEA).withValues(alpha: 0.42 * glow));
    canvas.drawCircle(tip, 17 * tipScale, Paint()..color = Colors.white.withValues(alpha: 0.52 * glow));
    canvas.drawCircle(tip, 9.5 * tipScale, Paint()..color = Colors.white.withValues(alpha: 0.95));
    canvas.drawLine(
      Offset(c.dx, c.dy + 26 * tipScale),
      Offset(c.dx, c.dy - 52 * tipScale),
      Paint()
        ..color = color
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
    }
    return null;
  }

  void selectOrDetailAt(Offset local) {
    // Watch band is read-only — ignore taps in short watch
    if (local.dy < watchH) return;

    final t = tutorial;
    // Floating actions first
    if (t != null && t.session == TutorialSession.session1) {
      if (floatingActionHitRect('突撃').contains(local)) {
        flashHit(tutorialOwnIndex ?? 0, '突撃');
        t.onTapCharge();
        onTutorialChanged?.call();
        return;
      }
    }
    if (t != null && t.session == TutorialSession.session2) {
      if (floatingActionHitRect('迎擊').contains(local)) {
        // Flash only on success — early/wrong facing goes to fail/retry without false 迎擊 飛字.
        final ok = t.turnWindowOpen && t.facingCorrect;
        if (ok) flashHit(tutorialOwnIndex ?? 0, '迎擊');
        t.onTapIntercept(facingWasCorrect: t.facingCorrect);
        onTutorialChanged?.call();
        return;
      }
    }
    // Match: fat「迎擊」when turn window open.
    if (t == null && floatingActionHitRect('迎擊').contains(local)) {
      if (_matchTurnWindowOpen && _matchFacingCorrect && _matchSpearIndex != null) {
        flashHit(_matchSpearIndex!, '迎擊');
        // Visual only — no damage numbers.
        _matchEnemyChargeIndex = null;
        _matchTurnWindowOpen = false;
      }
      return;
    }

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
      if (t.s1 != S1Phase.dragGuide && t.s1 != S1Phase.highlightSelect) return;
      if (i != tutorialOwnIndex) return;
      selectedIndex = i;
      t.onSelectOwnCavalry();
      dragging = true;
      dragFrom = tokenCenter(i);
      dragTo = local;
      onTutorialChanged?.call();
      return;
    }
    // Free match: select→drag with guide line + drop
    selectedIndex = i;
    dragging = true;
    dragFrom = tokenCenter(i);
    dragTo = local;
  }

  void panUpdate(Offset local) {
    if (!dragging) return;
    // Clamp to flat field — never into watch band
    final y = local.dy < watchH + 8 ? watchH + 8 : local.dy;
    dragTo = Offset(local.dx, y);
    castleBandHot = inCastleBand(dragTo!);
  }

  void panEnd(Offset local) {
    if (!dragging) return;
    dragging = false;
    final t = tutorial;
    final drop = dropGuidePoint;
    final at = Offset(local.dx, local.dy < watchH + 8 ? watchH + 8 : local.dy);
    dragTo = at;
    final bandHot = inCastleBand(at);
    castleBandHot = false;
    if (t != null && t.session == TutorialSession.session1 && tutorialOwnIndex != null) {
      final d = (at - drop).distance;
      if (d <= 48) {
        fieldPos[tutorialOwnIndex!] = drop;
        t.onDropAtGuide();
        onTutorialChanged?.call();
      }
    } else if (t == null && selectedIndex != null && selectedIndex! < fieldPos.length) {
      final i = selectedIndex!;
      // Free match drop: move token within lower field (no stack-shadow).
      final y = at.dy.clamp(watchH + 40, size.y - 20);
      final x = at.dx.clamp(36.0, size.x - 36);
      final moved = dragFrom != null && (Offset(x, y) - dragFrom!).distance > 24;
      final wasInCastle = i < fieldInCastle.length && fieldInCastle[i];

      if (bandHot && !isEnemyAt(i)) {
        // Drag INTO 己城 band → 返城 (heal/redeploy state; no invented numbers).
        final band = castleBandRect;
        fieldPos[i] = Offset(x.clamp(48.0, size.x - 48), band.top + band.height * 0.55);
        while (fieldInCastle.length <= i) {
          fieldInCastle.add(false);
        }
        fieldInCastle[i] = true;
        triggerReturnCityFx();
        _cancelBowWindup();
      } else {
        fieldPos[i] = Offset(x, y);
        while (fieldInCastle.length <= i) {
          fieldInCastle.add(false);
        }
        if (wasInCastle && !bandHot) {
          // Drag OUT of band onto field → 出陣 (visual flytext only).
          fieldInCastle[i] = false;
          flashHit(i, '出陣');
        } else {
          fieldInCastle[i] = false;
        }
        // Moving cancels bow still-windup.
        if (moved && field[i].troop == TroopType.bow) {
          _cancelBowWindup();
        } else if (field[i].troop == TroopType.cavalry && dragFrom != null && !wasInCastle) {
          // Cavalry drag far enough → wait aura ≥1C then 突撃 hit (visual only).
          if ((Offset(x, y) - dragFrom!).distance > 70) {
            _matchChargeIndex = i;
            _matchChargeC = 0;
          }
        }
      }
    }
    dragFrom = null;
    dragTo = null;
  }

  void flashHit(int index, String label) {
    _hitFlashIndex = index;
    _hitFlashLabel = label;
    _hitFlashLeft = FxWindows.toSeconds(FxWindows.interceptHitFlashC);
    _shakeLeft = FxWindows.toSeconds(FxWindows.interceptHitFlashC);
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
