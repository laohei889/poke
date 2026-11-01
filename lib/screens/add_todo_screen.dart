// 完整录入 / 编辑表单页：标题、备注、截止时间、重复规则、
// 优先级、系统日历同步开关。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/todo_item.dart';
import '../providers/todo_provider.dart';
import '../widgets/calendar_dialog.dart';
import '../widgets/repeat_rule_dialog.dart';

/// 完整录入 / 编辑表单
class AddTodoScreen extends ConsumerStatefulWidget {
  const AddTodoScreen({super.key, this.todo, this.initialTitle});

  final TodoItem? todo;
  final String? initialTitle;

  @override
  ConsumerState<AddTodoScreen> createState() => _AddTodoScreenState();
}

class _AddTodoScreenState extends ConsumerState<AddTodoScreen> {
  late final TextEditingController _titleController =
      TextEditingController(text: _initTitle);
  late final TextEditingController _descController =
      TextEditingController(text: widget.todo?.description ?? '');

  String get _initTitle => widget.todo?.title ?? widget.initialTitle ?? '';

  DateTime? _due;
  RepeatRule _rule = const RepeatRule();
  int _priority = 2;
  bool _syncCalendar = false;

  bool get _isEditing => widget.todo != null;

  @override
  void initState() {
    super.initState();
    final todo = widget.todo;
    if (todo != null) {
      _due = todo.effectiveDue;
      _rule = RepeatRule(
        type: todo.repeatType,
        days: List.of(todo.repeatDays),
        intervalDays: todo.intervalDays,
      );
      _priority = todo.priority;
    }
    // 开关反映"该待办当前是否有日历事件"，而非全局设置，
    // 避免保存单条待办时意外改写全局同步状态
    _syncCalendar = (widget.todo?.calendarEventId != null) ||
        ref.read(settingsProvider).calendarSyncEnabled;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _due ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null) return;
    setState(() {
      _due = DateTime(date.year, date.month, date.day, _due?.hour ?? 18, _due?.minute ?? 0);
    });
  }

  Future<void> _pickTime() async {
    final base = _due ?? DateTime.now();
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return;
    setState(() {
      _due = DateTime(base.year, base.month, base.day, time.hour, time.minute);
    });
  }

  Future<void> _chooseRepeatRule() async {
    final rule = await showRepeatRuleDialog(context, initial: _rule);
    if (rule == null) return;
    setState(() => _rule = rule);
  }

  /// 确保日历权限与目标日历已就绪
  Future<bool> _prepareCalendar() async {
    if (!_syncCalendar) return true;
    final settings = ref.read(settingsProvider);
    final calendarService = ref.read(calendarServiceProvider);

    var granted = await calendarService.hasPermissions();
    if (!granted) granted = await calendarService.requestPermissions();
    if (!granted) {
      _snack('未授予日历权限，本次不写入系统日历');
      return false;
    }

    if (settings.calendarId == null) {
      if (!mounted) return false;
      final id = await pickCalendar(context);
      if (id == null) {
        _snack('未选择日历，本次不写入系统日历');
        return false;
      }
      await ref.read(settingsProvider.notifier).setCalendarId(id);
    }
    return true;
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _snack('请填写标题');
      return;
    }

    final controller = ref.read(todoProvider.notifier);
    final syncReady = await _prepareCalendar();
    // 本次保存的日历意图：开关开且就绪才写入；关则明确删除已有事件。
    // 不回写全局设置，全局开关只在设置页管理。
    final wantEvent = _syncCalendar && syncReady;

    if (_isEditing) {
      final todo = widget.todo!;
      final isRepeating = _rule.type != RepeatType.none;
      final desc = _descController.text.trim();
      final updated = todo.copyWith(
        title: title,
        description: desc.isEmpty ? null : desc,
        clearDescription: desc.isEmpty,
        dueDate: _due,
        clearDueDate: _due == null,
        repeatType: _rule.type,
        repeatDays: _rule.days,
        intervalDays: _rule.intervalDays,
        nextDueDate: isRepeating ? (_due ?? todo.nextDueDate ?? DateTime.now()) : null,
        clearNextDueDate: !isRepeating,
        priority: _priority,
        updatedAt: DateTime.now(),
      );
      await controller.save(updated, syncCalendar: wantEvent);
    } else {
      await controller.create(
        title: title,
        description: _descController.text.trim(),
        dueDate: _due,
        repeatType: _rule.type,
        repeatDays: _rule.days,
        intervalDays: _rule.intervalDays,
        priority: _priority,
        syncCalendar: wantEvent,
      );
    }

    // 日历写入失败时明确提示，避免"提醒静默丢失"
    final warn = controller.lastCalendarError;
    if (warn != null) {
      _snack('已保存，但日历提醒未写入：$warn');
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑待办' : '新建待办'),
        actions: [
          TextButton(onPressed: _save, child: const Text('保存')),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(
            controller: _titleController,
            autofocus: !_isEditing,
            textInputAction: TextInputAction.next,
            style: theme.textTheme.titleMedium,
            decoration: const InputDecoration(
              labelText: '标题',
              hintText: '要做什么？',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _descController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '备注（可选）',
              hintText: '补充说明、地点、链接…',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 22),
          _sectionTitle(context, '截止时间'),
          Row(
            children: [
              Expanded(
                child: _selectorTile(
                  icon: Icons.event_rounded,
                  label: _due == null
                      ? '选择日期'
                      : '${_due!.year}-${_due!.month.toString().padLeft(2, '0')}-${_due!.day.toString().padLeft(2, '0')}',
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _selectorTile(
                  icon: Icons.schedule_rounded,
                  label: _due == null
                      ? '选择时间'
                      : '${_due!.hour.toString().padLeft(2, '0')}:${_due!.minute.toString().padLeft(2, '0')}',
                  onTap: _pickTime,
                ),
              ),
              if (_due != null)
                IconButton(
                  tooltip: '清除截止时间',
                  onPressed: () => setState(() => _due = null),
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
          const SizedBox(height: 22),
          _sectionTitle(context, '重复'),
          _selectorTile(
            icon: Icons.repeat_rounded,
            label: _rule.type == RepeatType.customInterval
                ? '每 ${_rule.intervalDays} 天'
                : (_rule.type == RepeatType.weekly && _rule.days.isNotEmpty)
                    ? '每周 ${_rule.days.map((d) => _dayName[d]).join('、')}'
                    : _rule.type.label,
            onTap: _chooseRepeatRule,
          ),
          const SizedBox(height: 22),
          _sectionTitle(context, '优先级'),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('低')),
              ButtonSegment(value: 2, label: Text('中')),
              ButtonSegment(value: 3, label: Text('高')),
            ],
            selected: {_priority},
            onSelectionChanged: (selection) =>
                setState(() => _priority = selection.first),
          ),
          const SizedBox(height: 22),
          SwitchListTile(
            value: _syncCalendar,
            onChanged: (value) => setState(() => _syncCalendar = value),
            title: const Text('同步到系统日历提醒'),
            subtitle: const Text('由系统日历负责通知，可在设置中更换目标日历'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
            label: Text(_isEditing ? '保存修改' : '创建待办'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ],
      ),
    );
  }

  static const _dayName = {1: '一', 2: '二', 3: '三', 4: '四', 5: '五', 6: '六', 7: '日'};

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }

  Widget _selectorTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
