import 'package:flutter/material.dart';

import '../game/faction_colors.dart';

/// Three-slot Cost display: full / half / empty. Min star ≥8dp (UIUX).
class CostStars extends StatelessWidget {
  const CostStars({super.key, required this.cost, this.size = 10});

  final double cost;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Map cost 1–3 onto 3 stars (each star = 1.0 cost).
    final slots = <double>[];
    var rem = cost.clamp(0, 3);
    for (var i = 0; i < 3; i++) {
      if (rem >= 1) {
        slots.add(1);
        rem -= 1;
      } else if (rem >= 0.5) {
        slots.add(0.5);
        rem = 0;
      } else {
        slots.add(0);
      }
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final f in slots)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: _Star(fill: f, size: size < 8 ? 8 : size),
          ),
      ],
    );
  }
}

class _Star extends StatelessWidget {
  const _Star({required this.fill, required this.size});
  final double fill;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (fill >= 1) {
      return Icon(Icons.star, size: size, color: FactionColors.gold);
    }
    if (fill >= 0.5) {
      return Icon(Icons.star_half, size: size, color: FactionColors.gold);
    }
    return Icon(Icons.star_border, size: size, color: Colors.white70);
  }
}
