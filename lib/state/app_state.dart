import 'package:flutter/foundation.dart';
import '../models/todo.dart';
import '../services/storage_service.dart';

class AppState extends ChangeNotifier {
  final StorageService _storage = StorageService();

  bool isExpanded = false;
  List<Todo> todos = [];
  bool _loaded = false;

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

  void addTodo(String title, {DateTime? dueDate}) {
    final todo = Todo(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim(),
      dueDate: dueDate,
    );
    todos.insert(0, todo);
    _save();
    notifyListeners();
  }

  void toggleTodo(String id) {
    final todo = todos.firstWhere((t) => t.id == id);
    todo.completed = !todo.completed;
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
