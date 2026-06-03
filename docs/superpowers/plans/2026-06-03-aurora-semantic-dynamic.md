# Aurora Bar — 语义化任务管理 + 生成式动态环境 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 aurora_bar 加入两大能力：(1) 自然语言输入自动提取时间/标签/关联笔记；(2) 时间/天气/心情驱动的动态渐变背景、FragmentShader 极光效果和增强粒子系统。

**Architecture:** 新增 6 个模块文件（NLP 解析、笔记关联、天气服务、主题引擎、动态背景、心情选择器）+ 1 个 shader 文件 + 2 个粒子文件。修改现有 Todo 模型、AppState、BarView、PanelView 以接入新能力。整体遵循项目现有的 `models/` `services/` `state/` `widgets/` 分层结构，AppState 继续作为唯一的状态中枢。

**Tech Stack:** Flutter 3.x + Dart >=3.3.0, window_manager, screen_retriever, http (新增), flutter_shaders (新增 FragmentShader 支持)

---

## 文件结构

```
lib/
├── models/
│   └── todo.dart              # [修改] 新增 tags 字段
├── services/
│   ├── storage_service.dart   # [修改] 新增笔记目录配置存取
│   ├── nlp_parser.dart        # [新建] 自然语言时间/标签提取
│   ├── note_linker.dart       # [新建] 本地笔记关联
│   ├── weather_service.dart   # [新建] 天气数据获取
│   └── theme_engine.dart      # [新建] 动态调色板计算
├── state/
│   └── app_state.dart         # [修改] 新增 mood/theme/笔记目录状态
├── widgets/
│   ├── bar_view.dart          # [修改] 接入动态背景
│   ├── panel_view.dart        # [修改] 接入动态背景、显示标签/笔记建议
│   ├── todo_tile.dart         # [修改] 渲染 tags 标签
│   ├── time_picker.dart       # 不变
│   ├── dynamic_background.dart # [新建] 动态渐变 + shader 背景组件
│   ├── mood_selector.dart     # [新建] 心情选择器
│   └── weather_particle.dart  # [新建] 天气粒子系统
├── shaders/
│   └── aurora.frag            # [新建] GPU 极光波动着色器
└── main.dart                  # [修改] 注册 shader、初始化天气/主题
pubspec.yaml                   # [修改] 新增 http 依赖、flutter_shaders 配置
```

---

### Task 1: Todo 模型扩展 — 新增 tags 字段

**Files:**
- Modify: `lib/models/todo.dart`
- Modify: `lib/services/storage_service.dart`
- Modify: `lib/widgets/todo_tile.dart`

- [ ] **Step 1: 给 Todo 模型加 tags 字段**

修改 `lib/models/todo.dart`，在 `category` 下方添加 `List<String> tags`，更新 `toJson`/`fromJson`/构造函数：

```dart
class Todo {
  final String id;
  final String title;
  bool completed;
  final DateTime createdAt;
  DateTime? dueDate;
  String? category;
  List<String> tags;                          // 新增

  Todo({
    required this.id,
    required this.title,
    this.completed = false,
    DateTime? createdAt,
    this.dueDate,
    this.category,
    List<String>? tags,                       // 新增
  }) : tags = tags ?? [],                     // 新增
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'completed': completed,
        'createdAt': createdAt.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'category': category,
        'tags': tags,                          // 新增
      };

  factory Todo.fromJson(Map<String, dynamic> json) => Todo(
        id: json['id'] as String,
        title: json['title'] as String,
        completed: json['completed'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
        dueDate: json['dueDate'] != null
            ? DateTime.parse(json['dueDate'] as String)
            : null,
        category: json['category'] as String?,
        tags: json['tags'] != null                // 新增
            ? List<String>.from(json['tags'] as List)
            : null,
      );
}
```

- [ ] **Step 2: 在 TodoTile 中渲染 tags**

修改 `lib/widgets/todo_tile.dart`，在 deadline 和 category 的 Row 后面追加 tags 渲染。在 `build` 方法的 `if (deadline.isNotEmpty || catLabel.isNotEmpty)` Padding 内的 Row children 末尾追加：

```dart
// 在 catLabel 的 Container 后面追加（Row children 末尾）
if (todo.tags.isNotEmpty)
  ...todo.tags.map((tag) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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
```

- [ ] **Step 3: 验证编译通过**

```bash
cd /d/zhang/aurora_bar && flutter analyze lib/models/todo.dart lib/widgets/todo_tile.dart
```

- [ ] **Step 4: 提交**

```bash
cd /d/zhang/aurora_bar
git add lib/models/todo.dart lib/widgets/todo_tile.dart
git commit -m "feat: add tags field to Todo model and render in TodoTile"
```

---

### Task 2: NLP 解析器 — 时间提取 + 自动标签

**Files:**
- Create: `lib/services/nlp_parser.dart`

- [ ] **Step 1: 创建 NLP 解析器**

创建 `lib/services/nlp_parser.dart`：

