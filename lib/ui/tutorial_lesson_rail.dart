import 'package:flutter/material.dart';

import '../game/faction_colors.dart';
import '../game/tutorial_controller.dart';

/// One-row Soft Lock handoff. Every lesson name stays readable.
/// Locked steps are not buttons — Pass is the only way the next one opens.
class TutorialLessonRail extends StatelessWidget {
  const TutorialLessonRail({super.key, required this.controller});

  final TutorialController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final lessons = controller.lessons;
        return IgnorePointer(
          child: Container(
            key: const Key('tutorial-lesson-rail'),
            width: double.infinity,
            color: FactionColors.lacquer,
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
            child: Row(
              children: [
                for (var i = 0; i < lessons.length; i++) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        '›',
                        style: TextStyle(color: Color(0x66D4AF37), fontSize: 14, height: 1),
                      ),
                    ),
                  Expanded(child: _LessonChip(lesson: lessons[i])),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LessonChip extends StatelessWidget {
  const _LessonChip({required this.lesson});

  final TutorialLesson lesson;

  @override
  Widget build(BuildContext context) {
    final locked = lesson.gate == TutorialLessonGate.locked;
    final current = lesson.current;
    final border = current
        ? FactionColors.gold
        : (locked ? const Color(0xFF9A9A9A) : FactionColors.gold.withValues(alpha: 0.45));
    final nameColor = locked ? const Color(0xFFE6E6E6) : FactionColors.gold;
    return Container(
      key: Key('tutorial-lesson-${lesson.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      decoration: BoxDecoration(
        color: current ? const Color(0xFF2A2208) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border, width: current ? 1.4 : 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            lesson.name,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: nameColor,
              fontSize: 12,
              fontWeight: current ? FontWeight.w800 : FontWeight.w600,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            _status(lesson.gate),
            maxLines: 1,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: locked ? const Color(0xFFBDBDBD) : nameColor.withValues(alpha: 0.9),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  String _status(TutorialLessonGate gate) {
    switch (gate) {
      case TutorialLessonGate.locked:
        return '未開';
      case TutorialLessonGate.current:
        return '進行';
      case TutorialLessonGate.done:
        return '過關';
    }
  }
}
