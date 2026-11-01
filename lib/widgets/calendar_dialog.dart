// 选择系统日历：跳转全屏选择页（含诊断信息与自动兜底），返回日历 ID。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/todo_provider.dart';
import '../screens/calendar_picker_screen.dart';

/// 选择系统日历，返回日历 ID；用户取消时返回 null。
/// 实际选择逻辑在 [CalendarPickerScreen] 页面内完成。
Future<String?> pickCalendar(BuildContext context) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) => const CalendarPickerScreen(),
    ),
  );
}

/// 确保日历权限与目标日历已就绪（供快捷录入等入口使用）。
/// 返回 true 表示可以写入系统日历；false 表示未就绪（权限被拒 / 未选日历）。
/// 日历未选择时弹出选择页，用户取消则回退系统默认日历。
Future<bool> ensureCalendarReady(BuildContext context, WidgetRef ref) async {
  final calendarService = ref.read(calendarServiceProvider);
  var granted = await calendarService.hasPermissions();
  if (!granted) granted = await calendarService.requestPermissions();
  if (!granted) return false;

  if (ref.read(settingsProvider).calendarId != null) return true;
  if (!context.mounted) return false;
  var id = await pickCalendar(context);
  // 用户取消选择时兜底系统默认日历，避免"选不上"
  id ??= (await calendarService.defaultCalendar())?.id;
  if (id == null) return false;
  await ref.read(settingsProvider.notifier).setCalendarId(id);
  return true;
}