```dart
/// Lightweight NLP parser for Chinese natural language task input.
/// Extracts due dates, times, and auto-tags from free-text input.
class NlpParser {
  /// Result of parsing a task string.
  final ParsedTask result;

  NlpParser._(this.result);

  /// Parse [input] and return structured task data.
  /// Original text is preserved as title; extracted date/time/tags are returned separately.
  factory NlpParser.parse(String input) {
    final trimmed = input.trim();
    DateTime? dueDate;
    final tags = <String>[];

    dueDate = _extractDateTime(trimmed);
    tags.addAll(_extractTags(trimmed));

    return NlpParser._(ParsedTask(
      title: trimmed,
      dueDate: dueDate,
      tags: tags,
    ));
  }

  // ── Time extraction ──

  static DateTime? _extractDateTime(String text) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // "明天下午3点" / "明天下午3点半" / "明天下午3:30"
    final tomorrowHour = RegExp(r'明天[上下]午?(\d{1,2})[点:：](\d{0,2})?');
    final matchTH = tomorrowHour.firstMatch(text);
    if (matchTH != null) {
      int h = int.parse(matchTH.group(1)!);
      final m = matchTH.group(2)?.isNotEmpty == true
          ? int.parse(matchTH.group(2)!)
          : 0;
      if (text.contains('下') && h < 12) h += 12;
      if (text.contains('上') && h == 12) h = 0;
      return today.add(Duration(days: 1)).add(Duration(hours: h, minutes: m));
    }

    // "明天" without specific time → 9:00
    if (RegExp(r'明天').hasMatch(text)) {
      return today.add(const Duration(days: 1, hours: 9));
    }

    // "后天" → 9:00
    if (RegExp(r'后天').hasMatch(text)) {
      return today.add(const Duration(days: 2, hours: 9));
    }

    // "今天下午3点" / "今晚8点" / "今天3点半"
    final todayHour = RegExp(r'今天[上下晚]?午?(\d{1,2})[点:：](\d{0,2})?');
    final matchToday = todayHour.firstMatch(text);
    if (matchToday != null) {
      int h = int.parse(matchToday.group(1)!);
      final m = matchToday.group(2)?.isNotEmpty == true
          ? int.parse(matchToday.group(2)!)
          : 0;
      if ((text.contains('下') || text.contains('晚')) && h < 12) h += 12;
      if (text.contains('上') && h == 12) h = 0;
      return today.add(Duration(hours: h, minutes: m));
    }

    // "下周X" → next week that day
    final nextWeek = RegExp(r'下周([一二三四五六七日天])');
    final matchNW = nextWeek.firstMatch(text);
    if (matchNW != null) {
      final dayChar = matchNW.group(1)!;
      final targetWday = _weekdayFromChinese(dayChar);
      final daysUntil = (targetWday - now.weekday + 7) % 7 + 7;
      return today.add(Duration(days: daysUntil, hours: 9));
    }

    // "周X" / "星期X" → this week (or next if passed)
    final thisWeek = RegExp(r'(?:周|星期)([一二三四五六七日天])');
    final matchTW = thisWeek.firstMatch(text);
    if (matchTW != null) {
      final dayChar = matchTW.group(1)!;
      final targetWday = _weekdayFromChinese(dayChar);
      var daysUntil = (targetWday - now.weekday + 7) % 7;
      if (daysUntil == 0 && now.hour >= 18) daysUntil = 7;
      return today.add(Duration(days: daysUntil, hours: 9));
    }

    // "X月Y日" / "X月Y号"
    final monthDay = RegExp(r'(\d{1,2})月(\d{1,2})[日号]');
    final matchMD = monthDay.firstMatch(text);
    if (matchMD != null) {
      final m = int.parse(matchMD.group(1)!);
      final d = int.parse(matchMD.group(2)!);
      return DateTime(now.year, m, d, 9);
    }

    // "晚上8点" / "下午3点" / "早上9点" (no date prefix)
    final bareHour = RegExp(r'([上中下晚早]午?|晚上|早上|中午)(\d{1,2})[点:：](\d{0,2})?');
    final matchBH = bareHour.firstMatch(text);
    if (matchBH != null) {
      int h = int.parse(matchBH.group(2)!);
      final m = matchBH.group(3)?.isNotEmpty == true
          ? int.parse(matchBH.group(3)!)
          : 0;
      final period = matchBH.group(1)!;
      if ((period == '下' || period == '下午' || period == '晚' || period == '晚上') && h < 12) h += 12;
      if ((period == '上' || period == '上午' || period == '早' || period == '早上') && h == 12) h = 0;
      if (period == '中' || period == '中午') h = 12;
      return today.add(Duration(hours: h, minutes: m));
    }

    return null;
  }

  static int _weekdayFromChinese(String s) {
    const map = {'一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6, '日': 7, '天': 7};
    return map[s] ?? 1;
  }

  // ── Tag extraction ──

  static final _tagDict = {
    '复习': ['学习'],
    '考试': ['学习'],
    '作业': ['学习'],
    '论文': ['学习'],
    '阅读': ['阅读'],
    '读书': ['阅读'],
    '看.*书': ['阅读'],
    '会议': ['工作'],
    '开会': ['工作'],
    '报告': ['工作'],
    '项目': ['工作'],
    '运动': ['运动'],
    '跑步': ['运动'],
    '健身': ['运动'],
    '游泳': ['运动'],
    '买菜': ['生活'],
    '做饭': ['生活'],
    '快递': ['生活'],
    '打扫': ['生活'],
    '整理': ['生活'],
  };

  static List<String> _extractTags(String text) {
    final tags = <String>[];
    for (final entry in _tagDict.entries) {
      if (RegExp(entry.key).hasMatch(text)) {
        for (final tag in entry.value) {
          if (!tags.contains(tag)) tags.add(tag);
        }
      }
    }
    return tags;
  }
}

class ParsedTask {
  final String title;
  final DateTime? dueDate;
  final List<String> tags;

  const ParsedTask({
    required this.title,
    this.dueDate,
    this.tags = const [],
  });
}
```

- [ ] **Step 2: 添加单元测试**

创建 `test/nlp_parser_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:aurora_bar/services/nlp_parser.dart';

void main() {
  group('NlpParser time extraction', () {
    test('明天下午3点', () {
      final r = NlpParser.parse('明天下午记得复习 Hofstede 的文化维度理论');
      expect(r.dueDate, isNotNull);
      expect(r.dueDate!.hour, 15);
    });

    test('后天', () {
      final r = NlpParser.parse('后天交报告');
      expect(r.dueDate, isNotNull);
      final diff = r.dueDate!.difference(DateTime.now()).inDays;
      expect(diff, 2);
    });

    test('今天晚上8点', () {
      final r = NlpParser.parse('今天晚上8点开会');
      expect(r.dueDate, isNotNull);
      expect(r.dueDate!.hour, 20);
    });

    test('下周X', () {
      final r = NlpParser.parse('下周三汇报');
      expect(r.dueDate, isNotNull);
      expect(r.dueDate!.weekday, 3);
    });

    test('no time mention', () {
      final r = NlpParser.parse('随便写点什么');
      expect(r.dueDate, isNull);
    });
  });

  group('NlpParser tag extraction', () {
    test('复习 → 学习', () {
      final r = NlpParser.parse('复习高等数学');
      expect(r.tags, contains('学习'));
    });

    test('运动 → 运动', () {
      final r = NlpParser.parse('下午去跑步');
      expect(r.tags, contains('运动'));
    });

    test('multiple tags', () {
      final r = NlpParser.parse('复习完去跑步买菜');
      expect(r.tags, contains('学习'));
      expect(r.tags, contains('运动'));
      expect(r.tags, contains('生活'));
    });
  });
}
```

- [ ] **Step 3: 运行测试验证通过**

