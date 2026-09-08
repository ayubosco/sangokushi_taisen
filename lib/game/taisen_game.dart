import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import 'c_clock.dart';
import 'faction_colors.dart';
import 'fx_windows.dart';

/// Offline 1v1 CPU stub: top 1/3 watch (read-only), bottom 2/3 flat field.
class TaisenGame extends FlameGame {
  final CClock clock = CClock();
  int fieldCount = 0;
  static const int fieldMax = 5;
  static const double costCap = 6;

  String _fxLabel = '';
  double _fxLeft = 0;

  @override
  Color backgroundColor() => FactionColors.lacquer;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.anchor = Anchor.topLeft;
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
    final watchPaint = Paint()..color = const Color(0xFF1A1A1A);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, watchH), watchPaint);
    _drawText(canvas, '敵軍監視（只讀）', Offset(16, 24), FactionColors.gold, 16);
    _drawText(
      canvas,
      'オーラ≥${FxWindows.chargeAuraVisibleC}C · 迎擊常駐 · 弓停~${FxWindows.bowStopBeforeShotC}C',
      Offset(16, 52),
      const Color(0xFFCCCCCC),
      12,
    );

    // Bottom 2/3 — flat field
    final fieldPaint = Paint()..color = const Color(0xFF121212);
    canvas.drawRect(Rect.fromLTWH(0, fieldTop, w, h - watchH), fieldPaint);
    final goldLine = Paint()
      ..color = FactionColors.gold
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, fieldTop), Offset(w, fieldTop), goldLine);

    _drawText(canvas, '場即係盤 · Cost $costCap · 場上 $fieldCount/$fieldMax', Offset(16, fieldTop + 16), FactionColors.gold, 14);
    _drawText(canvas, '1v1 CPU stub · 計略 FX ≤${FxWindows.strategyFxMaxC}C 唔擋盤', Offset(16, fieldTop + 40), const Color(0xFFAAAAAA), 12);

    // Token placeholders
    for (var i = 0; i < fieldCount; i++) {
      final cx = 40.0 + i * 56;
      final cy = fieldTop + 100;
      canvas.drawCircle(Offset(cx, cy), 22, Paint()..color = FactionColors.shu);
      canvas.drawCircle(
        Offset(cx, cy),
        22,
        Paint()
          ..color = FactionColors.gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    if (_fxLabel.isNotEmpty) {
      // Short FX banner in bottom zone only — never covers full screen
      final banner = Rect.fromLTWH(w * 0.15, h - 120, w * 0.7, 36);
      canvas.drawRRect(
        RRect.fromRectAndRadius(banner, const Radius.circular(8)),
        Paint()..color = FactionColors.gold.withValues(alpha: 0.85),
      );
      _drawText(canvas, _fxLabel, Offset(banner.left + 12, banner.top + 8), FactionColors.lacquer, 14);
    }
  }

  void spawnPlaceholderUnit() {
    if (fieldCount < fieldMax) fieldCount++;
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
