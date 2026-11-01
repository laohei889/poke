// 设置页：后台摇一摇开关、系统日历同步、PC 控制台入口、关于。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/todo_provider.dart';
import '../services/foreground_shake_service.dart';
import '../widgets/calendar_dialog.dart';
import 'web_console_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _calendarName;

  @override
  void initState() {
    super.initState();
    _loadCalendarName();
  }

  Future<void> _loadCalendarName() async {
    final id = ref.read(settingsProvider).calendarId;
    if (id == null) return;
    // 包含只读日历，避免选中的日历被过滤后显示成“未选择”
    final calendars = await ref
        .read(calendarServiceProvider)
        .retrieveCalendars(includeReadOnly: true);
    if (!mounted) return;
    setState(() {
      _calendarName = calendars
          .where((c) => c.id == id)
          .map((c) => c.name ?? id)
          .firstOrNull;
    });
  }

  Future<void> _toggleBackgroundShake(bool enable) async {
    final settings = ref.read(settingsProvider.notifier);
    if (enable) {
      await ForegroundShakeService.requestPermissions();
      await ForegroundShakeService.init();
      await ForegroundShakeService.start();
      await settings.setBackgroundShake(true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('后台摇一摇已开启，锁屏摇动也会抽取任务')),
        );
      }
    } else {
      await ForegroundShakeService.stop();
      await settings.setBackgroundShake(false);
    }
    setState(() {});
  }

  Future<void> _toggleCalendarSync(bool enable) async {
    final notifier = ref.read(settingsProvider.notifier);
    await notifier.setCalendarSync(enable);

    if (enable) {
      final calendarService = ref.read(calendarServiceProvider);
      var granted = await calendarService.hasPermissions();
      if (!granted) granted = await calendarService.requestPermissions();
      if (!granted) {
        await notifier.setCalendarSync(false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未授予日历权限，无法开启同步')),
          );
        }
        return;
      }

      if (ref.read(settingsProvider).calendarId == null) {
        if (!mounted) return;
        var id = await pickCalendar(context);
        // 用户取消选择时自动兜底系统默认日历，避免"选不上"
        if (id == null) {
          final fallback = await calendarService.defaultCalendar();
          id = fallback?.id;
          if (id != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('已自动使用默认日历：${fallback!.name ?? id}')),
            );
          }
        }
        if (id != null) {
          await notifier.setCalendarId(id);
          await _loadCalendarName();
        }
      }
    }
    setState(() {});
  }

  Future<void> _chooseCalendar() async {
    final calendarService = ref.read(calendarServiceProvider);
    var granted = await calendarService.hasPermissions();
    if (!granted) granted = await calendarService.requestPermissions();
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未授予日历权限')),
        );
      }
      return;
    }

    if (!mounted) return;
    final id = await pickCalendar(context);
    if (id == null) return;
    await ref.read(settingsProvider.notifier).setCalendarId(id);
    await _loadCalendarName();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _sectionHeader(theme, '摇一摇'),
          SwitchListTile(
            value: settings.backgroundShakeEnabled,
            onChanged: _toggleBackgroundShake,
            title: const Text('后台 / 锁屏摇一摇'),
            subtitle: const Text(
              '开启后 App 以常驻通知保持运行，锁屏摇动手机也能抽任务。\n会增加一定耗电，不需要时请关闭（默认关闭）。',
            ),
          ),
          const Divider(height: 1),
          _sectionHeader(theme, '日历提醒'),
          SwitchListTile(
            value: settings.calendarSyncEnabled,
            onChanged: _toggleCalendarSync,
            title: const Text('同步到系统日历'),
            subtitle: const Text('创建待办时写入系统日历事件，由系统负责提醒'),
          ),
          ListTile(
            leading: const Icon(Icons.event_available_rounded),
            title: const Text('默认日历'),
            subtitle: Text(_calendarName ?? '未选择'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _chooseCalendar,
          ),
          const Divider(height: 1),
          _sectionHeader(theme, 'PC 控制台'),
          ListTile(
            leading: const Icon(Icons.desktop_windows_outlined),
            title: const Text('局域网 Web 控制台'),
            subtitle: const Text('管理访问密码、查看地址与二维码'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WebConsoleScreen()),
            ),
          ),
          const Divider(height: 1),
          _sectionHeader(theme, '关于'),
          const ListTile(
            leading: Icon(Icons.storage_rounded),
            title: Text('数据存储'),
            subtitle: Text('所有待办数据保存在手机本地 SQLite，无需联网；卸载 App 前请用 Web 控制台导出备份。'),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline_rounded),
            title: Text('手欠'),
            subtitle: Text('没事就手欠，手欠就有事 · 本地待办 · 摇一摇抽任务'),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}
