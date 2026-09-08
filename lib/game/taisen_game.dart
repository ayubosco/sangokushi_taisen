import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../data/card_models.dart';
import 'c_clock.dart';
import 'faction_colors.dart';
import 'fx_windows.dart';

enum AWindowKind { charge, intercept, bow, stratagem }

/// Offline 1v1 CPU stub: top 1/3 watch (read-only), bottom 2/3 flat field.
class TaisenGame extends FlameGame {
  final CClock clock = CClock();
  static const int fieldMax = 5;
  static const double costCap = 6;

  final List<CardFace> field = [];
  int? selectedIndex;

  /// Enemy-watch telegraph demo cycle (no combat numbers).
  AWindowKind watchKind = AWindowKind.charge;
  double _watchPhaseLeft = FxWindows.toSeconds(FxWindows.chargeAuraVisibleC);
  double _pulse = 0;

  /// Stratagem burst on field (≤1C, non-blocking).
  double _stratLeft = 0;
  Offset? _stratAt;

  /// Optional intercept hit flash on a field token.
  int? _interceptFlashIndex;
  double _interceptFlashLeft = 0;

  void Function(CardFace card)? onRequestDetail;

  @override
  Color backgroundColor() => FactionColors.lacquer;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.anchor = Anchor.topLeft;
    clock.reset();
  }

  @override
  void update(double dt) {
    super.update(dt);
    clock.update(dt);
    _pulse += dt;

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
    if (_interceptFlashLeft > 0) {
      _interceptFlashLeft -= dt;
      if (_interceptFlashLeft <= 0) {
        _interceptFlashLeft = 0;
        _interceptFlashIndex = null;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final w = size.x;
    final h = size.y;
    final watchH = h / 3;
    final fieldTop = watchH;

    canvas.drawRect(Rect.fromLTWH(0, 0, w, watchH), Paint()..color = const Color(0xFF1A1A1A));
    _drawText(canvas, '敵軍監視（只讀）', Offset(16, 24), FactionColors.gold, 16);
    _drawWatchTelegraph(canvas, Rect.fromLTWH(0, 0, w, watchH));

    canvas.drawRect(Rect.fromLTWH(0, fieldTop, w, h - watchH), Paint()..color = const Color(0xFF121212));
    canvas.drawLine(
      Offset(0, fieldTop),
      Offset(w, fieldTop),
      Paint()
        ..color = FactionColors.gold
        ..strokeWidth = 2,
    );

    _drawText(
      canvas,
      '場即係盤 · Cost $costCap · 場上 ${field.length}/$fieldMax',
      Offset(16, fieldTop + 12),
      FactionColors.gold,
      14,
    );

    const tokenR = 28.0;
    for (var i = 0; i < field.length; i++) {
      final card = field[i];
      final cx = 48.0 + i * (tokenR * 2 + 20);
      final cy = fieldTop + 110;
      final selected = selectedIndex == i;
      final center = Offset(cx, cy);

      _drawFieldTelegraph(canvas, center, card, i);

      canvas.drawCircle(center, tokenR, Paint()..color = card.factionColor);
      canvas.drawCircle(
        center,
        tokenR,
        Paint()
          ..color = selected ? FactionColors.gold : Colors.white24
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 4 : 2,
      );

      _drawWeapon(canvas, Offset(cx, cy - 2), card.troop, Colors.white);
      _drawCostStars(canvas, Offset(cx - 16, cy + tokenR + 2), card.cost);
      _drawText(canvas, card.nameZh, Offset(cx - 18, cy + tokenR + 16), FactionColors.gold, 11);
    }

    if (_stratLeft > 0 && _stratAt != null) {
      _drawStratagemBurst(canvas, _stratAt!, _stratLeft / FxWindows.toSeconds(FxWindows.strategyFxMaxC));
    }
  }

  void _drawWatchTelegraph(Canvas canvas, Rect band) {
    final c = Offset(band.center.dx, band.top + band.height * 0.58);
    final label = switch (watchKind) {
      AWindowKind.charge => '突撃オーラ ≥1C',
      AWindowKind.intercept => '迎擊 槍尖常駐',
      AWindowKind.bow => '弓停射 ~1C',
      AWindowKind.stratagem => '計略',
    };
    _drawText(canvas, label, Offset(16, band.top + 48), const Color(0xFF80DEEA), 13);

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

    // Soft enemy token silhouette under FX
    canvas.drawCircle(c, 22, Paint()..color = FactionColors.wei.withValues(alpha: 0.55));
  }

  void _drawFieldTelegraph(Canvas canvas, Offset c, CardFace card, int index) {
    // Flat, quieter versions of watch FX by troop
    switch (card.troop) {
      case TroopType.cavalry:
        _drawChargeRings(canvas, c, 36, const Color(0xFF00E5FF).withValues(alpha: 0.55));
        break;
      case TroopType.spear:
        _drawInterceptStance(canvas, c, 40, const Color(0xFF26C6DA).withValues(alpha: 0.5));
        if (_interceptFlashIndex == index && _interceptFlashLeft > 0) {
          _drawText(canvas, '迎擊', Offset(c.dx - 16, c.dy - 48), const Color(0xFF80DEEA), 12);
        }
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

  void _drawInterceptStance(Canvas canvas, Offset c, double rx, Color color) {
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
    // spear tip flash
    canvas.drawCircle(Offset(c.dx, c.dy - 26), 5, Paint()..color = Colors.white.withValues(alpha: 0.9));
    canvas.drawLine(
      Offset(c.dx, c.dy + 16),
      Offset(c.dx, c.dy - 28),
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
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
    // light column
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
    _drawText(canvas, '計略 ≤1C', Offset(at.dx - 10, at.dy - 52), FactionColors.gold.withValues(alpha: 0.9), 12);
  }

  bool spawnCard(CardFace card) {
    if (field.length >= fieldMax) return false;
    field.add(card);
    return true;
  }

  void selectOrDetailAt(Offset local) {
    final watchH = size.y / 3;
    // Watch band is read-only — ignore taps in top 1/3 for selection
    if (local.dy < watchH) return;

    const tokenR = 28.0;
    for (var i = 0; i < field.length; i++) {
      final cx = 48.0 + i * (tokenR * 2 + 20);
      final cy = watchH + 110;
      final dx = local.dx - cx;
      final dy = local.dy - cy;
      if (dx * dx + dy * dy <= (tokenR + 8) * (tokenR + 8)) {
        if (selectedIndex == i) {
          onRequestDetail?.call(field[i]);
        } else {
          selectedIndex = i;
        }
        return;
      }
    }
    selectedIndex = null;
  }

  /// Stratagem FX ≤1C on field; does not cover bottom bar (drawn inside game only).
  void triggerStrategyFx() {
    final watchH = size.y / 3;
    if (selectedIndex != null && selectedIndex! < field.length) {
      final i = selectedIndex!;
      const tokenR = 28.0;
      _stratAt = Offset(48.0 + i * (tokenR * 2 + 20), watchH + 110);
      // Spearmen get a short intercept hit flash when strategy demos on them
      if (field[i].troop == TroopType.spear) {
        _interceptFlashIndex = i;
        _interceptFlashLeft = FxWindows.toSeconds(FxWindows.interceptHitFlashC);
      }
    } else {
      _stratAt = Offset(size.x * 0.45, watchH + 130);
    }
    _stratLeft = FxWindows.toSeconds(FxWindows.strategyFxMaxC);
  }

  void _drawCostStars(Canvas canvas, Offset origin, double cost) {
    var rem = cost.clamp(0, 3);
    for (var i = 0; i < 3; i++) {
      final fill = rem >= 1 ? 1.0 : (rem >= 0.5 ? 0.5 : 0.0);
      rem = rem >= 1 ? rem - 1 : (rem >= 0.5 ? rem - 0.5 : 0);
      _drawStar(canvas, Offset(origin.dx + i * 12.0, origin.dy), 5.5, fill);
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
          ..strokeWidth = 1.2,
      );
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