```bash
cd /d/zhang/aurora_bar && flutter test test/nlp_parser_test.dart
```

预期：所有测试 PASS。

- [ ] **Step 4: 提交**

```bash
cd /d/zhang/aurora_bar
git add lib/services/nlp_parser.dart test/nlp_parser_test.dart
git commit -m "feat: add NLP parser for Chinese time extraction and auto-tagging"
```

---

### Task 3: NLP 接入 PanelView — 输入时实时解析

**Files:**
- Modify: `lib/state/app_state.dart`
- Modify: `lib/widgets/panel_view.dart`

- [ ] **Step 1: 修改 AppState.addTodo 签名**

修改 `lib/state/app_state.dart`，让 `addTodo` 接受可选的 `tags` 参数：

```dart
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
```

- [ ] **Step 2: 修改 PanelView._addTodo 调用 NlpParser**

修改 `lib/widgets/panel_view.dart`，在文件顶部添加导入：

```dart
import '../services/nlp_parser.dart';
```

修改 `_addTodo` 方法：

```dart
void _addTodo() {
  final text = _inputCtrl.text.trim();
  if (text.isEmpty) return;
  _inputCtrl.clear();

  final parsed = NlpParser.parse(text);
  final due = _dueDate ?? parsed.dueDate;
  final cat = _category;
  final tags = parsed.tags;

  setState(() {
    _dueDate = null;
    _category = null;
  });
  widget.state.addTodo(parsed.title, dueDate: due, category: cat, tags: tags);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) _inputFocus.requestFocus();
  });
}
```

- [ ] **Step 3: 验证编译通过**

```bash
cd /d/zhang/aurora_bar && flutter analyze lib/state/app_state.dart lib/widgets/panel_view.dart
```

- [ ] **Step 4: 提交**

```bash
cd /d/zhang/aurora_bar
git add lib/state/app_state.dart lib/widgets/panel_view.dart
git commit -m "feat: integrate NLP parser into PanelView input flow"
```

---

### Task 4: 笔记关联服务

**Files:**
- Create: `lib/services/note_linker.dart`

- [ ] **Step 1: 创建笔记关联服务**

创建 `lib/services/note_linker.dart`：

```dart
import 'dart:io';

/// Scans a configured notes directory and returns file paths
/// whose content matches keywords from a task title.
class NoteLinker {
  String? _notesDir;

  /// Configure the notes directory to scan.
  void setNotesDir(String dir) => _notesDir = dir;

  /// Return up to [maxResults] note file paths relevant to [taskTitle].
  /// Matching is naive full-text substring search — good enough for
  /// personal markdown/text note collections.
  Future<List<String>> findRelated(String taskTitle, {int maxResults = 3}) async {
    final dir = _notesDir;
    if (dir == null || dir.isEmpty) return [];
    final directory = Directory(dir);
    if (!await directory.exists()) return [];

    // Extract potential keywords: split on common separators + Chinese word boundaries
    final keywords = taskTitle
        .split(RegExp(r'[\s，。！？,.!?、：:（）()【】\[\]{}]+'))
        .where((s) => s.length >= 2)
        .toList();

    final results = <_Match>[];
    await for (final entity in directory.list(recursive: true)) {
      if (entity is! File) continue;
      final ext = entity.path.split('.').last.toLowerCase();
      if (!['txt', 'md', 'markdown', 'log', 'rst', 'org'].contains(ext)) continue;

      try {
        final content = await entity.readAsString();
        final lowerContent = content.toLowerCase();
        final lowerTitle = taskTitle.toLowerCase();
        var score = 0;

        // Full title match
        if (lowerContent.contains(lowerTitle)) score += 10;
        // Keyword matches
        for (final kw in keywords) {
          if (kw.length >= 2 && lowerContent.contains(kw.toLowerCase())) score += 3;
        }
        // Filename match
        final fname = entity.uri.pathSegments.last.toLowerCase();
        for (final kw in keywords) {
          if (kw.length >= 2 && fname.contains(kw.toLowerCase())) score += 5;
        }

        if (score > 0) {
          results.add(_Match(entity.path, score));
        }
      } catch (_) {}
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(maxResults).map((m) => m.path).toList();
  }
}

class _Match {
  final String path;
  final int score;
  const _Match(this.path, this.score);
}
```

- [ ] **Step 2: 在 AppState 中集成 NoteLinker，添加笔记目录配置**

修改 `lib/state/app_state.dart`：

```dart
import '../services/note_linker.dart';

class AppState extends ChangeNotifier {
  final StorageService _storage = StorageService();
  final NoteLinker noteLinker = NoteLinker();  // 新增

  // ... existing fields ...
  String _notesDir = '';
  String get notesDir => _notesDir;

  @override
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
    saveConfig({'notesDir': dir});  // persist via existing saveConfig
    notifyListeners();
  }

  // ... rest unchanged ...
}
```

- [ ] **Step 3: 验证编译通过**

```bash
cd /d/zhang/aurora_bar && flutter analyze lib/services/note_linker.dart lib/state/app_state.dart
```

- [ ] **Step 4: 提交**

```bash
cd /d/zhang/aurora_bar
git add lib/services/note_linker.dart lib/state/app_state.dart
git commit -m "feat: add note linker service for local note association"
```

---

### Task 5: PanelView 中输入时显示解析预览 + 笔记链接

**Files:**
- Modify: `lib/widgets/panel_view.dart`

- [ ] **Step 1: 添加实时解析预览**

修改 `lib/widgets/panel_view.dart`。在 `_PanelViewState` 中添加监听输入变化的逻辑，在输入框下方显示解析出来的时间和标签预览。

添加字段：

```dart
ParsedTask? _parsedPreview;
```

修改 `initState`，在 `_inputCtrl` 初始化后添加 listener：

```dart
@override
void initState() {
  super.initState();
  _inputCtrl.addListener(_onInputChanged);
  _sparkleTimer = Timer.periodic(const Duration(seconds: 3), (_) {
    if (mounted && _sparkles.isNotEmpty) setState(() => _sparkles.clear());
  });
}

void _onInputChanged() {
  final text = _inputCtrl.text.trim();
  if (text.isEmpty) {
    if (_parsedPreview != null) setState(() => _parsedPreview = null);
    return;
  }
  final parsed = NlpParser.parse(text);
  if (_parsedPreview?.dueDate != parsed.dueDate ||
      !_listsEqual(_parsedPreview?.tags ?? [], parsed.tags)) {
    setState(() => _parsedPreview = parsed);
  }
}

bool _listsEqual(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
```

