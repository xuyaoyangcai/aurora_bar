import 'package:flutter_test/flutter_test.dart';
import 'package:aurora_bar/services/nlp_parser.dart';

void main() {
  group('NlpParser time extraction', () {
    test('明天下午3点', () {
      final r = NlpParser.parse('明天下午3点记得复习 Hofstede 的文化维度理论');
      expect(r.dueDate, isNotNull);
      expect(r.dueDate!.hour, 15);
    });

    test('后天', () {
      final r = NlpParser.parse('后天交报告');
      expect(r.dueDate, isNotNull);
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final diff = r.dueDate!.difference(today).inDays;
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

    test('bare 下午3点', () {
      final r = NlpParser.parse('下午3点开会');
      expect(r.dueDate, isNotNull);
      expect(r.dueDate!.hour, 15);
    });

    test('X月Y日', () {
      final r = NlpParser.parse('12月25日圣诞节');
      expect(r.dueDate, isNotNull);
      expect(r.dueDate!.month, 12);
      expect(r.dueDate!.day, 25);
    });

    test('明天3点 without period', () {
      final r = NlpParser.parse('明天3点交报告');
      expect(r.dueDate, isNotNull);
      expect(r.dueDate!.hour, 3);
    });

    test('早上7点', () {
      final r = NlpParser.parse('明天早上7点出发');
      expect(r.dueDate, isNotNull);
      expect(r.dueDate!.hour, 7);
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
