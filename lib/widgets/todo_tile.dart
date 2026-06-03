import 'package:flutter/material.dart';
import '../models/todo.dart';

class TodoTile extends StatelessWidget {
  final Todo todo;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  const TodoTile({
    super.key,
    required this.todo,
    required this.onToggle,
    required this.onDelete,
    this.onTap,
  });

  String _deadlineLabel() {
    final due = todo.dueDate;
    if (due == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(due.year, due.month, due.day);
    final dayDiff = dueDay.difference(today).inDays;
    if (dayDiff == 0) {
      return 'Today ${due.hour}:${due.minute.toString().padLeft(2, '0')}';
    }
    if (dayDiff == 1) {
      return 'Tomorrow ${due.hour}:${due.minute.toString().padLeft(2, '0')}';
    }
    return '${due.month}/${due.day} ${due.hour}:${due.minute.toString().padLeft(2, '0')}';
  }

  Color? _categoryColor() {
    switch (todo.category) {
      case 'urgent':
        return const Color(0xFFf87171);
      case 'work':
        return const Color(0xFF60a5fa);
      case 'personal':
        return const Color(0xFF34d399);
      default:
        return null;
    }
  }

  String _categoryLabel() {
    switch (todo.category) {
      case 'urgent':
        return 'Urgent';
      case 'work':
        return 'Work';
      case 'personal':
        return 'Personal';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final deadline = _deadlineLabel();
    final catColor = _categoryColor();
    final catLabel = _categoryLabel();

    final child = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          // Check circle — explicit tap target
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: todo.completed
                      ? const Color(0xFF818cf8)
                      : Colors.white.withOpacity(0.25),
                  width: 1.5,
                ),
                color: todo.completed
                    ? const Color(0xFF818cf8)
                    : Colors.transparent,
              ),
              child: todo.completed
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  todo.title,
                  style: TextStyle(
                    color: todo.completed
                        ? Colors.white.withOpacity(0.3)
                        : Colors.white.withOpacity(0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                    decoration: todo.completed
                        ? TextDecoration.lineThrough
                        : null,
                    decorationColor: Colors.white.withOpacity(0.2),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (deadline.isNotEmpty || catLabel.isNotEmpty || todo.tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(
                      children: [
                        if (deadline.isNotEmpty) ...[
                          Icon(
                            Icons.schedule,
                            size: 10,
                            color: todo.dueDate!.isBefore(DateTime.now()) &&
                                    !todo.completed
                                ? const Color(0xFFf87171)
                                : const Color(0xFFc084fc).withOpacity(0.6),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            deadline,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w300,
                              color: todo.dueDate!.isBefore(DateTime.now()) &&
                                      !todo.completed
                                  ? const Color(0xFFf87171)
                                  : const Color(0xFFc084fc).withOpacity(0.6),
                            ),
                          ),
                        ],
                        if (deadline.isNotEmpty && catLabel.isNotEmpty)
                          const SizedBox(width: 8),
                        if (catLabel.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: catColor!.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              catLabel,
                              style: TextStyle(
                                fontSize: 9,
                                color: catColor.withOpacity(0.8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        if (todo.tags.isNotEmpty)
                          ...todo.tags.map((tag) => Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '#$tag',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.white.withOpacity(0.35),
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                ),
                              )),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Delete button
          GestureDetector(
            onTap: onDelete,
            child: Icon(
              Icons.close,
              size: 14,
              color: Colors.white.withOpacity(0.15),
            ),
          ),
        ],
      ),
      ),
    );

    // Wrap in Dismissible for swipe-to-complete
    return Dismissible(
      key: Key(todo.id),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe right → complete
          onToggle();
        } else {
          // Swipe left → delete
          onDelete();
        }
        return false; // We handle state ourselves
      },
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF818cf8).withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.check, color: Color(0xFF818cf8), size: 18),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFf87171).withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline,
            color: Color(0xFFf87171), size: 18),
      ),
      child: child,
    );
  }
}
