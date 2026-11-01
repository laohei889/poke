// 底部快速录入栏：一行输入标题回车即创建，
// 快捷标签 [今天 / 明天 / 每周 / 定时 / 更多] 快速设定规则。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/todo_provider.dart';
import '../screens/add_todo_screen.dart';
import 'calendar_dialog.dart';
import 'repeat_rule_dialog.dart';

/// 底部快速录入栏：一行输入标题 + 快捷标签
class QuickInputBar extends ConsumerStatefulWidget {
  const QuickInputBar({super.key});

  @override
  ConsumerState<QuickInputBar> createState() => _QuickInputBarState();
}

class _QuickInputBarState extends ConsumerState<QuickInputBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _hint(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  void _clear() {
    _controller.clear();
    setState(() {});
  }

  /// 快捷创建：重复/定时规则由快捷标签决定
  Future<void> _quickCreate({
    DateTime? dueDate,
    RepeatRule rule = const RepeatRule(),
    bool? syncCalendar,
  }) async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _hint('先输入要做的事，再点快捷标签');
      return;
    }
    await ref.read(todoProvider.notifier).create(
      title: text,
      dueDate: dueDate,
      repeatType: rule.type,
      repeatDays: rule.days,
      intervalDays: rule.intervalDays,
      syncCalendar: syncCalendar,
    );
    _clear();
    // 日历写入失败时明确提示，避免"提醒静默丢失"
    final err = ref.read(todoProvider.notifier).lastCalendarError;
    if (err != null) _hint('已添加，但日历提醒未写入：$err');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.edit_note_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      hintText: '添加待办，回车即创建…',
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _quickCreate(),
                  ),
                ),
                IconButton(
                  tooltip: '创建',
                  onPressed: _controller.text.trim().isEmpty ? null : () => _quickCreate(),
                  icon: const Icon(Icons.add_circle_rounded),
                  color: scheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 2),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chip('今天', Icons.today_rounded, onTap: () {
                    final now = DateTime.now();
                    _quickCreate(
                      dueDate: DateTime(now.year, now.month, now.day, 18),
                    );
                  }),
                  _chip('明天', Icons.wb_sunny_outlined, onTap: () {
                    final now = DateTime.now().add(const Duration(days: 1));
                    _quickCreate(
                      dueDate: DateTime(now.year, now.month, now.day, 9),
                    );
                  }),
                  _chip('每周', Icons.repeat_rounded, onTap: () async {
                    if (_controller.text.trim().isEmpty) {
                      _hint('先输入要做的事，再设置重复');
                      return;
                    }
                    final rule = await showRepeatRuleDialog(context);
                    if (rule == null || !mounted) return;
                    await _quickCreate(rule: rule);
                  }),
                  _chip('定时', Icons.alarm_rounded, onTap: () async {
                    if (_controller.text.trim().isEmpty) {
                      _hint('先输入要做的事，再设置提醒时间');
                      return;
                    }
                    final now = DateTime.now();
                    final date = await showDatePicker(
                      context: context,
                      initialDate: now,
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 5),
                    );
                    if (date == null) return;
                    if (!context.mounted) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
                    );
                    if (time == null) return;
                    if (!context.mounted) return;
                    final due = DateTime(
                      date.year,
                      date.month,
                      date.day,
                      time.hour,
                      time.minute,
                    );
                    // 确保日历权限与目标日历就绪，否则"定时"的提醒会写不进去
                    await ensureCalendarReady(context, ref);
                    if (!mounted) return;
                    await _quickCreate(dueDate: due, syncCalendar: true);
                  }),
                  _chip('更多', Icons.tune_rounded, onTap: () async {
                    final text = _controller.text.trim();
                    final created = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddTodoScreen(initialTitle: text),
                      ),
                    );
                    if (created == true) _clear();
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, IconData icon, {required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(icon, size: 16),
        label: Text(label),
        visualDensity: VisualDensity.compact,
        onPressed: onTap,
      ),
    );
  }
}
