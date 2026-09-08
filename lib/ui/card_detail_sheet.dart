import 'package:flutter/material.dart';

import '../data/card_models.dart';
import '../game/faction_colors.dart';
import 'cost_stars.dart';

Future<void> showCardDetailSheet(BuildContext context, CardFace card) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final h = MediaQuery.of(ctx).size.height * 0.55;
      return Container(
        height: h,
        decoration: BoxDecoration(
          color: FactionColors.lacquer,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border.all(color: FactionColors.gold, width: 2),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(height: 6, color: card.factionColor),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    iconSize: 28,
                    icon: const Icon(Icons.close, color: FactionColors.gold),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          card.portraitAsset,
                          width: 120,
                          height: 160,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 120,
                            height: 160,
                            color: card.factionColor.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: ListView(
                          children: [
                            Text(
                              card.nameZh,
                              style: const TextStyle(
                                color: FactionColors.gold,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                CostStars(cost: card.cost, size: 14),
                                const SizedBox(width: 10),
                                _WeaponGlyph(troop: card.troop),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '武 ${card.force}　知 ${card.intel}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14),
                            ),
                            if (card.skills.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    for (final s in card.skills.take(3))
                                      Padding(
                                        padding: const EdgeInsets.only(right: 4),
                                        child: Chip(
                                          label: Text(s),
                                          visualDensity: VisualDensity.compact,
                                          backgroundColor: const Color(0xFF222222),
                                          labelStyle: const TextStyle(
                                            color: FactionColors.gold,
                                            fontSize: 12,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                            const Divider(color: FactionColors.gold),
                            Text(
                              '${card.strategyName}（士氣 ${card.strategyMorale}）',
                              style: const TextStyle(
                                color: FactionColors.gold,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              card.strategyEffect,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _WeaponGlyph extends StatelessWidget {
  const _WeaponGlyph({required this.troop});
  final TroopType troop;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(28, 28),
      painter: _TroopPainter(troop),
      child: const SizedBox(width: 28, height: 28),
    );
  }
}

class _TroopPainter extends CustomPainter {
  _TroopPainter(this.troop);
  final TroopType troop;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final p = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    switch (troop) {
      case TroopType.cavalry:
        canvas.drawLine(Offset(c.dx - 8, c.dy + 6), Offset(c.dx + 8, c.dy - 8), p);
        canvas.drawCircle(Offset(c.dx + 8, c.dy - 8), 2.5, Paint()..color = Colors.white);
        canvas.drawCircle(c, 5, p);
        break;
      case TroopType.spear:
        canvas.drawLine(Offset(c.dx, c.dy + 10), Offset(c.dx, c.dy - 10), p);
        canvas.drawLine(Offset(c.dx - 4, c.dy - 6), Offset(c.dx, c.dy - 10), p);
        canvas.drawLine(Offset(c.dx + 4, c.dy - 6), Offset(c.dx, c.dy - 10), p);
        break;
      case TroopType.bow:
        final arc = Path()
          ..moveTo(c.dx - 6, c.dy - 8)
          ..quadraticBezierTo(c.dx + 8, c.dy, c.dx - 6, c.dy + 8);
        canvas.drawPath(arc, p);
        canvas.drawLine(Offset(c.dx - 6, c.dy - 8), Offset(c.dx - 6, c.dy + 8), p);
        canvas.drawLine(Offset(c.dx - 4, c.dy), Offset(c.dx + 6, c.dy), p);
        break;
      case TroopType.siege:
        canvas.drawRect(Rect.fromCenter(center: c, width: 12, height: 8), p);
        canvas.drawLine(Offset(c.dx - 8, c.dy + 6), Offset(c.dx + 8, c.dy + 6), p);
        break;
      case TroopType.infantry:
        canvas.drawLine(Offset(c.dx, c.dy - 8), Offset(c.dx, c.dy + 4), p);
        canvas.drawLine(Offset(c.dx - 5, c.dy - 2), Offset(c.dx + 5, c.dy - 2), p);
        canvas.drawLine(Offset(c.dx, c.dy + 4), Offset(c.dx - 4, c.dy + 9), p);
        canvas.drawLine(Offset(c.dx, c.dy + 4), Offset(c.dx + 4, c.dy + 9), p);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
