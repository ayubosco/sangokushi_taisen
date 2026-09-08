import 'package:flutter/material.dart';

import '../data/card_models.dart';
import '../game/faction_colors.dart';
import 'cost_stars.dart';

/// Half / bottom sheet Detail — does not full-screen block the board.
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
                child: IconButton(
                  iconSize: 28,
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close, color: FactionColors.gold),
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
                            alignment: Alignment.center,
                            child: Text(card.troopLabel,
                                style: const TextStyle(color: Colors.white70)),
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
                                const SizedBox(width: 8),
                                Text(
                                  '${card.cost} · ${card.troopLabel}',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14),
                                ),
                              ],
                            ),
                            Text(
                              '武 ${card.force}　知 ${card.intel}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14),
                            ),
                            if (card.skills.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                children: card.skills
                                    .map(
                                      (s) => Chip(
                                        label: Text(s),
                                        visualDensity: VisualDensity.compact,
                                        backgroundColor: const Color(0xFF222222),
                                        labelStyle: const TextStyle(
                                            color: FactionColors.gold,
                                            fontSize: 12),
                                      ),
                                    )
                                    .toList(),
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
                            const SizedBox(height: 8),
                            Text(
                              card.source,
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 10),
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
