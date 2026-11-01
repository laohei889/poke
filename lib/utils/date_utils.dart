// 重复排期算法：完成后计算下次到期时间，**保留原有时分秒**（App 与 Web 控制台共用）。
import '../models/todo_item.dart';

/// 计算下次到期时间（重复事项核心逻辑）。
///
/// [base] 为基准时间，默认取 `nextDueDate ?? dueDate ?? now`。
/// 所有分支都保留基准时间的时分秒，避免"每日 18:00"排期后变 0:00。
DateTime calculateNextDueDate(TodoItem todo, {DateTime? base}) {
  final from = base ??
      todo.nextDueDate ??
      todo.dueDate ??
      DateTime.now();
  switch (todo.repeatType) {
    case RepeatType.none:
      return from;
    case RepeatType.daily:
      return from.add(const Duration(days: 1));
    case RepeatType.workday:
      return nextWorkday(from);
    case RepeatType.weekly:
      if (todo.repeatDays.isNotEmpty) {
        return nextWeekday(from, todo.repeatDays);
      }
      return from.add(const Duration(days: 7));
    case RepeatType.monthly:
      return addMonths(from, 1);
    case RepeatType.yearly:
      return addMonths(from, 12);
    case RepeatType.customInterval:
      final days = todo.intervalDays < 1 ? 1 : todo.intervalDays;
      return from.add(Duration(days: days));
  }
}

/// 下一个工作日（跳过周六、周日），保留时分秒
DateTime nextWorkday(DateTime base) {
  var d = base.add(const Duration(days: 1));
  while (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
    d = d.add(const Duration(days: 1));
  }
  return d;
}

/// 下一个命中 [weekdays]（1=周一 ... 7=周日）的日期，保留时分秒
DateTime nextWeekday(DateTime base, List<int> weekdays) {
  final set = weekdays.toSet();
  var d = base.add(const Duration(days: 1));
  for (var i = 0; i < 8; i++) {
    if (set.contains(d.weekday)) return d;
    d = d.add(const Duration(days: 1));
  }
  return d;
}

/// 加若干月（自动处理月末日期溢出，如 1/31 + 1 月 → 2/28），保留时分秒
DateTime addMonths(DateTime dt, int months) {
  final year = dt.year + ((dt.month - 1 + months) ~/ 12);
  final month = (dt.month - 1 + months) % 12 + 1;
  final daysInMonth = DateTime(year, month + 1, 0).day;
  final day = dt.day > daysInMonth ? daysInMonth : dt.day;
  return DateTime(year, month, day, dt.hour, dt.minute);
}

/// 完成事项：单次归档；重复事项自动排期并回到 pending。
/// App 与 Web 控制台共用同一套逻辑。
///
/// 逾期的重复事项按周期逐次补追，排到下一个不早于 [now] 的周期，
/// 避免"完成后仍然逾期"（如逾期 10 天的每日任务要连做 10 次才追上今天）。
TodoItem applyCompletion(TodoItem todo, DateTime now) {
  if (todo.isRepeating) {
    var next = calculateNextDueDate(todo, base: todo.effectiveDue ?? now);
    // 上限防御：intervalDays 异常等极端数据不应导致死循环
    var guard = 0;
    while (next.isBefore(now) && guard++ < 1000) {
      next = calculateNextDueDate(todo, base: next);
    }
    return todo.copyWith(
      lastDoneAt: now,
      nextDueDate: next,
      status: TodoStatus.pending,
      clearAcceptedAt: true,
      updatedAt: now,
    );
  }
  return todo.copyWith(
    lastDoneAt: now,
    status: TodoStatus.archived,
    clearAcceptedAt: true,
    updatedAt: now,
  );
}

/// 解析 CSV / Web 导入中的日期字段
DateTime? parseFlexibleDate(String? raw) {
  if (raw == null) return null;
  final s = raw.trim();
  if (s.isEmpty) return null;
  final iso = DateTime.tryParse(s);
  if (iso != null) return iso;
  // 兼容 "2026-10-22 18:00" / "2026/10/22 18:00" / "2026-10-22"
  final normalized = s.replaceAll('/', '-');
  return DateTime.tryParse(normalized.replaceAll(' ', 'T'));
}
