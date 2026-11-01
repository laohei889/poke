// 列表中的单条待办：圆形勾选框 + 标题 + 截止/重复信息 + 优先级圆点，
// 点击进入编辑，菜单提供 完成 / 删除。
import 'package:flutter/material.dart';

import '../models/todo_item.dart';
import '../theme/app_theme_extension.dart';

/// 列表中的单条待办
class TodoListItem extends StatelessWidget {
  const TodoListItem({
    super.key,
    required this.todo,
    required this.onComplete,
    required this.onEdit,
    required this.onDelete,
  });

  final TodoItem todo;
  final VoidCallback onComplete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static const _repeatIcons = <RepeatType, IconData>{
    RepeatType.daily: Icons.repeat_rounded,
    RepeatType.workday: Icons.work_history_outlined,
    RepeatType.weekly: Icons.date_range_rounded,
    RepeatType.monthly: Icons.calendar_month_rounded,
    RepeatType.customInterval: Icons.timelapse_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final due = todo.effectiveDue;
    final overdue = todo.isOverdue;
    final isDone = todo.status == TodoStatus.completed ||
        todo.status == TodoStatus.archived;

    final dueText = due == null ? '无截止时间' : _formatDue(due, overdue);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        shadowColor: const Color(0x0F2E3A36),
        elevation: 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            child: Row(
              children: [
                _CheckButton(done: isDone, onTap: onComplete),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              todo.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                decoration: isDone ? TextDecoration.lineThrough : null,
                                color: isDone ? scheme.outline : null,
                              ),
                            ),
                          ),
                          if (todo.status == TodoStatus.inProgress) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '执行中',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            overdue
                                ? Icons.error_outline_rounded
                                : Icons.schedule_rounded,
                            size: 14,
                            color: overdue ? scheme.error : scheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dueText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: overdue ? scheme.error : scheme.outline,
                            ),
                          ),
                          if (todo.isRepeating) ...[
                            const SizedBox(width: 10),
                            Icon(
                              _repeatIcons[todo.repeatType] ?? Icons.repeat_rounded,
                              size: 14,
                              color: scheme.outline,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _repeatLabel(),
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: scheme.outline),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                _PriorityDot(priority: todo.priority),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit();
                      case 'done':
                        onComplete();
                      case 'delete':
                        onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('编辑')),
                    // 已完成/已归档的事项不再提供"完成"，避免重复触发排期
                    if (!isDone)
                      const PopupMenuItem(value: 'done', child: Text('完成')),
                    const PopupMenuItem(value: 'delete', child: Text('删除')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _repeatLabel() {
    switch (todo.repeatType) {
      case RepeatType.daily:
        return '每天';
      case RepeatType.workday:
        return '工作日';
      case RepeatType.weekly:
        return todo.repeatDays.isEmpty
            ? '每周'
            : '每周 ${todo.repeatDays.map((d) => '周${_dayName[d]}').join(' ')}';
      case RepeatType.monthly:
        return '每月';
      case RepeatType.yearly:
        return '每年';
      case RepeatType.customInterval:
        return '每 ${todo.intervalDays} 天';
      case RepeatType.none:
        return '';
    }
  }

  static const _dayName = {1: '一', 2: '二', 3: '三', 4: '四', 5: '五', 6: '六', 7: '日'};

  String _formatDue(DateTime due, bool overdue) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(due.year, due.month, due.day);
    final time =
        '${due.hour.toString().padLeft(2, '0')}:${due.minute.toString().padLeft(2, '0')}';

    String prefix;
    if (day == today) {
      prefix = '今天';
    } else if (day == today.add(const Duration(days: 1))) {
      prefix = '明天';
    } else if (day == today.subtract(const Duration(days: 1))) {
      prefix = '昨天';
    } else {
      prefix = '${due.month}月${due.day}日';
    }
    return '$prefix $time${overdue ? ' · 已逾期' : ''}';
  }
}

class _CheckButton extends StatelessWidget {
  const _CheckButton({required this.done, required this.onTap});

  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      customBorder: const CircleBorder(),
      // 已完成的事项不再响应点击，防止重复"完成"导致重复事项被复活排期
      onTap: done ? null : onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? scheme.primary : Colors.transparent,
          border: Border.all(
            color: done ? scheme.primary : scheme.outlineVariant,
            width: 2,
          ),
        ),
        child: done
            ? Icon(Icons.check_rounded, size: 18, color: scheme.onPrimary)
            : null,
      ),
    );
  }
}

class _PriorityDot extends StatelessWidget {
  const _PriorityDot({required this.priority});

  final int priority;

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    // 优先级用同色相深浅表达，避免红黄绿三色噪音；红色只留给逾期
    final (color, filled) = switch (priority) {
      3 => (t.priorityHigh, true),
      2 => (t.priorityMid, false),
      _ => (t.priorityLow, false),
    };
    final label = switch (priority) { 3 => '高', 1 => '低', _ => '中' };

    return Tooltip(
      message: '$label优先级',
      child: Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? color : Colors.transparent,
          border: filled ? null : Border.all(color: color, width: 1.6),
        ),
      ),
    );
  }
}
