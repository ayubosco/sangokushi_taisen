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
    final col = switch (troop) {
      TroopType.cavalry => 0,
      TroopType.spear => 1,
      TroopType.bow => 2,
      TroopType.infantry => 3,
      TroopType.siege => 3,
    };
    // Atlas 1280×720 / 4 cells; crop circular badge (skip label).
    const sheetW = 1280.0;
    const cell = 320.0;
    const pad = 48.0;
    const src = 224.0;
    const out = 28.0;
    const scale = out / src;
    return SizedBox(
      width: out,
      height: out,
      child: ClipRect(
        child: Transform.translate(
          offset: Offset(-(col * cell + pad) * scale, -56 * scale),
          child: Transform.scale(
            alignment: Alignment.topLeft,
            scale: scale,
            child: Image.asset(
              'assets/ui/token-weapons-sheet.png',
              width: sheetW,
              height: 720,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
