import 'dart:convert';
import 'dart:io';
import '../models/todo.dart';

class StorageService {
  static const _fileName = 'aurora_todos.json';
  static const _configName = 'aurora_config.json';

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

  Future<File> get _configFile async {
    final dir = await _dir;
    return File('${dir.path}/$_configName');
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

  Future<Map<String, dynamic>> loadConfig() async {
    try {
      final file = await _configFile;
      if (!await file.exists()) return {};
      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> saveConfig(Map<String, dynamic> config) async {
    final file = await _configFile;
    await file.writeAsString(jsonEncode(config));
  }
}