- [ ] **Step 2: 在输入框和分类行之间插入预览 strip**

在 `_buildInput()` 后面、`_buildCategories()` 前面，插入预览组件。修改 `build` 方法中 Column children 的对应位置：

```dart
// 在 _buildInput() 和 _buildCategories() 之间插入：
if (_parsedPreview != null &&
    (_parsedPreview!.dueDate != null || _parsedPreview!.tags.isNotEmpty))
  _buildParsePreview(),
```

添加 `_buildParsePreview` 方法：

```dart
Widget _buildParsePreview() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    child: Row(
      children: [
        Icon(Icons.auto_awesome, size: 10, color: Colors.white.withOpacity(0.25)),
        const SizedBox(width: 6),
        if (_parsedPreview!.dueDate != null) ...[
          Icon(Icons.schedule, size: 10, color: const Color(0xFFc084fc).withOpacity(0.6)),
          const SizedBox(width: 3),
          Text(
            '${_parsedPreview!.dueDate!.month}/${_parsedPreview!.dueDate!.day} '
            '${_parsedPreview!.dueDate!.hour}:${_parsedPreview!.dueDate!.minute.toString().padLeft(2, '0')}',
            style: TextStyle(fontSize: 10, color: const Color(0xFFc084fc).withOpacity(0.6)),
          ),
          const SizedBox(width: 8),
        ],
        ..._parsedPreview!.tags.map((t) => Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('#$t', style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.3))),
          ),
        )),
      ],
    ),
  );
}
```

- [ ] **Step 3: 验证编译**

```bash
cd /d/zhang/aurora_bar && flutter analyze lib/widgets/panel_view.dart
```

- [ ] **Step 4: 提交**

```bash
cd /d/zhang/aurora_bar
git add lib/widgets/panel_view.dart
git commit -m "feat: show NLP parse preview below input field"
```

---

### Task 6: 主题引擎 — 时间/天气/心情驱动的调色板

**Files:**
- Create: `lib/services/theme_engine.dart`

- [ ] **Step 1: 创建主题引擎**

创建 `lib/services/theme_engine.dart`：

