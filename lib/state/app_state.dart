import 'package:flutter/foundation.dart';
import '../models/todo.dart';
import '../services/storage_service.dart';

class AppState extends ChangeNotifier {
  final StorageService _storage = StorageService();

  bool isExpanded = false;
  bool isPeeking = false;
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

  void togglePeek() {
    isPeeking = !isPeeking;
    notifyListeners();
  }

  Future<void> saveConfig(Map<String, dynamic> config) =>
      _storage.saveConfig(config);

  void addTodo(String title, {DateTime? dueDate, String? category, List<String>? tags}) {
    final todo = Todo(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim(),
      dueDate: dueDate,
      category: category,
      tags: tags,
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
