import 'dart:async';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../state/app_state.dart';
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

  @override
  void dispose() {
    _inputCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _addTodo() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    widget.state.addTodo(text);
    _inputCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final activeTodos = widget.state.todos.where((t) => !t.completed).toList();
    final completedTodos = widget.state.todos.where((t) => t.completed).toList();

    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
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
            const SizedBox(height: 14),
            GestureDetector(
              onTap: widget.onCollapse,
              child: const _MiniClock(),
            ),
            _buildInput(),
            Expanded(
              child: activeTodos.isEmpty && completedTodos.isEmpty
                  ? _emptyState()
                  : ListView(
                      padding: const EdgeInsets.only(top: 4),
                      children: [
                        ...activeTodos.map((t) => TodoTile(
                              todo: t,
                              state: widget.state,
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
                                state: widget.state,
                              )),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
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
                hintText: 'Add a task...',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.25),
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
              ),
            ),
          ),
        ],
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
