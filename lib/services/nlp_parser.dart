/// Lightweight NLP parser for Chinese natural language task input.
/// Extracts due dates, times, and auto-tags from free-text input.
class NlpParser {
  // ── Static regex patterns ──

  static final _tomorrowHourRe = RegExp(
      r'明天(?:上午|下午|晚上|早上|中午)?(\d{1,2})[点:：](\d{0,2})?');
  static final _tomorrowRe = RegExp(r'明天');
  static final _dayAfterRe = RegExp(r'后天');
  static final _todayHourRe = RegExp(
      r'今天(?:上午|下午|晚上|早上|中午)?(\d{1,2})[点:：](\d{0,2})?');
  static final _nextWeekRe = RegExp(r'下周([一二三四五六七日天])');
  static final _thisWeekRe = RegExp(r'(?:周|星期)([一二三四五六七日天])');
  static final _monthDayRe = RegExp(r'(\d{1,2})月(\d{1,2})[日号]');
  static final _bareHourRe = RegExp(
      r'([上中下晚早]午?|晚上|早上|中午)(\d{1,2})[点:：](\d{0,2})?');

  /// Result of parsing a task string.
  final ParsedTask result;

  NlpParser._(this.result);

  /// The extracted due date (convenience getter).
  DateTime? get dueDate => result.dueDate;

  /// The extracted tags (convenience getter).
  List<String> get tags => result.tags;

  /// The cleaned title text (convenience getter).
  String get title => result.title;

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

    // "明天下午3点" / "明天3点" / "明天早上7点"
    final matchTH = _tomorrowHourRe.firstMatch(text);
    if (matchTH != null) {
      int h = int.parse(matchTH.group(1)!);
      final m = matchTH.group(2)?.isNotEmpty == true
          ? int.parse(matchTH.group(2)!)
          : 0;
      if ((text.contains('下') || text.contains('晚')) && h < 12) h += 12;
      if (text.contains('上') && h == 12) h = 0;
      if (text.contains('中')) h = 12;
      return today.add(const Duration(days: 1)).add(Duration(hours: h, minutes: m));
    }

    // "明天" without specific time → 9:00
    if (_tomorrowRe.hasMatch(text)) {
      return today.add(const Duration(days: 1, hours: 9));
    }

    // "后天" → 9:00
    if (_dayAfterRe.hasMatch(text)) {
      return today.add(const Duration(days: 2, hours: 9));
    }

    // "今天下午3点" / "今晚8点" / "今天3点半" / "今天早上7点" / "今天中午12点"
    final matchToday = _todayHourRe.firstMatch(text);
    if (matchToday != null) {
      int h = int.parse(matchToday.group(1)!);
      final m = matchToday.group(2)?.isNotEmpty == true
          ? int.parse(matchToday.group(2)!)
          : 0;
      if ((text.contains('下') || text.contains('晚')) && h < 12) h += 12;
      if (text.contains('上') && h == 12) h = 0;
      if (text.contains('中')) h = 12;
      return today.add(Duration(hours: h, minutes: m));
    }

    // "下周X" → next week that day
    final matchNW = _nextWeekRe.firstMatch(text);
    if (matchNW != null) {
      final dayChar = matchNW.group(1)!;
      final targetWday = _weekdayFromChinese(dayChar);
      final daysUntil = (targetWday - now.weekday + 7) % 7 + 7;
      return today.add(Duration(days: daysUntil, hours: 9));
    }

    // "周X" / "星期X" → this week (or next if already passed)
    final matchTW = _thisWeekRe.firstMatch(text);
    if (matchTW != null) {
      final dayChar = matchTW.group(1)!;
      final targetWday = _weekdayFromChinese(dayChar);
      var daysUntil = (targetWday - now.weekday + 7) % 7;
      final candidate = today.add(Duration(days: daysUntil, hours: 9));
      if (!candidate.isAfter(now)) daysUntil += 7;
      return today.add(Duration(days: daysUntil, hours: 9));
    }

    // "X月Y日" / "X月Y号"
    final matchMD = _monthDayRe.firstMatch(text);
    if (matchMD != null) {
      final m = int.parse(matchMD.group(1)!);
      final d = int.parse(matchMD.group(2)!);
      return DateTime(now.year, m, d, 9);
    }

    // "晚上8点" / "下午3点" / "早上9点" (no date prefix)
    final matchBH = _bareHourRe.firstMatch(text);
    if (matchBH != null) {
      int h = int.parse(matchBH.group(2)!);
      final m = matchBH.group(3)?.isNotEmpty == true
          ? int.parse(matchBH.group(3)!)
          : 0;
      final period = matchBH.group(1)!;
      if ((period == '下' || period == '下午' || period == '晚' || period == '晚上') &&
          h < 12) {
        h += 12;
      }
      if ((period == '上' || period == '上午' || period == '早' || period == '早上') &&
          h == 12) {
        h = 0;
      }
      if (period == '中' || period == '中午') h = 12;
      return today.add(Duration(hours: h, minutes: m));
    }

    return null;
  }

  static int _weekdayFromChinese(String s) {
    const map = {
      '一': 1,
      '二': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '日': 7,
      '天': 7,
    };
    final result = map[s];
    if (result == null) throw ArgumentError('Unknown weekday character: $s');
    return result;
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
