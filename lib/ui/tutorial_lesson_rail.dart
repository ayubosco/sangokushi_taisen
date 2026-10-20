import 'package:flutter/material.dart';

import '../game/faction_colors.dart';
import '../game/tutorial_controller.dart';

/// Soft Lock 4-step rail. Unlock stays on the lesson gates.
/// The hand sits on the current step. The yellow link is the 槍 drag
/// that opens 弓. It is not drawn on 回城.
class TutorialLessonRail extends StatelessWidget {
  const TutorialLessonRail({super.key, required this.controller});

  final TutorialController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final lessons = controller.lessons;
        final spearDrag = _spearDrag(lessons);
        final handoffCopy = _handoffCopy(lessons);
        return IgnorePointer(
          child: Container(
            key: const Key('tutorial-lesson-rail'),
            width: double.infinity,
            color: FactionColors.lacquer,
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (handoffCopy)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: _HandoffBubble(),
                  ),
                for (var i = 0; i < lessons.length; i++) ...[
                  if (spearDrag && lessons[i].id == 'bow') const _HandoffLink(),
                  _LessonChip(
                    index: i + 1,
                    lesson: lessons[i],
                    showHand: lessons[i].current,
                    onHandoff: spearDrag && (lessons[i].id == 'spear' || lessons[i].id == 'bow'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Yellow path while 槍迎撃 is the drag lesson. Hidden on 回城.
  bool _spearDrag(List<TutorialLesson> lessons) {
    if (lessons.length != 4) return false;
    return lessons[1].current;
  }

  /// Coach line for the 槍→弓 handoff. Backend string. Off once 回城 is current.
  bool _handoffCopy(List<TutorialLesson> lessons) {
    if (lessons.length != 4) return false;
    if (lessons[3].current) return false;
    return lessons[1].current || lessons[2].current;
  }
}

class _HandoffBubble extends StatelessWidget {
  const _HandoffBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('tutorial-handoff-cue'),
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F1E4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        '迎撃後開弓',
        style: TextStyle(
          color: Color(0xFF1A1A1A),
          fontSize: 12,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
      ),
    );
  }
}

class _HandoffLink extends StatelessWidget {
  const _HandoffLink();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: Key('tutorial-handoff-link'),
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: ColoredBox(
              color: Color(0xFFFFD54F),
              child: SizedBox(height: 2),
            ),
          ),
          SizedBox(width: 4),
          Icon(Icons.arrow_downward, color: Color(0xFFFFD54F), size: 14),
        ],
      ),
    );
  }
}

class _LessonChip extends StatelessWidget {
  const _LessonChip({
    required this.index,
    required this.lesson,
    required this.showHand,
    required this.onHandoff,
  });

  final int index;
  final TutorialLesson lesson;
  final bool showHand;
  final bool onHandoff;

  @override
  Widget build(BuildContext context) {
    final locked = lesson.gate == TutorialLessonGate.locked;
    final current = lesson.current;
    final border = onHandoff || current
        ? FactionColors.gold
        : (locked ? const Color(0xFF9A9A9A) : FactionColors.gold.withValues(alpha: 0.45));
    final nameColor = locked && !onHandoff ? const Color(0xFFE6E6E6) : FactionColors.gold;
    return Container(
      key: Key('tutorial-lesson-${lesson.id}'),
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.fromLTRB(6, 3, 4, 3),
      decoration: BoxDecoration(
        color: onHandoff || current ? const Color(0xFF2A2208) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border, width: onHandoff || current ? 1.6 : 1),
      ),
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (locked)
                    Icon(
                      Icons.lock,
                      key: Key('tutorial-lesson-lock-${lesson.id}'),
                      color: const Color(0xFFBDBDBD),
                      size: 12,
                    )
                  else if (lesson.id == 'bow')
                    const Icon(
                      Icons.lock_open,
                      key: Key('tutorial-lesson-open-bow'),
                      color: FactionColors.gold,
                      size: 12,
                    ),
                  Text(
                    '$index',
                    style: TextStyle(
                      color: nameColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      lesson.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: nameColor,
                        fontSize: 12,
                        fontWeight: current || onHandoff ? FontWeight.w800 : FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                  ),
                  if (showHand)
                    const Icon(
                      Icons.touch_app,
                      key: Key('tutorial-handoff-hand'),
                      color: Color(0xFFF7F7F7),
                      size: 16,
                    ),
                ],
              ),
              const SizedBox(height: 1),
              Text(
                _status(lesson.gate),
                maxLines: 1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: locked && !onHandoff ? const Color(0xFFBDBDBD) : nameColor.withValues(alpha: 0.9),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ],
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
