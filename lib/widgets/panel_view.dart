import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../state/app_state.dart';
import '../models/todo.dart';
import 'todo_tile.dart';
import 'time_picker.dart';

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
  DateTime? _dueDate;
  String? _category;
  final List<_Sparkle> _sparkles = [];
  late final Timer _sparkleTimer;

  @override
  void initState() {
    super.initState();
    _sparkleTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && _sparkles.isNotEmpty) setState(() => _sparkles.clear());
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _inputFocus.dispose();
    _sparkleTimer.cancel();
    super.dispose();
  }

  void _showTimePickerSheet() {
    showDialog(
      context: context,
      builder: (ctx) => Center(
        child: SingleChildScrollView(
          child: Container(
            width: 340,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
            child: Material(
              color: Colors.transparent,
              child: CompactTimePicker(
                initial: _dueDate,
                onPicked: (dt) {
                  setState(() => _dueDate = dt);
                  Navigator.of(ctx).pop();
                },
                onClear: () {
                  setState(() => _dueDate = null);
                  Navigator.of(ctx).pop();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
  void _addSparkle(Offset pos) {
    setState(() {
      _sparkles.add(_Sparkle(pos));
      if (_sparkles.length > 12) _sparkles.removeAt(0);
    });
  }

  void _addTodo() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    final due = _dueDate;
    final cat = _category;
    setState(() {
      _dueDate = null;
      _category = null;
    });
    widget.state.addTodo(text, dueDate: due, category: cat);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inputFocus.requestFocus();
    });
  }

  void _toggleTodo(String id) {
    widget.state.toggleTodo(id);
    // Only schedule auto-remove if becoming completed; re-check before deleting
    if (widget.state.todos.any((t) => t.id == id && t.completed)) {
      Future.delayed(const Duration(seconds: 2), () {
        if (widget.state.todos.any((t) => t.id == id && t.completed)) {
          widget.state.removeTodo(id);
        }
      });
    }
  }

  Future<void> _openClaude() async {
    try {
      await Process.start(
        'cmd', ['/c', 'start', 'claude'],
        mode: ProcessStartMode.detached,
      );
    } catch (_) {}
  }

  String _catLabel(String c) {
    switch (c) {
      case 'urgent': return 'Urgent';
      case 'work': return 'Work';
      case 'personal': return 'Personal';
      default: return c;
    }
  }

  Color _catColor(String c) {
    switch (c) {
      case 'urgent': return const Color(0xFFf87171);
      case 'work': return const Color(0xFF60a5fa);
      case 'personal': return const Color(0xFF34d399);
      default: return const Color(0xFF818cf8);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xDD0f0c29), Color(0xDD302b63), Color(0xDD24243e)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFF6366f1).withOpacity(0.15), blurRadius: 30, spreadRadius: -4),
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 16),
        ],
      ),
      child: Stack(
        children: [
          Column(children: [
            GestureDetector(
              onTap: widget.onCollapse,
              onPanStart: (_) => windowManager.startDragging(),
              child: const Padding(padding: EdgeInsets.only(top: 14, bottom: 6), child: _MiniClock()),
            ),
            _buildInput(),
            const SizedBox(height: 6),
            _buildCategories(),
            if (_dueDate != null) _dueBadge(),
            const SizedBox(height: 8),
            Expanded(child: ListenableBuilder(
              listenable: widget.state,
              builder: (context, _) {
                final active = widget.state.todos.where((t) => !t.completed).toList();
                final done = widget.state.todos.where((t) => t.completed).toList();
                if (active.isEmpty && done.isEmpty) return _emptyState();
                return ListView(
                  padding: const EdgeInsets.only(top: 2, bottom: 60),
                  children: [
                    ...active.map((t) => TodoTile(
                          todo: t, onToggle: () => _toggleTodo(t.id),
                          onDelete: () => widget.state.removeTodo(t.id),
                        )),
                    if (done.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Completed', style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 11, letterSpacing: 1)),
                      ),
                      ...done.map((t) => TodoTile(
                            todo: t, onToggle: () => _toggleTodo(t.id),
                            onDelete: () => widget.state.removeTodo(t.id),
                          )),
                    ],
                  ],
                );
              },
            )),
          ]),
          ..._sparkles.map((s) => Positioned(
                left: s.pos.dx - 6, top: s.pos.dy - 6,
                child: IgnorePointer(child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 1.0, end: 0.0),
                  duration: const Duration(milliseconds: 800),
                  builder: (c, v, _) => Opacity(
                    opacity: v,
                    child: Transform.scale(scale: 2 - v, child: const Icon(Icons.auto_awesome, size: 12, color: Color(0xFFc084fc))),
                  ),
                )),
              )),
          Positioned(
            right: 12, bottom: 12,
            child: GestureDetector(
              onTap: _openClaude,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [Color(0xFF818cf8), Color(0xFFc084fc)]),
                  boxShadow: [BoxShadow(color: const Color(0xFF818cf8).withOpacity(0.4), blurRadius: 12)],
                ),
                child: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(children: [
          const SizedBox(width: 14),
          const Icon(Icons.add, size: 16, color: Color(0xFF818cf8)),
          const SizedBox(width: 8),
          Expanded(child: TextField(
            controller: _inputCtrl, focusNode: _inputFocus,
            onSubmitted: (_) => _addTodo(),
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w300),
            decoration: InputDecoration(
              hintText: 'What needs doing?',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 14, fontWeight: FontWeight.w300),
              border: InputBorder.none, isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          )),
          GestureDetector(
            onTap: _showTimePickerSheet,
            child: Container(
              width: 32, height: 32,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: _dueDate != null ? const Color(0xFFc084fc).withOpacity(0.2) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.schedule, size: 14, color: _dueDate != null ? const Color(0xFFc084fc) : Colors.white.withOpacity(0.3)),
            ),
          ),
          GestureDetector(
            onTap: _addTodo,
            child: Container(
              width: 32, height: 32,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF818cf8).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF818cf8)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildCategories() {
    const cats = ['personal', 'work', 'urgent'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: cats.map((cat) {
        final sel = _category == cat;
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: GestureDetector(
            onTap: () => setState(() => _category = sel ? null : cat),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: sel ? _catColor(cat).withOpacity(0.2) : Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: sel ? _catColor(cat).withOpacity(0.4) : Colors.white.withOpacity(0.06)),
              ),
              child: Text(_catLabel(cat), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: sel ? _catColor(cat) : Colors.white.withOpacity(0.35))),
            ),
          ),
        );
      }).toList()),
    );
  }

  Widget _dueBadge() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(children: [
        const Icon(Icons.schedule, size: 12, color: Color(0xFFc084fc)),
        const SizedBox(width: 4),
        Text('Due: ${_dueDate!.month}/${_dueDate!.day} ${_dueDate!.hour}:${_dueDate!.minute.toString().padLeft(2, '0')}',
          style: const TextStyle(color: Color(0xFFc084fc), fontSize: 11, fontWeight: FontWeight.w300)),
      ]),
    );
  }

  Widget _emptyState() {
    final h = DateTime.now().hour;
    final g = h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
    return Center(
      child: GestureDetector(
        onTapDown: (d) => _addSparkle(d.localPosition),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.auto_awesome, size: 36, color: Color(0xFF818cf8)),
            const SizedBox(height: 10),
            Text(g, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16, fontWeight: FontWeight.w200, letterSpacing: 2)),
            const SizedBox(height: 4),
            Text('Your mind is clear', style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 12, fontWeight: FontWeight.w300, letterSpacing: 1)),
          ]),
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
  void dispose() { _timer.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFF818cf8), Color(0xFFc084fc)],
      ).createShader(bounds),
      child: Text('$h:$m', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w200, color: Colors.white, letterSpacing: 3)),
    );
  }
}

class _Sparkle { final Offset pos; const _Sparkle(this.pos); }
