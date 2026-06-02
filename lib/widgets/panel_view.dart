import 'dart:async';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../state/app_state.dart';
import '../models/todo.dart';
import 'todo_tile.dart';

class PanelView extends StatefulWidget {
  final AppState state;
  final VoidCallback onCollapse;
  const PanelView({super.key, required this.state, required this.onCollapse});

  @override
  State<PanelView> createState() => _PanelViewState();
}

class _PanelViewState extends State<PanelView> {
  final _inputCtrl = TextEditingController();
  final _inputFocus = FocusNode();
  DateTime? _pickedDueDate;
  bool _showDatePicker = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _addTodo() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    // Clear input first to avoid re-submit during rebuild
    _inputCtrl.clear();
    final due = _pickedDueDate;
    setState(() {
      _pickedDueDate = null;
      _showDatePicker = false;
    });
    widget.state.addTodo(text, dueDate: due);
    // Re-focus after state change settles
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inputFocus.requestFocus();
    });
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickedDueDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
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
      final time = await showTimePicker(
        context: context,
        initialTime: _pickedDueDate != null
            ? TimeOfDay.fromDateTime(_pickedDueDate!)
            : const TimeOfDay(hour: 18, minute: 0),
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
      if (time != null) {
        setState(() {
          _pickedDueDate = DateTime(
            picked.year, picked.month, picked.day, time.hour, time.minute,
          );
        });
      }
    }
  }

  String _formatDueDate(DateTime dt) {
    final now = DateTime.now();
    final diff = dt.difference(now);
    if (diff.inDays == 0) return 'Today ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff.inDays == 1) return 'Tomorrow ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xDD0f0c29), Color(0xDD302b63), Color(0xDD24243e)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366f1).withOpacity(0.15),
            blurRadius: 30,
            spreadRadius: -4,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle — only the top clock area
          GestureDetector(
            onTap: widget.onCollapse,
            onPanStart: (_) => windowManager.startDragging(),
            child: const Padding(
              padding: EdgeInsets.only(top: 14, bottom: 8),
              child: _MiniClock(),
            ),
          ),
          // Input area
          _buildInput(),
          // Todo list
          Expanded(
            child: ListenableBuilder(
              listenable: widget.state,
              builder: (context, _) {
                final activeTodos =
                    widget.state.todos.where((t) => !t.completed).toList();
                final completedTodos =
                    widget.state.todos.where((t) => t.completed).toList();

                if (activeTodos.isEmpty && completedTodos.isEmpty) {
                  return _emptyState();
                }
                return ListView(
                  padding: const EdgeInsets.only(top: 4, bottom: 12),
                  children: [
                    ...activeTodos.map((t) => TodoTile(
                          todo: t,
                          onToggle: () => widget.state.toggleTodo(t.id),
                          onRemove: () => widget.state.removeTodo(t.id),
                        )),
                    if (completedTodos.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Completed',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 11,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      ...completedTodos.map((t) => TodoTile(
                            todo: t,
                            onToggle: () => widget.state.toggleTodo(t.id),
                            onRemove: () => widget.state.removeTodo(t.id),
                          )),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 14),
              const Icon(Icons.add, size: 16, color: Color(0xFF818cf8)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  focusNode: _inputFocus,
                  onSubmitted: (_) => _addTodo(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                  ),
                  decoration: InputDecoration(
                    hintText: 'What needs doing?',
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.25),
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 0),
                  ),
                ),
              ),
              // Date picker button
              _datePickerButton(),
              // Submit button
              _submitButton(),
              const SizedBox(width: 4),
            ],
          ),
          // Show picked deadline
          if (_pickedDueDate != null)
            Padding(
              padding: const EdgeInsets.only(left: 14, bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 12,
                      color: Color(0xFFc084fc)),
                  const SizedBox(width: 6),
                  Text(
                    'Due: ${_formatDueDate(_pickedDueDate!)}',
                    style: const TextStyle(
                      color: Color(0xFFc084fc),
                      fontSize: 11,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _datePickerButton() {
    return GestureDetector(
      onTap: _pickDueDate,
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: _pickedDueDate != null
              ? const Color(0xFFc084fc).withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.calendar_today,
          size: 12,
          color: _pickedDueDate != null
              ? const Color(0xFFc084fc)
              : Colors.white.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _submitButton() {
    return GestureDetector(
      onTap: _addTodo,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFF818cf8).withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.arrow_forward_ios,
          size: 12,
          color: Color(0xFF818cf8),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 32,
                color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 8),
            Text(
              'Your mind is clear',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 13,
                fontWeight: FontWeight.w300,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniClock extends StatefulWidget {
  const _MiniClock();

  @override
  State<_MiniClock> createState() => _MiniClockState();
}

class _MiniClockState extends State<_MiniClock> {
  late final Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFF818cf8), Color(0xFFc084fc)],
      ).createShader(bounds),
      child: Text(
        '$h:$m',
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w200,
          color: Colors.white,
          letterSpacing: 3,
        ),
      ),
    );
  }
}
