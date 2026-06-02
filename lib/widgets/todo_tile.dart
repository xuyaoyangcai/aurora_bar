import 'package:flutter/material.dart';
import '../models/todo.dart';
import '../state/app_state.dart';

class TodoTile extends StatefulWidget {
  final Todo todo;
  final AppState state;
  const TodoTile({super.key, required this.todo, required this.state});

  @override
  State<TodoTile> createState() => _TodoTileState();
}

class _TodoTileState extends State<TodoTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<double> _height;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _height = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    if (widget.todo.completed) _controller.value = 1.0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onToggle() {
    widget.state.toggleTodo(widget.todo.id);
    if (widget.todo.completed) {
      _controller.forward().then((_) {
        if (widget.todo.completed) {
          Future.delayed(const Duration(milliseconds: 800), () {
            widget.state.removeTodo(widget.todo.id);
          });
        }
      });
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _height,
      axisAlignment: -1.0,
      child: FadeTransition(
        opacity: _fade,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: widget.todo.completed ? 0 : 48,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: GestureDetector(
            onTap: _onToggle,
            child: Row(
              children: [
                _checkCircle(),
                const SizedBox(width: 10),
                Expanded(child: _titleText()),
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
        color: completed ? const Color(0xFF818cf8) : Colors.transparent,
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
            : Colors.white.withOpacity(0.8),
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
}
