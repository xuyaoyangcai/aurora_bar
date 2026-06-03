import 'package:flutter/material.dart';
import '../services/theme_engine.dart';

class MoodSelector extends StatelessWidget {
  final Mood current;
  final ValueChanged<Mood> onChanged;

  const MoodSelector({super.key, required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: Mood.values.map((mood) {
          final sel = current == mood;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onChanged(mood),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: sel
                      ? Colors.white.withOpacity(0.1)
                      : Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: sel
                        ? Colors.white.withOpacity(0.2)
                        : Colors.white.withOpacity(0.05),
                  ),
                ),
                child: Text(
                  '${_emoji(mood)}  ${_label(mood)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: sel ? Colors.white : Colors.white.withOpacity(0.35),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _emoji(Mood m) {
    switch (m) {
      case Mood.calm: return '🧘';
      case Mood.focused: return '🎯';
      case Mood.energetic: return '💪';
      case Mood.tired: return '😴';
      case Mood.creative: return '🎨';
    }
  }

  String _label(Mood m) {
    switch (m) {
      case Mood.calm: return 'Calm';
      case Mood.focused: return 'Focused';
      case Mood.energetic: return 'Energetic';
      case Mood.tired: return 'Tired';
      case Mood.creative: return 'Creative';
    }
  }
}
