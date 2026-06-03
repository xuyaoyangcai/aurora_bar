import 'dart:convert';
import 'package:http/http.dart' as http;
import 'nlp_parser.dart';

/// Smart NLP via local Ollama (qwen2.5:1.5b).
/// Falls back to null on any error — caller should use regex [NlpParser] instead.
class OllamaNlpService {
  static const _url = 'http://localhost:11434/api/chat';
  static const _model = 'qwen2.5:1.5b';
  static const _timeout = Duration(seconds: 4);

  /// Returns a [ParsedTask] from Ollama, or null if unavailable/timed out.
  static Future<ParsedTask?> parse(String input) async {
    try {
      final now = DateTime.now();
      final dateStr =
          '${now.year}年${now.month}月${now.day}日 ${now.hour}:${now.minute.toString().padLeft(2, '0')}'
          ' (星期${['日','一','二','三','四','五','六'][now.weekday % 7]})';

      final resp = await http
          .post(
            Uri.parse(_url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': _model,
              'stream': false,
              'messages': [
                {
                  'role': 'system',
                  'content':
                      '你是任务解析器。只返回JSON，不解释。\n'
                          '格式：{"title":"标题","date":"YYYY-MM-DD或null","time":"HH:MM或null","tags":["标签"]}\n'
                          '可用标签：学习,阅读,工作,运动,生活\n'
                          '\n'
                          '示例:\n'
                          '输入:明天下午3点交数学作业\n'
                          '输出:{"title":"交数学作业","date":"2026-06-04","time":"15:00","tags":["学习"]}\n'
                          '输入:晚上跑步\n'
                          '输出:{"title":"跑步","date":"2026-06-03","time":"20:00","tags":["运动"]}\n'
                          '输入:看书\n'
                          '输出:{"title":"看书","date":null,"time":null,"tags":["阅读"]}',
                },
                {
                  'role': 'user',
                  'content': '当前时间：$dateStr\n输入：$input',
                },
              ],
            }),
          )
          .timeout(_timeout);

      if (resp.statusCode != 200) return null;
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final msg = body['message'] as Map<String, dynamic>?;
      final content = msg?['content'] as String?;
      if (content == null) return null;

      return _extractJson(content, now, input);
    } catch (_) {
      return null;
    }
  }

  /// Extract JSON from model response, which may contain extra text.
  static ParsedTask? _extractJson(String raw, DateTime now, String original) {
    // Try to find JSON block first
    String? jsonStr;
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start >= 0 && end > start) {
      jsonStr = raw.substring(start, end + 1);
    }

    if (jsonStr == null) return null;
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final title = (map['title'] as String?) ?? original;
      final dateStr = map['date'] as String?;
      final timeStr = map['time'] as String?;
      final tags = (map['tags'] as List?)?.map((e) => e.toString()).toList();

      DateTime? due;
      if (dateStr != null && dateStr != 'null') {
        final dateParts = dateStr.split('-');
        if (dateParts.length == 3) {
          final y = int.tryParse(dateParts[0]) ?? now.year;
          final m = int.tryParse(dateParts[1]) ?? now.month;
          final d = int.tryParse(dateParts[2]) ?? now.day;
          var h = 9;
          var min = 0;
          if (timeStr != null && timeStr != 'null') {
            final timeParts = timeStr.split(':');
            if (timeParts.isNotEmpty) h = int.tryParse(timeParts[0]) ?? 9;
            if (timeParts.length >= 2) min = int.tryParse(timeParts[1]) ?? 0;
          }
          due = DateTime(y, m, d, h, min);
        }
      }

      return ParsedTask(title: title, dueDate: due, tags: tags ?? []);
    } catch (_) {
      return null;
    }
  }
}
