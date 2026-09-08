import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../data/card_models.dart';
import 'c_clock.dart';
import 'faction_colors.dart';
import 'fx_windows.dart';

/// Offline 1v1 CPU stub: top 1/3 watch (read-only), bottom 2/3 flat field.
class TaisenGame extends FlameGame {
  final CClock clock = CClock();
  static const int fieldMax = 5;
  static const double costCap = 6;

  final List<CardFace> field = [];
  int? selectedIndex;

  String _fxLabel = '';
  double _fxLeft = 0;

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
    if (_fxLeft > 0) {
      _fxLeft -= dt;
      if (_fxLeft <= 0) {
        _fxLeft = 0;
        _fxLabel = '';
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

      canvas.drawCircle(Offset(cx, cy), tokenR, Paint()..color = card.factionColor);
      canvas.drawCircle(
        Offset(cx, cy),
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

    if (_fxLabel.isNotEmpty) {
      final banner = Rect.fromLTWH(w * 0.15, h - 120, w * 0.7, 36);
      canvas.drawRRect(
        RRect.fromRectAndRadius(banner, const Radius.circular(8)),
        Paint()..color = FactionColors.gold.withValues(alpha: 0.85),
      );
      _drawText(canvas, _fxLabel, Offset(banner.left + 12, banner.top + 8), FactionColors.lacquer, 14);
    }
  }

  bool spawnCard(CardFace card) {
    if (field.length >= fieldMax) return false;
    field.add(card);
    return true;
  }

  void selectOrDetailAt(Offset local) {
    final watchH = size.y / 3;
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

  void triggerStrategyFx() {
    _fxLabel = '計略';
    _fxLeft = FxWindows.toSeconds(FxWindows.strategyFxMaxC);
  }

  void _drawCostStars(Canvas canvas, Offset origin, double cost) {
    var rem = cost.clamp(0, 3);
    for (var i = 0; i < 3; i++) {
      final fill = rem >= 1 ? 1.0 : (rem >= 0.5 ? 0.5 : 0.0);
      rem = rem >= 1 ? rem - 1 : 0;
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
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(c.dx - r, c.dy - r, r, r * 2));
      canvas.drawPath(path, Paint()..color = FactionColors.gold);
      canvas.restore();
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white70
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
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
