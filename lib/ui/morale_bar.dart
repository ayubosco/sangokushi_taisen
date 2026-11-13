import 'package:flutter/material.dart';

import '../game/faction_colors.dart';

/// HUD 士氣 bar. One gold hex per point of [morale].
///
/// 英傑 stage 5 用計得宜:「士氣欄高亮提示計略所需士氣值」. While a caster's
/// 計略範圍 is up, [need] is that card's printed 士氣. The trailing [need] pips,
/// which are the ones a cast would spend, light up. When the pool is short, the
/// missing points show as outlined hexes after the fill, so the player can see
/// how far regen still has to go. The bar is not a 6/2 table and has no
/// regen rate. The cost always comes from the card face.
///
/// With [cap] set, the bar is a fixed track as on the reference gauge: every
/// point up to the ceiling has a socket, the empty ones stay dark, and the next
/// one fills by [charge] while 士氣 recovers.
class MoraleBar extends StatelessWidget {
  const MoraleBar({super.key, required this.morale, this.need, this.cap, this.charge = 0});

  final int morale;

  /// Regen ceiling. Null keeps the bar to the filled pips only.
  final int? cap;

  /// How far the next point has filled, 0–1.
  final double charge;

  /// Dark sockets after the fill and after any short pips.
  static int socketPips(int morale, int? need, int? cap) {
    if (cap == null) return 0;
    final used = (morale < 0 ? 0 : morale) + shortPips(morale, need);
    return cap > used ? cap - used : 0;
  }

  /// Printed 士氣 of the previewed 計略. Null when no range is up.
  final int? need;

  /// Pips the cast would spend, counted from the end of the pool.
  static int litPips(int morale, int? need) {
    if (need == null || need <= 0 || morale <= 0) return 0;
    return need < morale ? need : morale;
  }

  /// Points the pool is short of [need]. 0 when the cast is affordable.
  static int shortPips(int morale, int? need) {
    if (need == null || need <= morale) return 0;
    return need - (morale < 0 ? 0 : morale);
  }

  @override
  Widget build(BuildContext context) {
    final lit = litPips(morale, need);
    final short = shortPips(morale, need);
    final ready = need != null && short == 0;
    final sockets = socketPips(morale, need, cap);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < morale; i++)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: i >= morale - lit
                ? KeyedSubtree(
                    key: const Key('match-morale-need'),
                    child: _MoraleHex(lit: true, ready: ready),
                  )
                : const _MoraleHex(),
          ),
        for (var i = 0; i < short; i++)
          const Padding(
            padding: EdgeInsets.only(right: 2),
            child: _MoraleHex(key: Key('match-morale-short'), empty: true),
          ),
        for (var i = 0; i < sockets; i++)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: CustomPaint(
              key: const Key('match-morale-socket'),
              size: const Size(9, 10),
              painter: _MoraleSocketPainter(charge: i == 0 && short == 0 ? charge : 0),
            ),
          ),
      ],
    );
  }
}

/// One printed 士氣 point. Filled pips keep the `match-morale-pip` key.
class _MoraleHex extends StatelessWidget {
  const _MoraleHex({super.key, this.lit = false, this.ready = false, this.empty = false});

  final bool lit;
  final bool ready;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      key: empty ? null : const Key('match-morale-pip'),
      size: const Size(9, 10),
      painter: _MoraleHexPainter(lit: lit, ready: ready, empty: empty),
    );
  }
}

class _MoraleHexPainter extends CustomPainter {
  _MoraleHexPainter({required this.lit, required this.ready, required this.empty});

  final bool lit;
  final bool ready;
  final bool empty;

  static const Color _litReady = Color(0xFFFFF3B0);
  static const Color _litShort = Color(0xFFFF8A65);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, h * 0.25)
      ..lineTo(w, h * 0.75)
      ..lineTo(w * 0.5, h)
      ..lineTo(0, h * 0.75)
      ..lineTo(0, h * 0.25)
      ..close();
    if (empty) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = _litShort,
      );
      return;
    }
    if (!lit) {
      canvas.drawPath(path, Paint()..color = FactionColors.gold);
      return;
    }
    final glow = ready ? _litReady : _litShort;
    canvas.drawPath(
      path,
      Paint()
        ..color = glow.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
    canvas.drawPath(path, Paint()..color = glow);
  }

  @override
  bool shouldRepaint(covariant _MoraleHexPainter oldDelegate) =>
      oldDelegate.lit != lit || oldDelegate.ready != ready || oldDelegate.empty != empty;
}

/// A point the pool does not hold yet. Dark, with a gold fill rising by [charge].
class _MoraleSocketPainter extends CustomPainter {
  _MoraleSocketPainter({required this.charge});

  final double charge;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, h * 0.25)
      ..lineTo(w, h * 0.75)
      ..lineTo(w * 0.5, h)
      ..lineTo(0, h * 0.75)
      ..lineTo(0, h * 0.25)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF2A241C));
    final fill = charge.clamp(0.0, 1.0);
    if (fill > 0) {
      canvas.save();
      canvas.clipPath(path);
      canvas.drawRect(
        Rect.fromLTRB(0, h * (1 - fill), w, h),
        Paint()..color = FactionColors.gold.withValues(alpha: 0.7),
      );
      canvas.restore();
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = FactionColors.gold.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant _MoraleSocketPainter oldDelegate) => oldDelegate.charge != charge;
}