```dart
import 'dart:math';
import 'package:flutter/material.dart';

enum Mood { calm, focused, energetic, tired, creative }

/// Produces a dynamic color palette based on time of day, weather, and mood.
class AuroraPalette {
  final Color primary;
  final Color secondary;
  final Color backgroundStart;
  final Color backgroundMid;
  final Color backgroundEnd;
  final Color accent1;
  final Color accent2;

  const AuroraPalette({
    required this.primary,
    required this.secondary,
    required this.backgroundStart,
    required this.backgroundMid,
    required this.backgroundEnd,
    required this.accent1,
    required this.accent2,
  });
}

class ThemeEngine {
  Mood _mood = Mood.calm;
  String? _weatherCode; // 'clear', 'cloudy', 'rain', 'snow', 'fog'

  void setMood(Mood mood) => _mood = mood;
  void setWeather(String? code) => _weatherCode = code;

  AuroraPalette compute(DateTime now) {
    final hour = now.hour + now.minute / 60.0;
    final t = _timeFactor(hour);

    // Base palettes for key times (dusk, midnight, dawn, noon)
    final morning = _blendPalettes(_dawnPalette(), _noonPalette(), t);
    final evening = _blendPalettes(_noonPalette(), _duskPalette(), t);
    final night = _blendPalettes(_duskPalette(), _midnightPalette(), t);

    AuroraPalette base;
    if (hour < 6) {
      base = night;
    } else if (hour < 8) {
      base = _blendPalettes(night, morning, (hour - 6) / 2);
    } else if (hour < 12) {
      base = morning;
    } else if (hour < 17) {
      base = _blendPalettes(morning, evening, (hour - 12) / 5);
    } else if (hour < 19) {
      base = evening;
    } else {
      base = _blendPalettes(evening, night, (hour - 19) / 5);
    }

    base = _applyWeather(base);
    base = _applyMood(base);
    return base;
  }

  double _timeFactor(double hour) {
    // Sinusoidal: peaks at noon (0.5), trough at midnight (-0.5)
    return sin((hour - 6) / 24 * 2 * pi) * 0.5 + 0.5;
  }

  AuroraPalette _dawnPalette() => const AuroraPalette(
    primary: Color(0xFF818cf8), secondary: Color(0xFFc084fc),
    backgroundStart: Color(0xFF1a1a3e), backgroundMid: Color(0xFF2d2b55),
    backgroundEnd: Color(0xFF3b2a4a),
    accent1: Color(0xFFa78bfa), accent2: Color(0xFFf9a8d4),
  );

  AuroraPalette _noonPalette() => const AuroraPalette(
    primary: Color(0xFF60a5fa), secondary: Color(0xFF34d399),
    backgroundStart: Color(0xFF1e3a5f), backgroundMid: Color(0xFF2563a0),
    backgroundEnd: Color(0xFF1e4d6b),
    accent1: Color(0xFF38bdf8), accent2: Color(0xFF4ade80),
  );

  AuroraPalette _duskPalette() => const AuroraPalette(
    primary: Color(0xFFf59e0b), secondary: Color(0xFFef4444),
    backgroundStart: Color(0xFF3d1e1e), backgroundMid: Color(0xFF5c2a2a),
    backgroundEnd: Color(0xFF3d1020),
    accent1: Color(0xFFfb923c), accent2: Color(0xFFf87171),
  );

  AuroraPalette _midnightPalette() => const AuroraPalette(
    primary: Color(0xFF6366f1), secondary: Color(0xFF8b5cf6),
    backgroundStart: Color(0xFF0f0c29), backgroundMid: Color(0xFF1a1040),
    backgroundEnd: Color(0xFF0d0a1a),
    accent1: Color(0xFF818cf8), accent2: Color(0xFFa78bfa),
  );

  AuroraPalette _blendPalettes(AuroraPalette a, AuroraPalette b, double t) {
    final tt = t.clamp(0.0, 1.0);
    return AuroraPalette(
      primary: Color.lerp(a.primary, b.primary, tt)!,
      secondary: Color.lerp(a.secondary, b.secondary, tt)!,
      backgroundStart: Color.lerp(a.backgroundStart, b.backgroundStart, tt)!,
      backgroundMid: Color.lerp(a.backgroundMid, b.backgroundMid, tt)!,
      backgroundEnd: Color.lerp(a.backgroundEnd, b.backgroundEnd, tt)!,
      accent1: Color.lerp(a.accent1, b.accent1, tt)!,
      accent2: Color.lerp(a.accent2, b.accent2, tt)!,
    );
  }

  AuroraPalette _applyWeather(AuroraPalette p) {
    switch (_weatherCode) {
      case 'rain':
        return AuroraPalette(
          primary: p.primary, secondary: p.secondary,
          backgroundStart: Color.lerp(p.backgroundStart, const Color(0xFF1a2332), 0.3)!,
          backgroundMid: Color.lerp(p.backgroundMid, const Color(0xFF2a3348), 0.3)!,
          backgroundEnd: Color.lerp(p.backgroundEnd, const Color(0xFF1a1e2e), 0.3)!,
          accent1: Color.lerp(p.accent1, const Color(0xFF6b7fa8), 0.4)!,
          accent2: Color.lerp(p.accent2, const Color(0xFF5b6e8e), 0.4)!,
        );
      case 'snow':
        return AuroraPalette(
          primary: p.primary, secondary: p.secondary,
          backgroundStart: Color.lerp(p.backgroundStart, const Color(0xFFe8eef5), 0.4)!,
          backgroundMid: Color.lerp(p.backgroundMid, const Color(0xFFdce4f0), 0.4)!,
          backgroundEnd: Color.lerp(p.backgroundEnd, const Color(0xFFcfd8e8), 0.4)!,
          accent1: Color.lerp(p.accent1, const Color(0xFFb0c4de), 0.5)!,
          accent2: Color.lerp(p.accent2, const Color(0xFFc8d8e8), 0.5)!,
        );
      case 'cloudy':
        return AuroraPalette(
          primary: p.primary, secondary: p.secondary,
          backgroundStart: Color.lerp(p.backgroundStart, const Color(0xFF252536), 0.2)!,
          backgroundMid: Color.lerp(p.backgroundMid, const Color(0xFF35354a), 0.2)!,
          backgroundEnd: Color.lerp(p.backgroundEnd, const Color(0xFF2a2a3c), 0.2)!,
          accent1: p.accent1, accent2: p.accent2,
        );
      default: return p;
    }
  }

  AuroraPalette _applyMood(AuroraPalette p) {
    switch (_mood) {
      case Mood.focused:
        return AuroraPalette(
          primary: const Color(0xFF60a5fa), secondary: const Color(0xFF3b82f6),
          backgroundStart: Color.lerp(p.backgroundStart, const Color(0xFF0f2027), 0.25)!,
          backgroundMid: Color.lerp(p.backgroundMid, const Color(0xFF1a3545), 0.25)!,
          backgroundEnd: Color.lerp(p.backgroundEnd, const Color(0xFF0f2535), 0.25)!,
          accent1: const Color(0xFF38bdf8), accent2: const Color(0xFF818cf8),
        );
      case Mood.energetic:
        return AuroraPalette(
          primary: const Color(0xFFf59e0b), secondary: const Color(0xFFef4444),
          backgroundStart: Color.lerp(p.backgroundStart, const Color(0xFF3d1e10), 0.2)!,
          backgroundMid: Color.lerp(p.backgroundMid, const Color(0xFF553010), 0.2)!,
          backgroundEnd: Color.lerp(p.backgroundEnd, const Color(0xFF3d1510), 0.2)!,
          accent1: const Color(0xFFfb923c), accent2: const Color(0xFFf87171),
        );
      case Mood.tired:
        return AuroraPalette(
          primary: Color.lerp(p.primary, const Color(0xFF6b7280), 0.35)!,
          secondary: Color.lerp(p.secondary, const Color(0xFF4b5563), 0.35)!,
          backgroundStart: Color.lerp(p.backgroundStart, const Color(0xFF1a1a1a), 0.3)!,
          backgroundMid: Color.lerp(p.backgroundMid, const Color(0xFF2a2a2a), 0.3)!,
          backgroundEnd: Color.lerp(p.backgroundEnd, const Color(0xFF1a1a1a), 0.3)!,
          accent1: const Color(0xFF9ca3af), accent2: const Color(0xFF6b7280),
        );
      case Mood.creative:
        return AuroraPalette(
          primary: const Color(0xFFc084fc), secondary: const Color(0xFFf472b6),
          backgroundStart: Color.lerp(p.backgroundStart, const Color(0xFF2d1040), 0.2)!,
          backgroundMid: Color.lerp(p.backgroundMid, const Color(0xFF3d1855), 0.2)!,
          backgroundEnd: Color.lerp(p.backgroundEnd, const Color(0xFF301040), 0.2)!,
          accent1: const Color(0xFFe879f9), accent2: const Color(0xFFf9a8d4),
        );
      default: return p;
    }
  }
}
```

- [ ] **Step 2: 在 AppState 中集成 ThemeEngine**

修改 `lib/state/app_state.dart`：

```dart
import '../services/theme_engine.dart';

class AppState extends ChangeNotifier {
  // ... existing ...
  final ThemeEngine themeEngine = ThemeEngine();  // 新增
  Mood _mood = Mood.calm;                          // 新增
  Mood get mood => _mood;

  void setMood(Mood mood) {
    _mood = mood;
    themeEngine.setMood(mood);
    notifyListeners();
  }
  // ...
}
```

- [ ] **Step 3: 验证编译**

```bash
cd /d/zhang/aurora_bar && flutter analyze lib/services/theme_engine.dart lib/state/app_state.dart
```

- [ ] **Step 4: 提交**

```bash
cd /d/zhang/aurora_bar
git add lib/services/theme_engine.dart lib/state/app_state.dart
git commit -m "feat: add theme engine with time/weather/mood-driven palettes"
```

---

### Task 7: 天气服务

**Files:**
- Create: `lib/services/weather_service.dart`
- Modify: `pubspec.yaml`

- [ ] **Step 1: 添加 http 依赖**

修改 `pubspec.yaml`，在 dependencies 中添加：

```yaml
  http: ^1.2.0
```

运行：

```bash
cd /d/zhang/aurora_bar && flutter pub get
```

- [ ] **Step 2: 创建天气服务**

