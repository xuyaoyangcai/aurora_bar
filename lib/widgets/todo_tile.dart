import 'package:flutter/material.dart';
import '../models/todo.dart';

class TodoTile extends StatefulWidget {
  final Todo todo;
  final VoidCallback onToggle;
  final VoidCallback? onRemove;
  const TodoTile({super.key, required this.todo, required this.onToggle, this.onRemove});

  @override
  State<TodoTile> createState() => _TodoTileState();
}

class _TodoTileState extends State<TodoTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    if (widget.todo.completed) _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(TodoTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.todo.completed != oldWidget.todo.completed) {
      if (widget.todo.completed) {
        _controller.forward().then((_) {
          if (mounted) {
            Future.delayed(const Duration(milliseconds: 600), () {
              widget.onRemove?.call();
            });
          }
        });
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _deadlineLabel() {
    final due = widget.todo.dueDate;
    if (due == null) return null;
    final now = DateTime.now();
    final diff = due.difference(now);
    final label = diff.inDays == 0
        ? 'Today ${due.hour}:${due.minute.toString().padLeft(2, '0')}'
        : diff.inDays == 1
            ? 'Tomorrow ${due.hour}:${due.minute.toString().padLeft(2, '0')}'
            : '${due.month}/${due.day} ${due.hour}:${due.minute.toString().padLeft(2, '0')}';
    return label;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      height: widget.todo.completed ? 0 : 52,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: FadeTransition(
        opacity: _fade,
        child: GestureDetector(
          onTap: widget.onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: widget.todo.completed
                  ? Colors.white.withOpacity(0.03)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.todo.completed
                    ? Colors.white.withOpacity(0.05)
                    : Colors.white.withOpacity(0.08),
              ),
            ),
            child: Row(
              children: [
                _checkCircle(),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _titleText(),
                      if (_deadlineLabel() != null) ...[
                        const SizedBox(height: 2),
                        _deadlineChip(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _checkCircle() {
    final completed = widget.todo.completed;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: completed
              ? const Color(0xFF818cf8)
              : Colors.white.withOpacity(0.3),
          width: 1.5,
        ),
        color: completed
            ? const Color(0xFF818cf8).withOpacity(0.9)
            : Colors.transparent,
      ),
      child: completed
          ? const Icon(Icons.check, size: 12, color: Colors.white)
          : null,
    );
  }

  Widget _titleText() {
    return Text(
      widget.todo.title,
      style: TextStyle(
        color: widget.todo.completed
            ? Colors.white.withOpacity(0.3)
            : Colors.white.withOpacity(0.85),
        fontSize: 14,
        fontWeight: FontWeight.w300,
        decoration: widget.todo.completed
            ? TextDecoration.lineThrough
            : TextDecoration.none,
        decorationColor: Colors.white.withOpacity(0.2),
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _deadlineChip() {
    final due = widget.todo.dueDate!;
    final isOverdue = due.isBefore(DateTime.now()) && !widget.todo.completed;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.schedule,
          size: 10,
          color: isOverdue
              ? const Color(0xFFf87171)
              : const Color(0xFFc084fc).withOpacity(0.7),
        ),
        const SizedBox(width: 4),
        Text(
          _deadlineLabel()!,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w300,
            color: isOverdue
                ? const Color(0xFFf87171)
                : const Color(0xFFc084fc).withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}
