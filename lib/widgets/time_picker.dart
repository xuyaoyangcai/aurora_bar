import 'package:flutter/material.dart';

/// Compact inline date+time picker — fits 360px
class CompactTimePicker extends StatefulWidget {
  final DateTime? initial;
  final ValueChanged<DateTime> onPicked;
  final VoidCallback onClear;

  const CompactTimePicker({
    super.key,
    this.initial,
    required this.onPicked,
    required this.onClear,
  });

  @override
  State<CompactTimePicker> createState() => _CompactTimePickerState();
}

class _CompactTimePickerState extends State<CompactTimePicker> {
  late DateTime _date;
  late int _hour;
  late int _minute;

  @override
  void initState() {
    super.initState();
    final d = widget.initial ?? DateTime.now().add(const Duration(hours: 1));
    _date = DateTime(d.year, d.month, d.day);
    _hour = d.hour;
    _minute = (d.minute ~/ 5) * 5;
  }

  DateTime get _result =>
      DateTime(_date.year, _date.month, _date.day, _hour, _minute);

  void _apply() => widget.onPicked(_result);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = List.generate(7, (i) => today.add(Duration(days: i)));

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1e1b4b).withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Date row
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: days.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              itemBuilder: (context, i) {
                final day = days[i];
                final isToday = i == 0;
                final isTomorrow = i == 1;
                final isSelected = _date == day;
                String label;
                if (isToday) {
                  label = 'Today';
                } else if (isTomorrow) {
                  label = 'Tomorrow';
                } else {
                  label =
                      '${day.month}/${day.day} ${_weekday(day.weekday)}';
                }
                return GestureDetector(
                  onTap: () => setState(() => _date = day),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF818cf8).withOpacity(0.3)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(
                              color: const Color(0xFF818cf8).withOpacity(0.5))
                          : null,
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withOpacity(0.6),
                        fontWeight:
                            isSelected ? FontWeight.w500 : FontWeight.w300,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          // Time row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _timeSpinner(
                value: _hour,
                max: 23,
                onChanged: (v) => setState(() => _hour = v),
              ),
              Text(':', style: TextStyle(
                  color: Colors.white.withOpacity(0.5), fontSize: 20)),
              _timeSpinner(
                value: _minute,
                max: 55,
                step: 5,
                onChanged: (v) => setState(() => _minute = v),
              ),
              const SizedBox(width: 12),
              // Apply
              GestureDetector(
                onTap: _apply,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF818cf8), Color(0xFFc084fc)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Set', style: TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: widget.onClear,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.close, size: 14,
                      color: Colors.white.withOpacity(0.4)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeSpinner({
    required int value,
    required int max,
    int step = 1,
    required ValueChanged<int> onChanged,
  }) {
    final items = List.generate(max ~/ step + 1, (i) => i * step);
    return Container(
      height: 36,
      width: 46,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListWheelScrollView.useDelegate(
        itemExtent: 36,
        diameterRatio: 2.0,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (i) => onChanged(items[i]),
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, i) {
            final v = items[i.clamp(0, items.length - 1)];
            return Center(
              child: Text(
                v.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                  color: v == value
                      ? Colors.white
                      : Colors.white.withOpacity(0.3),
                ),
              ),
            );
          },
          childCount: items.length,
        ),
      ),
    );
  }

  String _weekday(int d) {
    const w = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return w[d - 1];
  }
}
