// 日历选择页：全屏列表 + 诊断信息（权限、数量、错误详情）。
// 关键设计：只读标记仅供参考（部分国产 ROM 会错报），所有日历均可点选，
// 选中时做真实"写入验证"（插入并立即删除测试事件），实测可写才算选上。
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/todo_provider.dart';

class CalendarPickerScreen extends ConsumerStatefulWidget {
  const CalendarPickerScreen({super.key, this.initialId});

  final String? initialId;

  @override
  ConsumerState<CalendarPickerScreen> createState() =>
      _CalendarPickerScreenState();
}

class _CalendarPickerScreenState extends ConsumerState<CalendarPickerScreen> {
  List<Calendar> _calendars = [];
  String? _error;
  bool _loading = true;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final service = ref.read(calendarServiceProvider);
    var granted = await service.hasPermissions();
    if (!granted) granted = await service.requestPermissions();
    if (!mounted) return;

    if (!granted) {
      setState(() {
        _loading = false;
        _error = '未授予日历权限：请到系统设置 → 应用 → 手欠 → 权限中允许「日历」';
      });
      return;
    }

    final result = await service.loadCalendars(includeReadOnly: true);
    if (!mounted) return;

    final sorted = [...result.calendars]
      ..sort((a, b) {
        // 系统默认优先，其次非只读（仅排序参考，不影响可点性）
        int rank(Calendar c) =>
            (c.isDefault == true ? 0 : 2) + (c.isReadOnly == true ? 1 : 0);
        return rank(a).compareTo(rank(b));
      });

    setState(() {
      _loading = false;
      _calendars = sorted;
      _error = result.error;
    });
  }

  /// 选中日历：先做写入验证，实测可写才返回
  Future<void> _selectCalendar(Calendar calendar) async {
    final id = calendar.id;
    if (id == null || _verifying) return;

    setState(() => _verifying = true);
    final verifyError =
        await ref.read(calendarServiceProvider).verifyWritable(id);
    if (!mounted) return;
    setState(() => _verifying = false);

    if (verifyError == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已选择日历：${calendar.name ?? id}（写入验证通过）'),
        ),
      );
      Navigator.pop(context, id);
      return;
    }

    // 写入失败：展示真实原因，询问是否仍然使用
    final stillUse = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('无法写入「${calendar.name ?? '该日历'}」'),
        content: Text(
          '写入验证失败：$verifyError\n\n'
          '可能是该日历确实只读，或账户未完成同步。\n'
          '仍要选择它吗？（后续同步日历事件可能失败）',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('换一个'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('仍然使用'),
          ),
        ],
      ),
    );
    if (stillUse == true && mounted) {
      Navigator.pop(context, id);
    }
  }

  Future<void> _pickDefault() async {
    final service = ref.read(calendarServiceProvider);
    final fallback = await service.defaultCalendar();
    if (!mounted) return;
    if (fallback == null || fallback.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未找到系统日历，请确认手机上已登录日历账户')),
      );
      return;
    }
    await _selectCalendar(fallback);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择用于提醒的日历'),
        actions: [
          IconButton(
            tooltip: '重新加载',
            onPressed: _verifying ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_calendars.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy_rounded,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? '未找到系统日历',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '提示：请确认已授予日历权限，且手机上已登录日历账户\n'
              '（如小米云日历 / Google 账户等）',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重新加载'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_error != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            '点击日历即进行写入验证并选用。标注「可能只读」的仅供参考'
            '（部分机型会误报），以实际验证结果为准。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _calendars.length,
            itemBuilder: (context, index) {
              final calendar = _calendars[index];
              final readOnly = calendar.isReadOnly == true;
              // 仅在确实传入了 initialId 且匹配时显示勾选，
              // 避免 id 缺失的行因 null == null 被误标为已选
              final selected =
                  widget.initialId != null && calendar.id == widget.initialId;

              return ListTile(
                leading: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(calendar.color ?? 0xFF3DDC97),
                  ),
                ),
                title: Text(
                  '${calendar.name ?? '未命名日历'}'
                  '${calendar.isDefault == true ? '（默认）' : ''}',
                ),
                subtitle: Text(
                  [
                    if (calendar.accountName != null &&
                        calendar.accountName!.isNotEmpty)
                      calendar.accountName!,
                    if (readOnly) '可能只读（可点击验证）',
                  ].join(' · '),
                ),
                trailing: _verifying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : selected
                        ? Icon(Icons.check_circle_rounded,
                            color: Theme.of(context).colorScheme.primary)
                        : const Icon(Icons.chevron_right_rounded),
                enabled: !_verifying && calendar.id != null,
                onTap: (_verifying || calendar.id == null)
                    ? null
                    : () => _selectCalendar(calendar),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: _verifying ? null : _pickDefault,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('自动使用系统默认日历'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
