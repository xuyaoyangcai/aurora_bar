import 'dart:convert';
import 'dart:io';
import '../models/todo.dart';

class StorageService {
  static const _fileName = 'aurora_todos.json';

  Future<Directory> get _dir async {
    final appData = Platform.environment['APPDATA'] ??
        Platform.environment['HOME'] ??
        '.';
    final dir = Directory('$appData/aurora_bar');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> get _file async {
    final dir = await _dir;
    return File('${dir.path}/$_fileName');
  }

  Future<List<Todo>> loadTodos() async {
    try {
      final file = await _file;
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final list = jsonDecode(content) as List<dynamic>;
      return list.map((e) => Todo.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveTodos(List<Todo> todos) async {
    final file = await _file;
    final json = jsonEncode(todos.map((t) => t.toJson()).toList());
    await file.writeAsString(json);
  }
}
