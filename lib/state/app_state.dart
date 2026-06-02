import 'package:flutter/foundation.dart';
import '../models/todo.dart';
import '../services/storage_service.dart';

class AppState extends ChangeNotifier {
  final StorageService _storage = StorageService();

  bool isExpanded = false;
  List<Todo> todos = [];
  bool _loaded = false;

  int get activeCount => todos.where((t) => !t.completed).length;

  Future<void> init() async {
    if (_loaded) return;
    todos = await _storage.loadTodos();
    _loaded = true;
    notifyListeners();
  }

  void toggleExpanded() {
    isExpanded = !isExpanded;
    notifyListeners();
  }

  void addTodo(String title, {DateTime? dueDate, String? category}) {
    final todo = Todo(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim(),
      dueDate: dueDate,
      category: category,
    );
    todos.insert(0, todo);
    _save();
    notifyListeners();
  }

  void toggleTodo(String id) {
    final idx = todos.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    todos[idx].completed = !todos[idx].completed;
    _save();
    notifyListeners();
  }

  void removeTodo(String id) {
    todos.removeWhere((t) => t.id == id);
    _save();
    notifyListeners();
  }

  void _save() => _storage.saveTodos(todos);
}
