import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../data/card_models.dart';
import 'c_clock.dart';
import 'faction_colors.dart';
import 'fx_windows.dart';
import 'tutorial_controller.dart';

enum AWindowKind { charge, intercept, bow, stratagem }

/// Offline 1v1 CPU stub: top 1/3 watch (read-only), bottom 2/3 flat field.
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
  int? selectedIndex;

  /// Cosmetic castle race fills (0–1). No combat damage numbers invented.
  double ownCastle = 0.78;
  double enemyCastle = 0.64;
  double _shakeLeft = 0;
  /// Shot mode: keep 返城 float visible.
  bool holdReturnFlash = false;

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

  void Function(CardFace card)? onRequestDetail;
  VoidCallback? onTutorialChanged;

  @override
  Color backgroundColor() => FactionColors.lacquer;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.anchor = Anchor.topLeft;
    clock.reset();
  }

  double get watchH => size.y / 3;

  Offset tokenCenter(int i) {
    if (i >= 0 && i < fieldPos.length) return fieldPos[i];
    const tokenR = 28.0;
    return Offset(48.0 + i * (tokenR * 2 + 20), watchH + 110);
  }

  void setupSession1Field() {
    field.clear();
    fieldPos.clear();
    fieldIsEnemy.clear();
    selectedIndex = null;
    final zhao = Cost6Roster.all.firstWhere((c) => c.id == 'zhaoyun');
    final cao = Cost6Roster.all.firstWhere((c) => c.id == 'caocao');
    // Layout lock: lower field shows BOTH own + enemy (not own-only).
    field.addAll([zhao, cao]);
    fieldIsEnemy.addAll([false, true]);
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
    selectedIndex = null;
    final spear = Cost6Roster.all.firstWhere((c) => c.id == 'zhanghe');
    final enemyCav = Cost6Roster.all.firstWhere((c) => c.id == 'caocao');
    field.addAll([spear, enemyCav]);
    fieldIsEnemy.addAll([false, true]);
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
      fieldPos.add(Offset(w * (0.22 + i * 0.22), wh + fh * 0.62));
    }
    for (var i = 0; i < enemyCards.length; i++) {
      field.add(enemyCards[i]);
      fieldIsEnemy.add(true);
      fieldPos.add(Offset(w * (0.35 + i * 0.28), wh + fh * 0.22));
    }
    // Cap visual stack: never more than fieldMax total, no stack-shadow.
    while (field.length > fieldMax) {
      field.removeLast();
      fieldPos.removeLast();
      fieldIsEnemy.removeLast();
    }
    selectedIndex = 0;
    tutorialOwnIndex = 0;
    ownCastle = 0.72;
    enemyCastle = 0.58;
  }

  void setupFeelCastleField() {
    setupMatchDemoField();
    ownCastle = 0.82;
    enemyCastle = 0.45;
    selectedIndex = 0;
    holdReturnFlash = true;
    _returnFlashLeft = 1.0;
    // Show drag rubber-band on Zhao for 拖得郁 readability in match.
    final wh = size.y > 0 ? watchH : 200.0;
    final w = size.x > 0 ? size.x : 390.0;
    final fh = size.y > 0 ? (size.y - wh) : 280.0;
    dragging = true;
    dragFrom = fieldPos.isNotEmpty ? fieldPos[0] : Offset(w * 0.22, wh + fh * 0.62);
    dragTo = Offset(w * 0.55, wh + fh * 0.34);
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
    final own = Cost6Roster.all.firstWhere((c) => c.id == 'caoren'); // 魏騎
    final enemy = Cost6Roster.all.firstWhere((c) => c.id == 'caocao'); // 魏騎
    field.addAll([own, enemy]);
    fieldIsEnemy.addAll([false, true]);
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

  Offset get dropGuidePoint {
    final wh = size.y > 0 ? watchH : 200.0;
    final w = size.x > 0 ? size.x : 390.0;
    // Mid field, clear of bottom bar (bar is outside GameWidget).
    return Offset(w * 0.55, wh + (size.y - wh) * 0.42);
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Tutorial shell keeps C frozen at 99 (paused); match demo still ticks.
    if (tutorial == null) {
      clock.update(dt);
    }
    _pulse += dt;
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

    // Session2: when facing becomes correct, rotate spear tip toward enemy.
    final t = tutorial;
    if (t != null && t.session == TutorialSession.session2 && t.facingCorrect) {
      ownFacing = -0.35; // tip toward enemy
    } else if (t != null && t.session == TutorialSession.session2 && !t.facingCorrect) {
      ownFacing = 0.9; // wrong facing
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
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

    // Top 1/3: full battlefield watch — BOTH sides in frame, READ-ONLY.
    canvas.drawRect(Rect.fromLTWH(0, 0, w, wh), Paint()..color = const Color(0xFF141414));
    _drawLacquerGrain(canvas, Rect.fromLTWH(0, 0, w, wh), alpha: 0.08);
    _drawText(canvas, '全戰場（只睇）', const Offset(16, 18), FactionColors.gold, 17);
    _drawWatchFullField(canvas, Rect.fromLTWH(0, 0, w, wh));

    // Mid divider: thicker dual castle bars + 99C zone edge.
    _drawCastleRaceBars(canvas, w, fieldTop);

    // Bottom 2/3: flat field — own + enemy tokens.
    canvas.drawRect(Rect.fromLTWH(0, fieldTop, w, h - wh), Paint()..color = const Color(0xFF101010));
    _drawLacquerGrain(canvas, Rect.fromLTWH(0, fieldTop, w, h - wh), alpha: 0.14);

    final t = tutorial;
    _drawText(canvas, '雙方動向（可操作）', Offset(16, fieldTop + 28), FactionColors.gold, 16);
    if (t == null) {
      final ownN = fieldIsEnemy.where((e) => !e).length;
      final enN = fieldIsEnemy.where((e) => e).length;
      _drawText(
        canvas,
        'Cost $costCap · 場上 ${field.length}/$fieldMax（己$ownN／敵$enN）',
        Offset(16, fieldTop + 50),
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

    const tokenR = 30.0;
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

      _drawCardLikeToken(
        canvas,
        center,
        card,
        tokenR: tokenR,
        selected: selected || (tutorialOwnIndex == i && t != null),
        isEnemy: isEnemy,
        dim: dim,
        pulseOwn: tutorialOwnIndex == i && t != null && t.session == TutorialSession.session1,
      );

      // Enemy facing arrow (lower field)
      if (isEnemy) {
        _drawFacingArrow(canvas, center, enemyFacing, const Color(0xFFFFF59D), enemyHard: true);
      } else if (t != null && t.session == TutorialSession.session2 && tutorialOwnIndex == i) {
        _drawFacingArrow(canvas, center, ownFacing, FactionColors.gold);
      }

      _drawText(
        canvas,
        card.nameZh,
        Offset(center.dx - 18, center.dy + tokenR + 4),
        dim ? FactionColors.gold.withValues(alpha: 0.35) : FactionColors.gold,
        11,
      );
      _drawCostStars(canvas, Offset(center.dx - 18, center.dy + tokenR + 20), card.cost);
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

    // Floating 迎擊 — only while awaiting tap; NEVER stack with fat-float「迎擊」(no 迎擊迎擊).
    final suppressFloatIntercept = _hitFlashLeft > 0 && _hitFlashLabel == '迎擊';
    if (t != null &&
        t.session == TutorialSession.session2 &&
        !suppressFloatIntercept &&
        (t.s2 == S2Phase.interceptHit || (t.s2 == S2Phase.waitTurn && t.facingCorrect))) {
      final at = tutorialOwnIndex != null ? tokenCenter(tutorialOwnIndex!) : Offset(w * 0.35, wh + 160);
      final ready = t.facingCorrect || t.shotPassMode;
      _drawFloatingAction(canvas, Offset(at.dx, at.dy - 58), '迎擊', ready);
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
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: at, width: 86, height: 36),
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
    final t = tutorial;
    if (t == null) return Rect.zero;
    if (label == '突撃' && tutorialOwnIndex != null) {
      final at = tokenCenter(tutorialOwnIndex!);
      return Rect.fromCenter(center: Offset(at.dx, at.dy - 56), width: 80, height: 40);
    }
    if (label == '迎擊' && tutorialOwnIndex != null) {
      final at = tokenCenter(tutorialOwnIndex!);
      return Rect.fromCenter(center: Offset(at.dx, at.dy - 56), width: 80, height: 40);
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


  void _drawLacquerGrain(Canvas canvas, Rect rect, {double alpha = 0.12}) {
    final paint = Paint()
      ..color = FactionColors.gold.withValues(alpha: alpha * 0.35)
      ..strokeWidth = 1;
    for (var i = 0; i < 14; i++) {
      final y = rect.top + (i + 1) * (rect.height / 15);
      canvas.drawLine(Offset(rect.left + 8, y), Offset(rect.right - 8, y), paint);
    }
    final v = Paint()
      ..color = Colors.white.withValues(alpha: alpha * 0.2)
      ..strokeWidth = 1;
    for (var i = 0; i < 6; i++) {
      final x = rect.left + (i + 1) * (rect.width / 7);
      canvas.drawLine(Offset(x, rect.top + 6), Offset(x, rect.bottom - 6), v);
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
        _drawBowWindup(canvas, ownC, ownC.dx + 70, const Color(0xFFFFD54F));
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
        AWindowKind.charge => '突撃オーラ ≥1C',
        AWindowKind.intercept => '迎擊 槍尖常駐',
        AWindowKind.bow => '弓停射 ~1C',
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
    required double tokenR,
    required bool selected,
    required bool isEnemy,
    required bool dim,
    required bool pulseOwn,
  }) {
    final base = _tokenFill(card);
    final fill = dim ? base.withValues(alpha: 0.35) : base;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: tokenR * 1.7, height: tokenR * 2.05),
      const Radius.circular(8),
    );
    // Gold-border card shape: lacquer face + thin faction stripe (NOT portrait blob).
    canvas.drawRRect(rect, Paint()..color = const Color(0xFF141414).withValues(alpha: dim ? 0.4 : 0.96));
    final stripe = RRect.fromRectAndRadius(
      Rect.fromLTWH(center.dx - tokenR * 0.85, center.dy - tokenR * 1.025, tokenR * 1.7, tokenR * 0.42),
      const Radius.circular(7),
    );
    canvas.drawRRect(stripe, Paint()..color = fill);
    // Soft inner panel so weapon icon pops
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center.translate(0, 4), width: tokenR * 1.25, height: tokenR * 1.15),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFF1E1E1E).withValues(alpha: dim ? 0.35 : 0.9),
    );

    if (isEnemy) {
      // PRIORITY: Wei=Wei — thick dark outline + cool/white halo (NOT gold; own keeps gold ring).
      // Facing arrow stays yellow/white separately.
      final halo = RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: tokenR * 1.7 + 24, height: tokenR * 2.05 + 24),
        const Radius.circular(14),
      );
      canvas.drawRRect(
        halo,
        Paint()
          ..color = const Color(0xFFECEFF1) // silver-white halo ≠ gold select
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.5,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: tokenR * 1.7 + 14, height: tokenR * 2.05 + 14),
          const Radius.circular(12),
        ),
        Paint()
          ..color = const Color(0xFF000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10.0,
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color = const Color(0xFF0A0A0A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.5,
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color = const Color(0xFFB0BEC5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    } else {
      // Own: gold-border card
      canvas.drawRRect(
        rect,
        Paint()
          ..color = FactionColors.gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8,
      );
    }
    if (selected && !isEnemy) {
      // Fat gold select ring (own only — never on enemy)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: tokenR * 1.7 + 12, height: tokenR * 2.05 + 12),
          const Radius.circular(11),
        ),
        Paint()
          ..color = FactionColors.gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.0,
      );
    }
    if (pulseOwn) {
      final pulse = 0.5 + 0.5 * math.sin(_pulse * 3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: tokenR * 1.7 + 16 + pulse * 4, height: tokenR * 2.05 + 16 + pulse * 4),
          const Radius.circular(12),
        ),
        Paint()
          ..color = FactionColors.gold.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
    // Weapons-only icon (larger) — no face/portrait blob.
    _drawWeapon(
      canvas,
      Offset(center.dx, center.dy + 2),
      card.troop,
      dim ? Colors.white38 : Colors.white,
      scale: 1.35,
    );
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
        break;
      case TroopType.spear:
        _drawInterceptStance(canvas, c, 40, const Color(0xFF26C6DA).withValues(alpha: 0.5));
        break;
      case TroopType.bow:
        _drawBowWindup(canvas, c, c.dx + 70, FactionColors.gold.withValues(alpha: 0.7));
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
    // Bigger spear-tip triangle (was too small)
    final wedge = Path()
      ..moveTo(c.dx, c.dy - 52)
      ..lineTo(c.dx - 28, c.dy + 10)
      ..lineTo(c.dx + 28, c.dy + 10)
      ..close();
    canvas.drawPath(wedge, Paint()..color = color.withValues(alpha: 0.5));
    canvas.drawPath(
      wedge,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    // Persistent spear tip / 槍衾 glow (not a countdown bar) — larger
    final glow = 0.65 + 0.35 * math.sin(_pulse * 4);
    final tip = Offset(c.dx, c.dy - 48);
    canvas.drawCircle(tip, 22, Paint()..color = const Color(0xFF80DEEA).withValues(alpha: 0.4 * glow));
    canvas.drawCircle(tip, 14, Paint()..color = Colors.white.withValues(alpha: 0.5 * glow));
    canvas.drawCircle(tip, 8, Paint()..color = Colors.white.withValues(alpha: 0.95));
    canvas.drawLine(
      Offset(c.dx, c.dy + 26),
      Offset(c.dx, c.dy - 50),
      Paint()
        ..color = color
        ..strokeWidth = 4.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  void _drawBowWindup(Canvas canvas, Offset c, double aimX, Color color) {
    canvas.drawCircle(c, 26, Paint()..color = color.withValues(alpha: 0.18));
    canvas.drawCircle(
      c,
      26,
      Paint()
        ..color = color.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    canvas.drawRect(
      Rect.fromCenter(center: Offset(c.dx, c.dy - 30), width: 10, height: 50),
      Paint()..color = color.withValues(alpha: 0.22),
    );
    final y = c.dy;
    final dash = Paint()
      ..color = color
      ..strokeWidth = 1.6;
    for (var x = c.dx + 20; x < aimX; x += 10) {
      canvas.drawLine(Offset(x, y), Offset(x + 5, y), dash);
    }
    canvas.drawCircle(Offset(aimX, y), 8, Paint()..color = color.withValues(alpha: 0.35));
    canvas.drawCircle(
      Offset(aimX, y),
      8,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawStratagemBurst(Canvas canvas, Offset at, double life01) {
    // Translucent gold burst ≤1C — canvas paint only (lower 2/3 clip); never blocks 歸城/計略.
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
    const tokenR = 30.0;
    final i = field.length;
    field.add(card);
    fieldIsEnemy.add(enemy);
    fieldPos.add(Offset(48.0 + i * (tokenR * 2 + 18), watchH + 120));
    return true;
  }

  bool isEnemyAt(int i) => i >= 0 && i < fieldIsEnemy.length && fieldIsEnemy[i];

  int? hitTokenAt(Offset local) {
    if (local.dy < watchH) return null; // top 1/3 read-only
    const tokenR = 34.0;
    for (var i = 0; i < field.length; i++) {
      final c = tokenCenter(i);
      final dx = local.dx - c.dx;
      final dy = local.dy - c.dy;
      if (dx * dx + dy * dy <= (tokenR + 10) * (tokenR + 10)) return i;
    }
    return null;
  }

  void selectOrDetailAt(Offset local) {
    // Watch band is read-only — ignore taps in top 1/3
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
        flashHit(tutorialOwnIndex ?? 0, '迎擊');
        t.onTapIntercept(facingWasCorrect: t.facingCorrect);
        onTutorialChanged?.call();
        return;
      }
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
    if (isEnemyAt(i)) {
      // Can highlight enemy for read, but no gold ownership ring actions
      selectedIndex = i;
      return;
    }

    if (selectedIndex == i) {
      onRequestDetail?.call(field[i]);
    } else {
      selectedIndex = i;
    }
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
    // Clamp to field (lower 2/3) — never into watch band
    final y = local.dy < watchH + 8 ? watchH + 8 : local.dy;
    dragTo = Offset(local.dx, y);
  }

  void panEnd(Offset local) {
    if (!dragging) return;
    dragging = false;
    final t = tutorial;
    final drop = dropGuidePoint;
    final at = Offset(local.dx, local.dy < watchH + 8 ? watchH + 8 : local.dy);
    dragTo = at;
    if (t != null && t.session == TutorialSession.session1 && tutorialOwnIndex != null) {
      final d = (at - drop).distance;
      if (d <= 48) {
        fieldPos[tutorialOwnIndex!] = drop;
        t.onDropAtGuide();
        onTutorialChanged?.call();
      }
    } else if (t == null && selectedIndex != null && selectedIndex! < fieldPos.length) {
      // Free match drop: move token within lower field (no stack-shadow).
      final y = at.dy.clamp(watchH + 40, size.y - 40);
      final x = at.dx.clamp(36.0, size.x - 36);
      fieldPos[selectedIndex!] = Offset(x, y);
      // Cavalry drag far enough → wait aura ≥1C then 突撃 hit (visual only).
      if (field[selectedIndex!].troop == TroopType.cavalry && dragFrom != null) {
        if ((Offset(x, y) - dragFrom!).distance > 70) {
          _matchChargeIndex = selectedIndex;
          _matchChargeC = 0;
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

  void _drawWeapon(Canvas canvas, Offset c, TroopType troop, Color color, {double scale = 1}) {
    final s = scale;
    final p = Paint()
      ..color = color
      ..strokeWidth = 2.5 * s
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    switch (troop) {
      case TroopType.cavalry:
        // Blade / saber — weapons-only
        canvas.drawLine(Offset(c.dx - 12 * s, c.dy + 10 * s), Offset(c.dx + 12 * s, c.dy - 12 * s), p);
        canvas.drawCircle(Offset(c.dx + 12 * s, c.dy - 12 * s), 4.2 * s, Paint()..color = color);
        canvas.drawLine(Offset(c.dx - 4 * s, c.dy + 4 * s), Offset(c.dx - 14 * s, c.dy + 2 * s), p);
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
        canvas.drawLine(Offset(c.dx - 10 * s, c.dy - 14 * s), Offset(c.dx - 10 * s, c.dy + 14 * s), p);
        canvas.drawLine(Offset(c.dx - 8 * s, c.dy), Offset(c.dx + 12 * s, c.dy), p);
        break;
      case TroopType.siege:
        canvas.drawRect(Rect.fromCenter(center: c, width: 16 * s, height: 12 * s), p);
        canvas.drawLine(Offset(c.dx - 12 * s, c.dy + 10 * s), Offset(c.dx + 12 * s, c.dy + 10 * s), p);
        break;
      case TroopType.infantry:
        canvas.drawLine(Offset(c.dx, c.dy - 12 * s), Offset(c.dx, c.dy + 8 * s), p);
        canvas.drawLine(Offset(c.dx - 9 * s, c.dy - 2 * s), Offset(c.dx + 9 * s, c.dy - 2 * s), p);
        canvas.drawLine(Offset(c.dx, c.dy + 8 * s), Offset(c.dx - 7 * s, c.dy + 14 * s), p);
        canvas.drawLine(Offset(c.dx, c.dy + 8 * s), Offset(c.dx + 7 * s, c.dy + 14 * s), p);
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