创建 `lib/services/weather_service.dart`：

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Fetches current weather from wttr.in (free, no API key).
/// Returns a simple weather code: clear, cloudy, rain, snow, fog.
class WeatherService {
  String? _lastCode;
  DateTime? _lastFetch;

  /// Returns a weather code, cached for 30 minutes.
  Future<String?> fetch() async {
    if (_lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < const Duration(minutes: 30)) {
      return _lastCode;
    }
    try {
      final uri = Uri.parse('https://wttr.in?format=%C');
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) return null;
      final raw = resp.body.trim().toLowerCase();
      _lastCode = _classify(raw);
      _lastFetch = DateTime.now();
      return _lastCode;
    } catch (_) {
      return _lastCode; // Return stale on failure
    }
  }

  String _classify(String condition) {
    if (condition.contains('rain') || condition.contains('drizzle') || condition.contains('shower')) return 'rain';
    if (condition.contains('snow') || condition.contains('sleet') || condition.contains('ice')) return 'snow';
    if (condition.contains('fog') || condition.contains('mist') || condition.contains('haze')) return 'fog';
    if (condition.contains('cloud') || condition.contains('overcast')) return 'cloudy';
    return 'clear';
  }
}
```

- [ ] **Step 3: 验证编译**

```bash
cd /d/zhang/aurora_bar && flutter analyze lib/services/weather_service.dart
```

- [ ] **Step 4: 提交**

```bash
cd /d/zhang/aurora_bar
git add pubspec.yaml pubspec.lock lib/services/weather_service.dart
git commit -m "feat: add weather service via wttr.in"
```

---

### Task 8: 动态背景组件 + FragmentShader 极光效果

**Files:**
- Create: `lib/shaders/aurora.frag`
- Create: `lib/widgets/dynamic_background.dart`
- Modify: `pubspec.yaml`

- [ ] **Step 1: 注册 shader 资源**

修改 `pubspec.yaml`，在 `flutter:` 段添加：

```yaml
flutter:
  uses-material-design: true

  shaders:                          # 新增
    - lib/shaders/aurora.frag       # 新增
```

- [ ] **Step 2: 编写 FragmentShader**

创建 `lib/shaders/aurora.frag`：

```glsl
#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uTime;
uniform vec3 uColor1;  // primary accent
uniform vec3 uColor2;  // secondary accent
uniform vec3 uColor3;  // background base

out vec4 fragColor;

// Simplex-like noise for flowing aurora bands
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution;
    vec2 st = uv;

    // Time-driven horizontal wave distortion
    float wave = sin(st.y * 6.0 + uTime * 0.3) * 0.04 +
                 sin(st.y * 10.0 - uTime * 0.5) * 0.03;

    // Multiple aurora bands
    float band1 = fbm(vec2(st.x + wave, st.y * 3.0 + uTime * 0.1)) * 0.15;
    float band2 = fbm(vec2(st.x + wave + 0.5, st.y * 2.5 - uTime * 0.13)) * 0.12;
    float band3 = fbm(vec2(st.x + wave - 0.3, st.y * 3.5 + uTime * 0.08)) * 0.10;

    // Combine bands into vertical strips
    float aurora = smoothstep(0.1, 0.5, band1) * (1.0 - abs(st.y - 0.3)) +
                   smoothstep(0.08, 0.4, band2) * (1.0 - abs(st.y - 0.5)) +
                   smoothstep(0.06, 0.35, band3) * (1.0 - abs(st.y - 0.7));

    aurora = clamp(aurora, 0.0, 0.7);

    // Background gradient
    vec3 bg = mix(uColor3, uColor1 * 0.3, st.y);

    // Apply aurora color
    vec3 auroraColor = mix(uColor1, uColor2, sin(st.y * 3.0 + uTime * 0.2) * 0.5 + 0.5);
    vec3 color = bg + aurora * auroraColor * 0.8;

    // Subtle vignette
    float vignette = 1.0 - smoothstep(0.4, 1.4, length(st - 0.5) * 1.5);
    color *= mix(0.7, 1.0, vignette);

    fragColor = vec4(color, 1.0);
}
```

- [ ] **Step 3: 创建动态背景组件**

创建 `lib/widgets/dynamic_background.dart`：

```dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/theme_engine.dart';

/// Renders a dynamic background combining:
/// - Animated gradient from ThemeEngine palette
/// - Optional GPU aurora shader overlay (if shader is loaded)
/// Fragmentshader is loaded once and cached.
class DynamicBackground extends StatefulWidget {
  final AuroraPalette palette;
  final bool showAurora;
  final Widget? child;

  const DynamicBackground({
    super.key,
    required this.palette,
    this.showAurora = true,
    this.child,
  });

  @override
  State<DynamicBackground> createState() => _DynamicBackgroundState();
}

