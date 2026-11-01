import 'package:flutter_test/flutter_test.dart';
import 'package:poke/models/todo_item.dart';
import 'package:poke/utils/csv.dart';
import 'package:poke/utils/date_utils.dart';

TodoItem _todo({
  RepeatType repeatType = RepeatType.none,
  List<int> repeatDays = const [],
  int intervalDays = 1,
  DateTime? dueDate,
  DateTime? nextDueDate,
}) {
  final now = DateTime(2026, 10, 25, 10);
  return TodoItem(
    id: 't1',
    title: '测试',
    dueDate: dueDate ?? DateTime(2026, 10, 25, 18),
    repeatType: repeatType,
    repeatDays: repeatDays,
    intervalDays: intervalDays,
    nextDueDate: nextDueDate,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('重复事项排期', () {
    test('每天 +1 天', () {
      final next = calculateNextDueDate(
        _todo(repeatType: RepeatType.daily, dueDate: DateTime(2026, 10, 25, 18)),
      );
      expect(next, DateTime(2026, 10, 26, 18));
    });

    test('工作日跳过周末', () {
      final next = calculateNextDueDate(
        _todo(repeatType: RepeatType.workday, dueDate: DateTime(2026, 10, 23)), // 周五
      );
      expect(next, DateTime(2026, 10, 26)); // 周一
    });

    test('每周指定周几', () {
      final next = calculateNextDueDate(
        _todo(
          repeatType: RepeatType.weekly,
          repeatDays: [1, 4], // 周一、周四
          dueDate: DateTime(2026, 10, 26), // 周一
        ),
      );
      expect(next, DateTime(2026, 10, 29)); // 周四
    });

    test('每月 +1 月并处理月末溢出', () {
      final next = calculateNextDueDate(
        _todo(repeatType: RepeatType.monthly, dueDate: DateTime(2026, 1, 31)),
      );
      expect(next, DateTime(2026, 2, 28));
    });

    test('每年（生日类）保留时分秒', () {
      final next = calculateNextDueDate(
        _todo(
          repeatType: RepeatType.yearly,
          dueDate: DateTime(2026, 3, 15, 8, 30),
        ),
      );
      expect(next, DateTime(2027, 3, 15, 8, 30));
    });

    test('重复事项排期保留原有时刻（修复 0:00 问题）', () {
      final next = calculateNextDueDate(
        _todo(repeatType: RepeatType.daily, dueDate: DateTime(2026, 10, 25, 18)),
      );
      expect(next, DateTime(2026, 10, 26, 18));

      final done = applyCompletion(
        _todo(repeatType: RepeatType.daily, dueDate: DateTime(2026, 10, 25, 18)),
        DateTime(2026, 10, 25, 20),
      );
      expect(done.nextDueDate, DateTime(2026, 10, 26, 18));
    });

    test('自定义间隔', () {
      final next = calculateNextDueDate(
        _todo(
          repeatType: RepeatType.customInterval,
          intervalDays: 3,
          dueDate: DateTime(2026, 10, 25),
        ),
      );
      expect(next, DateTime(2026, 10, 28));
    });
  });

  group('完成状态流转', () {
    test('单次事项完成后归档', () {
      final done = applyCompletion(_todo(), DateTime(2026, 10, 25, 20));
      expect(done.status, TodoStatus.archived);
      expect(done.lastDoneAt, DateTime(2026, 10, 25, 20));
    });

    test('重复事项完成后回 pending 并排期', () {
      final done = applyCompletion(
        _todo(repeatType: RepeatType.daily, dueDate: DateTime(2026, 10, 25, 18)),
        DateTime(2026, 10, 25, 20),
      );
      expect(done.status, TodoStatus.pending);
      expect(done.nextDueDate, DateTime(2026, 10, 26, 18));
    });

    test('逾期重复事项补追排期到未来（不残留逾期）', () {
      // 每日任务已逾期 10 天，完成一次后排到下一个不早于“现在”的周期
      final done = applyCompletion(
        _todo(repeatType: RepeatType.daily, dueDate: DateTime(2026, 10, 15, 18)),
        DateTime(2026, 10, 25, 20),
      );
      expect(done.status, TodoStatus.pending);
      expect(done.nextDueDate!.isBefore(DateTime(2026, 10, 25, 20)), false);
      expect(done.nextDueDate, DateTime(2026, 10, 26, 18));
    });
  });

  group('CSV 工具', () {
    test('解析引号包裹字段与逗号', () {
      final rows = parseCsv('title,desc\n"a,b","含""引号"""');
      expect(rows.length, 2);
      expect(rows[1][0], 'a,b');
      expect(rows[1][1], '含"引号"');
    });

    test('生成 CSV 后可回读', () {
      final csv = toCsv([
        ['title', 'desc'],
        ['买牛奶', '含,逗号'],
      ]);
      final rows = parseCsv(csv);
      expect(rows[1][1], '含,逗号');
    });
  });

  group('TodoItem 序列化', () {
    test('toMap / fromMap 往返一致', () {
      final todo = _todo(
        repeatType: RepeatType.weekly,
        repeatDays: [2, 5],
        nextDueDate: DateTime(2026, 10, 27),
      );
      final restored = TodoItem.fromMap(todo.toMap());
      expect(restored.title, todo.title);
      expect(restored.repeatType, RepeatType.weekly);
      expect(restored.repeatDays, [2, 5]);
      expect(restored.nextDueDate, todo.nextDueDate);
    });
  });
}
