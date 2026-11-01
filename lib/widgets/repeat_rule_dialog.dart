// 重复规则选择弹窗：每天 / 工作日 / 每周几 / 每月 / 每隔 N 天。
import 'package:flutter/material.dart';

import '../models/todo_item.dart';

/// 重复规则选择结果
class RepeatRule {
  const RepeatRule({
    this.type = RepeatType.none,
    this.days = const [],
    this.intervalDays = 1,
  });

  final RepeatType type;
  final List<int> days;
  final int intervalDays;
}

/// 弹出重复规则选择（每天 / 工作日 / 每周几 / 每月 / 每隔 N 天）
Future<RepeatRule?> showRepeatRuleDialog(
  BuildContext context, {
  RepeatRule? initial,
}) {
  return showDialog<RepeatRule>(
    context: context,
    builder: (context) => _RepeatRuleDialog(initial: initial ?? const RepeatRule()),
  );
}

class _RepeatRuleDialog extends StatefulWidget {
  const _RepeatRuleDialog({required this.initial});

  final RepeatRule initial;

  @override
  State<_RepeatRuleDialog> createState() => _RepeatRuleDialogState();
}

class _RepeatRuleDialogState extends State<_RepeatRuleDialog> {
  late RepeatType _type = widget.initial.type;
  final List<int> _days = [];
  late int _interval = widget.initial.intervalDays;
  final _intervalController = TextEditingController();

  static const _dayNames = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  void initState() {
    super.initState();
    _days.addAll(widget.initial.days);
    _intervalController.text = '$_interval';
  }

  @override
  void dispose() {
    _intervalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('重复规则'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final type in const [
            RepeatType.none,
            RepeatType.daily,
            RepeatType.workday,
            RepeatType.weekly,
            RepeatType.monthly,
            RepeatType.yearly,
            RepeatType.customInterval,
          ])
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _type = type),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                child: Row(
                  children: [
                    Icon(
                      _type == type
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: _type == type
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(width: 12),
                    Text(type.label),
                  ],
                ),
              ),
            ),
          if (_type == RepeatType.weekly) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: [
                for (var i = 1; i <= 7; i++)
                  FilterChip(
                    label: Text('周${_dayNames[i - 1]}'),
                    selected: _days.contains(i),
                    onSelected: (selected) => setState(() {
                      selected ? _days.add(i) : _days.remove(i);
                      _days.sort();
                    }),
                  ),
              ],
            ),
          ],
          if (_type == RepeatType.customInterval) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _intervalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '每隔几天',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => _interval = int.tryParse(value) ?? 1,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            RepeatRule(
              type: _type,
              days: List.of(_days),
              intervalDays: _interval < 1 ? 1 : _interval,
            ),
          ),
          child: const Text('确定'),
        ),
      ],
    );
  }
}
