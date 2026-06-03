import 'package:flutter/foundation.dart';
import '../models/todo.dart';
import '../services/note_linker.dart';
import '../services/storage_service.dart';
import '../services/theme_engine.dart';

class AppState extends ChangeNotifier {
  final StorageService _storage = StorageService();
  final NoteLinker noteLinker = NoteLinker();
  final ThemeEngine themeEngine = ThemeEngine();

  Mood _mood = Mood.calm;
  Mood get mood => _mood;

  String _notesDir = '';
  String get notesDir => _notesDir;

  bool isExpanded = false;
  bool isPeeking = false;
  List<Todo> todos = [];
  bool _loaded = false;

  int get activeCount => todos.where((t) => !t.completed).length;

  Future<void> init() async {
    if (_loaded) return;
    todos = await _storage.loadTodos();
    final config = await _storage.loadConfig();
    _notesDir = config['notesDir'] as String? ?? '';
    if (_notesDir.isNotEmpty) noteLinker.setNotesDir(_notesDir);
    _loaded = true;
    notifyListeners();
  }

  void setNotesDir(String dir) {
    _notesDir = dir;
    noteLinker.setNotesDir(dir);
    saveConfig({'notesDir': dir});
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

  void setMood(Mood mood) {
    _mood = mood;
    themeEngine.setMood(mood);
    notifyListeners();
  }

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
