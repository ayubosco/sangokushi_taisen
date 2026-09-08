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

  /// Opened from Flutter overlay when a token is tapped twice / detail requested.
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

    // Top 1/3 — enemy watch (read-only placeholder)
    canvas.drawRect(Rect.fromLTWH(0, 0, w, watchH), Paint()..color = const Color(0xFF1A1A1A));
    _drawText(canvas, '敵軍監視（只讀）', Offset(16, 24), FactionColors.gold, 16);

    // Bottom 2/3 — flat field
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

    // Tokens: COST stars + troop + name (≥48dp hit via large disk)
    const tokenR = 28.0; // ~56dp diameter
    for (var i = 0; i < field.length; i++) {
      final card = field[i];
      final cx = 48.0 + i * (tokenR * 2 + 16);
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

      _drawText(
        canvas,
        card.troopLabel,
        Offset(cx - 8, cy - 10),
        Colors.white,
        14,
      );
      _drawText(
        canvas,
        card.nameZh,
        Offset(cx - 20, cy + tokenR + 4),
        FactionColors.gold,
        11,
      );
      // Cost as compact text under name (stars drawn in Flutter overlay for clarity)
      _drawText(
        canvas,
        '★${card.cost}',
        Offset(cx - 14, cy + tokenR + 18),
        Colors.white70,
        10,
      );
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
      final cx = 48.0 + i * (tokenR * 2 + 16);
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

  void triggerChargeAuraDemo() {
    _fxLabel = '突撃オーラ';
    _fxLeft = FxWindows.toSeconds(FxWindows.chargeAuraVisibleC);
  }

  void _drawText(Canvas canvas, String text, Offset at, Color color, double size) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: this.size.x - at.dx - 8);
    tp.paint(canvas, at);
  }
}