class _DynamicBackgroundState extends State<DynamicBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  static ui.FragmentProgram? _auroraProgram;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
    _preloadShader();
  }

  static Future<void> _preloadShader() async {
    if (_auroraProgram != null) return;
    try {
      _auroraProgram = await ui.FragmentProgram.fromAsset('lib/shaders/aurora.frag');
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = widget.palette;
    return AnimatedContainer(
      duration: const Duration(seconds: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [pal.backgroundStart, pal.backgroundMid, pal.backgroundEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          if (widget.showAurora && _auroraProgram != null)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: _AuroraPainter(
                    program: _auroraProgram!,
                    time: _controller.value * 60,
                    palette: pal,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final ui.FragmentProgram program;
  final double time;
  final AuroraPalette palette;

  _AuroraPainter({
    required this.program,
    required this.time,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time)
      ..setFloat(3, palette.accent1.r / 255.0)
      ..setFloat(4, palette.accent1.g / 255.0)
      ..setFloat(5, palette.accent1.b / 255.0)
      ..setFloat(6, palette.accent2.r / 255.0)
      ..setFloat(7, palette.accent2.g / 255.0)
      ..setFloat(8, palette.accent2.b / 255.0)
      ..setFloat(9, palette.backgroundStart.r / 255.0)
      ..setFloat(10, palette.backgroundStart.g / 255.0)
      ..setFloat(11, palette.backgroundStart.b / 255.0);

    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.time != time || old.palette != palette;
}
```

- [ ] **Step 4: 验证编译**

```bash
cd /d/zhang/aurora_bar && flutter analyze lib/widgets/dynamic_background.dart
```

- [ ] **Step 5: 提交**

```bash
cd /d/zhang/aurora_bar
git add pubspec.yaml lib/shaders/aurora.frag lib/widgets/dynamic_background.dart
git commit -m "feat: add dynamic background with GPU aurora FragmentShader"
```

---

### Task 9: 心情选择器组件

**Files:**
- Create: `lib/widgets/mood_selector.dart`

- [ ] **Step 1: 创建心情选择器**

创建 `lib/widgets/mood_selector.dart`：

```dart
import 'package:flutter/material.dart';
import '../services/theme_engine.dart';

class MoodSelector extends StatelessWidget {
  final Mood current;
  final ValueChanged<Mood> onChanged;

  const MoodSelector({super.key, required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: Mood.values.map((mood) {
          final sel = current == mood;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onChanged(mood),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: sel
                      ? Colors.white.withOpacity(0.1)
                      : Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: sel
                        ? Colors.white.withOpacity(0.2)
                        : Colors.white.withOpacity(0.05),
                  ),
                ),
                child: Text(
                  '${_emoji(mood)}  ${_label(mood)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: sel ? Colors.white : Colors.white.withOpacity(0.35),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _emoji(Mood m) {
    switch (m) {
      case Mood.calm: return '🧘';
      case Mood.focused: return '🎯';
      case Mood.energetic: return '💪';
      case Mood.tired: return '😴';
      case Mood.creative: return '🎨';
    }
  }

  String _label(Mood m) {
    switch (m) {
      case Mood.calm: return 'Calm';
      case Mood.focused: return 'Focused';
      case Mood.energetic: return 'Energetic';
      case Mood.tired: return 'Tired';
      case Mood.creative: return 'Creative';
    }
  }
}
```

- [ ] **Step 2: 提交**

```bash
cd /d/zhang/aurora_bar
git add lib/widgets/mood_selector.dart
git commit -m "feat: add mood selector widget"
```

---

### Task 10: 天气粒子系统

**Files:**
- Create: `lib/widgets/weather_particle.dart`

- [ ] **Step 1: 创建天气粒子组件**

创建 `lib/widgets/weather_particle.dart`：

```dart
import 'dart:math';
import 'package:flutter/material.dart';

/// Renders weather-themed particle effects overlaid on the background.
/// Rain: falling streaks. Snow: drifting dots. Clear: subtle float.
class WeatherParticle extends StatefulWidget {
  final String? weatherCode;

  const WeatherParticle({super.key, this.weatherCode});

  @override
  State<WeatherParticle> createState() => _WeatherParticleState();
}

class _WeatherParticleState extends State<WeatherParticle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _random = Random(42);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.weatherCode;
    if (code == null || code == 'clear') return const SizedBox.shrink();

    final count = code == 'rain' ? 40 : (code == 'snow' ? 25 : 0);
    if (count == 0) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return CustomPaint(
          size: Size.infinite,
          painter: code == 'rain' ? _RainPainter(t, _random, count)
                                  : _SnowPainter(t, _random, count),
        );
      },
    );
  }
}

class _RainPainter extends CustomPainter {
  final double t;
  final Random random;
  final int count;

  _RainPainter(this.t, this.random, this.count);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF818cf8).withOpacity(0.12)
      ..strokeWidth = 1.0;

    for (var i = 0; i < count; i++) {
      final x = random.nextDouble() * size.width;
      final speed = 0.6 + random.nextDouble() * 0.4;
      final y = ((random.nextDouble() + t) * speed % 1.0) * size.height;
      final len = 8.0 + random.nextDouble() * 14;

      canvas.drawLine(
        Offset(x, y),
        Offset(x - 1.5, y - len),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RainPainter old) => old.t != t;
}

class _SnowPainter extends CustomPainter {
  final double t;
  final Random random;
  final int count;

  _SnowPainter(this.t, this.random, this.count);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.15);

    for (var i = 0; i < count; i++) {
      final x = random.nextDouble() * size.width;
      final drift = sin(t * 2 * pi + i) * 10;
      final speed = 0.3 + random.nextDouble() * 0.5;
      final y = ((random.nextDouble() + t * speed) % 1.0) * size.height;
      final r = 1.5 + random.nextDouble() * 2.5;

      canvas.drawCircle(Offset(x + drift, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_SnowPainter old) => old.t != t;
}
```

- [ ] **Step 2: 提交**

```bash
cd /d/zhang/aurora_bar
git add lib/widgets/weather_particle.dart
git commit -m "feat: add weather particle system (rain/snow)"
```

---

### Task 11: 组装 — 修改 BarView 和 PanelView 接入新背景和心情选择器

**Files:**
- Modify: `lib/widgets/bar_view.dart`
- Modify: `lib/widgets/panel_view.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: 修改 BarView — 包裹动态背景**

修改 `lib/widgets/bar_view.dart`。当前的 BarView 接收 `taskCount`、`onPeek`、`onQuit`。需要新增 `palette` 和 `weatherCode` 参数。

修改构造函数：

```dart
import '../services/theme_engine.dart';
import 'dynamic_background.dart';
import 'weather_particle.dart';

class BarView extends StatefulWidget {
  final int taskCount;
  final VoidCallback? onPeek;
  final VoidCallback? onQuit;
  final AuroraPalette palette;             // 新增
  final String? weatherCode;               // 新增

  const BarView({
    super.key,
    this.taskCount = 0,
    this.onPeek,
    this.onQuit,
    required this.palette,                 // 新增
    this.weatherCode,                      // 新增
  });
  // ...
}
```

修改 `build` 方法的 `Container` — 将其包在 `DynamicBackground` 中，并将原来的 `decoration` gradient 替换为从 palette 读取。找到 return 的 Container（约第 43 行），将整个 Container 改为：

```dart
@override
Widget build(BuildContext context) {
  final h = _now.hour.toString().padLeft(2, '0');
  final m = _now.minute.toString().padLeft(2, '0');
  final s = _now.second.toString().padLeft(2, '0');

  return ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: DynamicBackground(
      palette: widget.palette,
      showAurora: true,
      child: Stack(
        children: [
          Positioned.fill(
            child: WeatherParticle(weatherCode: widget.weatherCode),
          ),
          // Original Container content without the gradient decoration
          Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.palette.accent1.withOpacity(0.8),
                    boxShadow: [
                      BoxShadow(
                        color: widget.palette.accent1.withOpacity(0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [widget.palette.accent1, widget.palette.accent2],
                  ).createShader(bounds),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('$h:$m', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w200, letterSpacing: 3)),
                      Text(':$s', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13, fontWeight: FontWeight.w200)),
                    ],
                  ),
                ),
                const Spacer(),
                if (widget.taskCount > 0)
                  Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.palette.accent2.withOpacity(0.8)))
                else
                  Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.15))),
                const SizedBox(width: 10),
                if (widget.onPeek != null)
                  GestureDetector(
                    onTap: widget.onPeek,
                    child: Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.chevron_right, size: 14, color: Colors.white.withOpacity(0.3)),
                    ),
                  ),
                const SizedBox(width: 6),
                if (widget.onQuit != null)
                  GestureDetector(
                    onTap: widget.onQuit,
                    child: Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.power_settings_new, size: 12, color: Colors.white.withOpacity(0.3)),
                    ),
                  ),
                const SizedBox(width: 14),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 2: 修改 PanelView — 包裹动态背景 + 添加心情选择器**

修改 `lib/widgets/panel_view.dart`。PanelView 需要接收 palette 和 weatherCode。在 `_PanelViewState` 的 build 方法中，将现在的 Container 包装在 DynamicBackground 中。

修改 PanelView 构造函数（添加 palette 和 weatherCode 参数）：

```dart
class PanelView extends StatefulWidget {
  final AppState state;
  final VoidCallback onCollapse;
  final AuroraPalette palette;            // 新增
  final String? weatherCode;              // 新增

  const PanelView({
    super.key,
    required this.state,
    required this.onCollapse,
    required this.palette,                // 新增
    this.weatherCode,                     // 新增
  });
  // ...
}
```

修改 build 方法的根 Container — 与 BarView 类似，外面包 ClipRRect + DynamicBackground。同时，在 `_buildCategories()` 后面添加 `MoodSelector`：

```dart
import 'mood_selector.dart';
import 'dynamic_background.dart';
import 'weather_particle.dart';
```

在 build 的 Column children 中，`_buildCategories()` 之后插入：

```dart
const SizedBox(height: 6),
MoodSelector(
  current: widget.state.mood,
  onChanged: widget.state.setMood,
),
```

将原来的根 Container 替换为 DynamicBackground 包裹结构（与 BarView 风格一致）。

- [ ] **Step 3: 修改 main.dart — 启动时计算主题并传递**

修改 `lib/main.dart`。在 `_AuroraAppState` 中，启动时初始化天气并周期性更新。添加字段：

```dart
import 'services/weather_service.dart';
import 'services/theme_engine.dart';

class _AuroraAppState extends State<AuroraApp> {
  // ... existing ...
  final WeatherService _weather = WeatherService();
  String? _weatherCode;

  @override
  void initState() {
    super.initState();
    _currentOrigin = widget.collapsedOrigin;
    widget.state.init().then((_) {
      if (mounted) setState(() => _ready = true);
    });
    _updateWeather();
  }

  Future<void> _updateWeather() async {
    final code = await _weather.fetch();
    if (mounted && code != _weatherCode) {
      setState(() => _weatherCode = code);
      widget.state.themeEngine.setWeather(code);
    }
  }
  // ...
}
```

在 `build` 方法的 `ListenableBuilder` 中，计算当前 palette 并传递：

```dart
builder: (context, _) {
  final palette = widget.state.themeEngine.compute(DateTime.now());
  if (widget.state.isExpanded) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PanelView(
        state: widget.state,
        onCollapse: _collapse,
        palette: palette,
        weatherCode: _weatherCode,
      ),
    );
  }
  if (widget.state.isPeeking) {
    // ... peek state unchanged ...
  }
  return GestureDetector(
    onTap: () { _expand(); _updateWeather(); },
    onPanStart: (_) => windowManager.startDragging(),
    onPanEnd: (_) => _savePosition(),
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: BarView(
        taskCount: widget.state.activeCount,
        onPeek: _peek,
        onQuit: _quitApp,
        palette: palette,
        weatherCode: _weatherCode,
      ),
    ),
  );
},
```

- [ ] **Step 4: 修改 peek 态也使用动态颜色**

在 peek 态的 Container decoration 中，将硬编码的 `Color(0xDD302b63)` 和 `Color(0xDD0f0c29)` 替换为从 palette 读取：

```dart
decoration: BoxDecoration(
  gradient: LinearGradient(
    colors: [palette.accent1.withOpacity(0.6), palette.backgroundStart.withOpacity(0.8)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  ),
  borderRadius: BorderRadius.circular(10),
  border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
),
```

- [ ] **Step 5: 验证编译**

```bash
cd /d/zhang/aurora_bar && flutter analyze lib/
```

- [ ] **Step 6: 提交**

```bash
cd /d/zhang/aurora_bar
git add lib/widgets/bar_view.dart lib/widgets/panel_view.dart lib/main.dart
git commit -m "feat: integrate dynamic background, mood selector, and weather into UI"
```

---

### Task 12: 端到端验证

**Files:**
- 无新建/修改，仅运行验证

- [ ] **Step 1: 运行完整静态分析**

```bash
cd /d/zhang/aurora_bar && flutter analyze
```
预期：无 error（warning 和 info 允许）。

- [ ] **Step 2: 运行单元测试**

```bash
cd /d/zhang/aurora_bar && flutter test
```
预期：所有测试通过（含新增的 nlp_parser 测试）。

- [ ] **Step 3: 构建 Windows 可执行文件**

```bash
cd /d/zhang/aurora_bar && flutter build windows
```
预期：构建成功，无编译错误。

- [ ] **Step 4: 启动应用进行手动验证**

```bash
cd /d/zhang/aurora_bar/build/windows/x64/runner/Release && ./aurora_bar.exe
```

验证清单：
1. 收起态背景有动态渐变（随时间变化能看出色相差异）
2. 展开面板后能看到心情选择器（🧘 🎯 💪 😴 🎨），点击切换后整体配色改变
3. 输入"明天下午3点复习高等数学"→ 自动显示时间预览（明天 15:00）和 #学习 标签
4. 输入"后天跑步"→ 自动显示时间 + #运动 标签
5. 面板右下角 Claude 按钮正常工作
6. peek 态颜色跟随 palette
7. 拖动窗口功能正常
8. 开关机自启、桌面快捷方式正常

- [ ] **Step 5: 提交最终版本**

```bash
cd /d/zhang/aurora_bar
git add -A
git commit -m "feat: complete semantic task parsing + dynamic theming integration"
```
