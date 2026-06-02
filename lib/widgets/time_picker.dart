import 'package:flutter/material.dart';

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

  DateTime get _result => DateTime(_date.year, _date.month, _date.day, _hour, _minute);

  void _apply() => widget.onPicked(_result);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF818cf8),
            onPrimary: Colors.white,
            surface: Color(0xFF1e1b4b),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  String _dateLabel() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = _date.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return '${_date.month}/${_date.day}  ${_weekday(_date.weekday)}';
  }

  String _weekday(int d) {
    const w = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return w[d - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1e1b4b).withOpacity(0.98),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quick date chips — scrollable
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _quickDateChip(0, 'Today'),
              const SizedBox(width: 5),
              _quickDateChip(1, 'Tom.'),
              const SizedBox(width: 5),
              _quickDateChip(3, '+3d'),
              const SizedBox(width: 5),
              _quickDateChip(7, '+7d'),
            ]),
          ),
          const SizedBox(height: 8),
          // Calendar picker button — full width
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.calendar_today, size: 14, color: Color(0xFF818cf8)),
                const SizedBox(width: 6),
                Text(_dateLabel(), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w400)),
                const SizedBox(width: 6),
                Icon(Icons.arrow_drop_down, size: 16, color: Colors.white.withOpacity(0.3)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          // Time row
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _timeStepper(
              value: _hour,
              onUp: () => setState(() => _hour = (_hour + 1) % 24),
              onDown: () => setState(() => _hour = (_hour - 1 + 24) % 24),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(':', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 24, fontWeight: FontWeight.w200)),
            ),
            _timeStepper(
              value: _minute,
              onUp: () => setState(() => _minute = (_minute + 5) % 60),
              onDown: () => setState(() => _minute = (_minute - 5 + 60) % 60),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: _apply,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF818cf8), Color(0xFFc084fc)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Set', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: widget.onClear,
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.close, size: 16, color: Colors.white.withOpacity(0.4)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _quickDateChip(int daysFromNow, String label) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = today.add(Duration(days: daysFromNow));
    final isSelected = _date == target;
    return GestureDetector(
      onTap: () => setState(() => _date = target),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF818cf8).withOpacity(0.25) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: const Color(0xFF818cf8).withOpacity(0.5)) : null,
        ),
        child: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.white.withOpacity(0.5), fontWeight: isSelected ? FontWeight.w500 : FontWeight.w300)),
      ),
    );
  }

  Widget _timeStepper({required int value, required VoidCallback onUp, required VoidCallback onDown}) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
        onTap: onUp,
        child: Icon(Icons.keyboard_arrow_up, size: 18, color: Colors.white.withOpacity(0.4)),
      ),
      Container(
        width: 56,
        height: 40,
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(value.toString().padLeft(2, '0'),
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w300)),
      ),
      GestureDetector(
        onTap: onDown,
        child: Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.white.withOpacity(0.4)),
      ),
    ]);
  }
}
