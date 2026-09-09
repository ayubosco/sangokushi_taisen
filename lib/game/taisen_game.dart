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
  int? selectedIndex;

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
    selectedIndex = null;
    final zhao = Cost6Roster.all.firstWhere((c) => c.id == 'zhaoyun');
    final cao = Cost6Roster.all.firstWhere((c) => c.id == 'caocao');
    final bow = Cost6Roster.all.firstWhere((c) => c.id == 'sunquan');
    field.addAll([zhao, cao, bow]);
    final wh = size.y > 0 ? watchH : 200.0;
    final w = size.x > 0 ? size.x : 390.0;
    fieldPos.addAll([
      Offset(w * 0.28, wh + 120), // own cavalry
      Offset(w * 0.55, wh + 160), // dim
      Offset(w * 0.78, wh + 140), // dim
    ]);
    tutorialOwnIndex = 0;
    tutorialEnemyIndex = null;
    selectedIndex = null;
  }

  void setupSession2Field() {
    field.clear();
    fieldPos.clear();
    selectedIndex = null;
    final spear = Cost6Roster.all.firstWhere((c) => c.id == 'zhanghe');
    final enemyCav = Cost6Roster.all.firstWhere((c) => c.id == 'caocao');
    field.addAll([spear, enemyCav]);
    final wh = size.y > 0 ? watchH : 200.0;
    final w = size.x > 0 ? size.x : 390.0;
    fieldPos.addAll([
      Offset(w * 0.35, wh + 160), // own spear
      Offset(w * 0.70, wh + 100), // enemy cavalry
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
    selectedIndex = null;
    tutorialOwnIndex = null;
    tutorialEnemyIndex = null;
    final cards = [
      Cost6Roster.all.firstWhere((c) => c.id == 'zhaoyun'),
      Cost6Roster.all.firstWhere((c) => c.id == 'caocao'),
      Cost6Roster.all.firstWhere((c) => c.troop == TroopType.spear),
      Cost6Roster.all.firstWhere((c) => c.troop == TroopType.bow),
    ];
    for (var i = 0; i < cards.length; i++) {
      field.add(cards[i]);
      const tokenR = 28.0;
      fieldPos.add(Offset(48.0 + i * (tokenR * 2 + 20), watchH + 110));
    }
    selectedIndex = 0;
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
    clock.update(dt);
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

    if (_stratLeft > 0) {
      _stratLeft -= dt;
      if (_stratLeft <= 0) {
        _stratLeft = 0;
        _stratAt = null;
      }
    }
    if (_hitFlashLeft > 0) {
      _hitFlashLeft -= dt;
      if (_hitFlashLeft <= 0) {
        _hitFlashLeft = 0;
        _hitFlashIndex = null;
      }
    }
    if (_returnFlashLeft > 0) {
      _returnFlashLeft -= dt;
      if (_returnFlashLeft <= 0) _returnFlashLeft = 0;
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

    canvas.drawRect(Rect.fromLTWH(0, 0, w, wh), Paint()..color = const Color(0xFF1A1A1A));
    _drawText(canvas, '敵軍監視（只讀）', const Offset(16, 24), FactionColors.gold, 16);
    _drawWatchTelegraph(canvas, Rect.fromLTWH(0, 0, w, wh));

    canvas.drawRect(Rect.fromLTWH(0, fieldTop, w, h - wh), Paint()..color = const Color(0xFF121212));
    canvas.drawLine(
      Offset(0, fieldTop),
      Offset(w, fieldTop),
      Paint()
        ..color = FactionColors.gold
        ..strokeWidth = 2,
    );

    final t = tutorial;
    final title = t == null
        ? '場即係盤 · Cost $costCap · 場上 ${field.length}/$fieldMax'
        : (t.session == TutorialSession.session1
            ? '教學場1 · 選→拖→突撃'
            : (t.session == TutorialSession.session2 ? '教學場2 · 迎擊＋計略/歸城' : '場即係盤'));
    _drawText(canvas, title, Offset(16, fieldTop + 12), FactionColors.gold, 14);

    // Session1 drop guide
    if (t != null &&
        t.session == TutorialSession.session1 &&
        (t.s1 == S1Phase.dragGuide ||
            t.s1 == S1Phase.waitAura ||
            t.s1 == S1Phase.hitCharge ||
            t.s1 == S1Phase.tipNext ||
            t.shotPassMode)) {
      final drop = dropGuidePoint;
      canvas.drawCircle(
        drop,
        22,
        Paint()
          ..color = FactionColors.gold.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawCircle(drop, 6, Paint()..color = FactionColors.gold.withValues(alpha: 0.7));
      if (tutorialOwnIndex != null) {
        final from = tokenCenter(tutorialOwnIndex!);
        _drawDashedLine(canvas, from, drop, FactionColors.gold.withValues(alpha: 0.55));
      }
    }

    // Drag rubber-band (must stay in lower 2/3; never cover bottom bar — bar is outside)
    if (dragging && dragFrom != null && dragTo != null) {
      _drawDashedLine(canvas, dragFrom!, dragTo!, const Color(0xFF80DEEA));
    }

    const tokenR = 28.0;
    for (var i = 0; i < field.length; i++) {
      final card = field[i];
      final center = tokenCenter(i);
      final selected = selectedIndex == i;
      final isOwn = tutorialOwnIndex == i;
      final isEnemy = tutorialEnemyIndex == i;
      final dim = t != null &&
          t.session == TutorialSession.session1 &&
          !isOwn &&
          (t.s1 == S1Phase.highlightSelect ||
              t.s1 == S1Phase.dragGuide ||
              t.s1 == S1Phase.waitAura ||
              t.s1 == S1Phase.hitCharge);

      _drawFieldTelegraph(canvas, center, card, i, isOwn: isOwn, isEnemy: isEnemy);

      final base = _tokenFill(card);
      final fill = dim ? base.withValues(alpha: 0.28) : base;
      canvas.drawCircle(center, tokenR, Paint()..color = fill);
      // Shu: punch green on top of cyan charge aura so token never reads Wei-blue.
      if (!dim && card.faction == Faction.shu) {
        canvas.drawCircle(center, tokenR - 3, Paint()..color = const Color(0xFF66BB6A));
        canvas.drawCircle(center, tokenR - 10, Paint()..color = const Color(0xFF43A047));
      }

      // Gold ring on own tutorial target
      final ringGold = (isOwn && t != null) || selected;
      canvas.drawCircle(
        center,
        tokenR,
        Paint()
          ..color = ringGold ? FactionColors.gold : Colors.white24
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringGold ? 4 : 2,
      );
      if (isOwn && t != null && t.session == TutorialSession.session1) {
        // Extra outer gold ring highlight
        final pulse = 0.5 + 0.5 * math.sin(_pulse * 3);
        canvas.drawCircle(
          center,
          tokenR + 6 + pulse * 3,
          Paint()
            ..color = FactionColors.gold.withValues(alpha: 0.45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }

      _drawWeapon(canvas, Offset(center.dx, center.dy - 2), card.troop, dim ? Colors.white38 : Colors.white);
      // Name above Cost so ●●○ is not covered by glyphs.
      _drawText(
        canvas,
        card.nameZh,
        Offset(center.dx - 18, center.dy + tokenR + 2),
        dim ? FactionColors.gold.withValues(alpha: 0.35) : FactionColors.gold,
        11,
      );
      _drawCostStars(canvas, Offset(center.dx - 18, center.dy + tokenR + 18), card.cost);
    }

    // Floating 突撃 button (session1)
    if (t != null &&
        t.session == TutorialSession.session1 &&
        (t.s1 == S1Phase.hitCharge || t.s1 == S1Phase.waitAura || t.shotPassMode && t.s1 == S1Phase.tipNext)) {
      final at = tutorialOwnIndex != null ? tokenCenter(tutorialOwnIndex!) : dropGuidePoint;
      final ready = t.auraReady || t.shotPassMode;
      _drawFloatingAction(canvas, Offset(at.dx, at.dy - 56), '突撃', ready);
    }

    // Floating 迎擊 (session2)
    if (t != null &&
        t.session == TutorialSession.session2 &&
        (t.s2 == S2Phase.interceptHit ||
            t.s2 == S2Phase.waitTurn ||
            t.s2 == S2Phase.strategyOrReturn ||
            t.s2 == S2Phase.tipDone ||
            t.shotPassMode)) {
      final at = tutorialOwnIndex != null ? tokenCenter(tutorialOwnIndex!) : Offset(w * 0.35, wh + 160);
      final ready = t.facingCorrect || t.shotPassMode;
      _drawFloatingAction(canvas, Offset(at.dx, at.dy - 56), '迎擊', ready);
    }

    if (_hitFlashLeft > 0 && _hitFlashIndex != null && _hitFlashIndex! < field.length) {
      final c = tokenCenter(_hitFlashIndex!);
      _drawText(canvas, _hitFlashLabel, Offset(c.dx - 16, c.dy - 72), const Color(0xFF80DEEA), 14);
      canvas.drawCircle(
        c,
        40,
        Paint()
          ..color = const Color(0xFF80DEEA).withValues(alpha: (_hitFlashLeft * 2).clamp(0, 0.5))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    if (_stratLeft > 0 && _stratAt != null) {
      _drawStratagemBurst(canvas, _stratAt!, _stratLeft / FxWindows.toSeconds(FxWindows.strategyFxMaxC));
    }

    if (_returnFlashLeft > 0) {
      final a = (_returnFlashLeft / 0.6).clamp(0.0, 1.0);
      canvas.drawRect(
        Rect.fromLTWH(0, fieldTop, w, h - fieldTop),
        Paint()..color = FactionColors.gold.withValues(alpha: 0.12 * a),
      );
      _drawText(canvas, '歸城', Offset(w * 0.5 - 24, fieldTop + 40), FactionColors.gold.withValues(alpha: a), 18);
    }
  }

  void _drawFloatingAction(Canvas canvas, Offset at, String label, bool ready) {
    final bg = ready ? FactionColors.gold : Colors.white24;
    final fg = ready ? FactionColors.lacquer : Colors.white54;
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: at, width: 72, height: 32),
      const Radius.circular(8),
    );
    canvas.drawRRect(r, Paint()..color = bg);
    _drawText(canvas, label, Offset(at.dx - 18, at.dy - 8), fg, 14);
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

  void _drawWatchTelegraph(Canvas canvas, Rect band) {
    final c = Offset(band.center.dx, band.top + band.height * 0.58);
    if (showAWindowDebugLabels) {
      final label = switch (watchKind) {
        AWindowKind.charge => '突撃オーラ ≥1C',
        AWindowKind.intercept => '迎擊 槍尖常駐',
        AWindowKind.bow => '弓停射 ~1C',
        AWindowKind.stratagem => '計略',
      };
      _drawText(canvas, label, Offset(16, band.top + 48), const Color(0xFF80DEEA), 13);
    }

    switch (watchKind) {
      case AWindowKind.charge:
        _drawChargeRings(canvas, c, 42, const Color(0xFF00E5FF));
        break;
      case AWindowKind.intercept:
        _drawInterceptStance(canvas, c, 50, const Color(0xFF26C6DA));
        break;
      case AWindowKind.bow:
        _drawBowWindup(canvas, c, band.right - 40, const Color(0xFFFFD54F));
        break;
      case AWindowKind.stratagem:
        break;
    }

    canvas.drawCircle(c, 22, Paint()..color = FactionColors.wei.withValues(alpha: 0.55));
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
      // Charge aura while waiting / ready / pass
      if (t.s1 == S1Phase.waitAura ||
          t.s1 == S1Phase.hitCharge ||
          t.s1 == S1Phase.tipNext ||
          t.shotPassMode) {
        _drawChargeRings(canvas, c, 44, const Color(0xFF00E5FF).withValues(alpha: 0.35));
      }
      return;
    }
    if (t != null && t.session == TutorialSession.session2) {
      if (isOwn && card.troop == TroopType.spear) {
        _drawInterceptStance(canvas, c, 40, const Color(0xFF26C6DA).withValues(alpha: 0.65), facing: ownFacing);
        return;
      }
      if (isEnemy && (t.enemyAuraVisible || t.shotPassMode)) {
        _drawChargeRings(canvas, c, 36, const Color(0xFF00E5FF).withValues(alpha: 0.65));
        return;
      }
    }

    // Match / demo telegraph by troop
    switch (card.troop) {
      case TroopType.cavalry:
        _drawChargeRings(canvas, c, 36, const Color(0xFF00E5FF).withValues(alpha: 0.55));
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

  void _drawChargeRings(Canvas canvas, Offset c, double baseR, Color color) {
    final t = (_pulse % 1.2) / 1.2;
    for (var i = 0; i < 3; i++) {
      final r = baseR + i * 10 + t * 14;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = color.withValues(alpha: 0.55 - i * 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    }
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 + _pulse;
      canvas.drawLine(
        Offset(c.dx + math.cos(a) * (baseR - 6), c.dy + math.sin(a) * (baseR - 6)),
        Offset(c.dx + math.cos(a) * (baseR + 18), c.dy + math.sin(a) * (baseR + 18)),
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..strokeWidth = 1.4,
      );
    }
  }

  void _drawInterceptStance(Canvas canvas, Offset c, double rx, Color color, {double facing = 0}) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(facing);
    canvas.translate(-c.dx, -c.dy);

    final oval = Rect.fromCenter(center: c, width: rx * 2.2, height: rx * 1.1);
    canvas.drawOval(
      oval,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final wedge = Path()
      ..moveTo(c.dx, c.dy - 4)
      ..lineTo(c.dx - 18, c.dy + 22)
      ..lineTo(c.dx + 18, c.dy + 22)
      ..close();
    canvas.drawPath(wedge, Paint()..color = color.withValues(alpha: 0.45));
    // Persistent spear tip glow
    final glow = 0.6 + 0.4 * math.sin(_pulse * 4);
    canvas.drawCircle(
      Offset(c.dx, c.dy - 26),
      7,
      Paint()..color = Colors.white.withValues(alpha: 0.35 * glow),
    );
    canvas.drawCircle(Offset(c.dx, c.dy - 26), 5, Paint()..color = Colors.white.withValues(alpha: 0.9));
    canvas.drawLine(
      Offset(c.dx, c.dy + 16),
      Offset(c.dx, c.dy - 28),
      Paint()
        ..color = color
        ..strokeWidth = 2.5
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
    final alpha = (life01.clamp(0.0, 1.0)) * 0.55;
    final cone = Path()
      ..moveTo(at.dx, at.dy)
      ..lineTo(at.dx + 90, at.dy - 40)
      ..lineTo(at.dx + 90, at.dy + 40)
      ..close();
    canvas.drawPath(cone, Paint()..color = FactionColors.gold.withValues(alpha: alpha));
    canvas.drawCircle(
      at,
      28 + (1 - life01) * 20,
      Paint()
        ..color = FactionColors.gold.withValues(alpha: alpha * 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    if (showAWindowDebugLabels) {
      _drawText(canvas, '計略 ≤1C', Offset(at.dx - 10, at.dy - 52), FactionColors.gold.withValues(alpha: 0.9), 12);
    }
  }

  bool spawnCard(CardFace card) {
    if (field.length >= fieldMax) return false;
    const tokenR = 28.0;
    final i = field.length;
    field.add(card);
    fieldPos.add(Offset(48.0 + i * (tokenR * 2 + 20), watchH + 110));
    return true;
  }

  int? hitTokenAt(Offset local) {
    if (local.dy < watchH) return null; // top 1/3 read-only
    const tokenR = 28.0;
    for (var i = 0; i < field.length; i++) {
      final c = tokenCenter(i);
      final dx = local.dx - c.dx;
      final dy = local.dy - c.dy;
      if (dx * dx + dy * dy <= (tokenR + 8) * (tokenR + 8)) return i;
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
      // Dimmed others: ignore select in highlight phase
      if (t.s1 == S1Phase.highlightSelect || t.s1 == S1Phase.dragGuide) return;
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
    if (t == null || t.session != TutorialSession.session1) return;
    if (t.s1 != S1Phase.dragGuide && t.s1 != S1Phase.highlightSelect) return;
    final i = hitTokenAt(local);
    if (i != tutorialOwnIndex) return;
    selectedIndex = i;
    t.onSelectOwnCavalry();
    dragging = true;
    dragFrom = tokenCenter(i!);
    dragTo = local;
    onTutorialChanged?.call();
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
    }
    dragFrom = null;
    dragTo = null;
  }

  void flashHit(int index, String label) {
    _hitFlashIndex = index;
    _hitFlashLabel = label;
    _hitFlashLeft = FxWindows.toSeconds(FxWindows.interceptHitFlashC);
  }

  /// Stratagem FX ≤1C on field; non-blocking (board stays tappable).
  void triggerStrategyFx() {
    final t = tutorial;
    if (selectedIndex != null && selectedIndex! < field.length) {
      final i = selectedIndex!;
      _stratAt = tokenCenter(i);
      if (field[i].troop == TroopType.spear) {
        flashHit(i, '迎擊');
      }
    } else if (tutorialOwnIndex != null) {
      _stratAt = tokenCenter(tutorialOwnIndex!);
    } else {
      _stratAt = Offset(size.x * 0.45, watchH + 130);
    }
    _stratLeft = FxWindows.toSeconds(FxWindows.strategyFxMaxC);
    t?.onStrategy();
    onTutorialChanged?.call();
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

  /// Cost: exactly 3 slots as ● / ◐ / ○ (>=8dp). Cost2 = ●●○.
  void _drawCostStars(Canvas canvas, Offset origin, double cost) {
    var rem = cost.clamp(0.0, 3.0);
    const slot = 10.0;
    const gap = 4.0;
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
      final c = Offset(origin.dx + i * (slot + gap) + slot / 2, origin.dy + slot / 2);
      final rad = slot / 2;
      if (fill >= 1) {
        canvas.drawCircle(c, rad, Paint()..color = FactionColors.gold);
      } else if (fill >= 0.5) {
        canvas.drawCircle(
          c,
          rad,
          Paint()
            ..color = Colors.white70
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        canvas.save();
        canvas.clipRect(Rect.fromLTRB(c.dx - rad - 0.5, c.dy - rad - 0.5, c.dx, c.dy + rad + 0.5));
        canvas.drawCircle(c, rad, Paint()..color = FactionColors.gold);
        canvas.restore();
      } else {
        canvas.drawCircle(
          c,
          rad,
          Paint()
            ..color = Colors.white70
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
      }
    }
  }

  void _drawWeapon(Canvas canvas, Offset c, TroopType troop, Color color) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    switch (troop) {
      case TroopType.cavalry:
        canvas.drawLine(Offset(c.dx - 10, c.dy + 8), Offset(c.dx + 10, c.dy - 10), p);
        canvas.drawCircle(Offset(c.dx + 10, c.dy - 10), 3.5, Paint()..color = color);
        canvas.drawCircle(c, 7, p);
        break;
      case TroopType.spear:
        canvas.drawLine(Offset(c.dx, c.dy + 12), Offset(c.dx, c.dy - 12), p);
        canvas.drawLine(Offset(c.dx - 5, c.dy - 8), Offset(c.dx, c.dy - 12), p);
        canvas.drawLine(Offset(c.dx + 5, c.dy - 8), Offset(c.dx, c.dy - 12), p);
        break;
      case TroopType.bow:
        final arc = Path()
          ..moveTo(c.dx - 8, c.dy - 10)
          ..quadraticBezierTo(c.dx + 10, c.dy, c.dx - 8, c.dy + 10);
        canvas.drawPath(arc, p);
        canvas.drawLine(Offset(c.dx - 8, c.dy - 10), Offset(c.dx - 8, c.dy + 10), p);
        canvas.drawLine(Offset(c.dx - 6, c.dy), Offset(c.dx + 8, c.dy), p);
        break;
      case TroopType.siege:
        canvas.drawRect(Rect.fromCenter(center: c, width: 14, height: 10), p);
        canvas.drawLine(Offset(c.dx - 10, c.dy + 8), Offset(c.dx + 10, c.dy + 8), p);
        break;
      case TroopType.infantry:
        canvas.drawLine(Offset(c.dx, c.dy - 10), Offset(c.dx, c.dy + 6), p);
        canvas.drawLine(Offset(c.dx - 7, c.dy - 2), Offset(c.dx + 7, c.dy - 2), p);
        canvas.drawLine(Offset(c.dx, c.dy + 6), Offset(c.dx - 6, c.dy + 12), p);
        canvas.drawLine(Offset(c.dx, c.dy + 6), Offset(c.dx + 6, c.dy + 12), p);
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
