// 局域网 Web 控制台服务的 Riverpod 单例：
// 组装 DbService / PcAuth，并把数据变化回调给 App 列表刷新。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/pc_auth.dart';
import '../services/web_server_service.dart';
import 'todo_provider.dart';

/// 局域网 Web 控制台服务（懒加载单例）
final webServerServiceProvider = Provider<WebServerService>((ref) {
  final service = WebServerService(
    dbService: ref.watch(dbServiceProvider),
    auth: PcAuth(ref.watch(sharedPreferencesProvider)),
    onDataChanged: () => ref.read(todoProvider.notifier).load(),
    // 与 App 端共用同一套日历同步逻辑（创建/更新/完成后重建事件）
    onSyncCalendar: (todo) =>
        ref.read(todoProvider.notifier).syncCalendarEvent(todo),
    onDelete: (todo) async {
      final settings = ref.read(settingsProvider);
      final eventId = todo.calendarEventId;
      final calendarId = settings.calendarId;
      if (eventId != null && calendarId != null) {
        await ref.read(calendarServiceProvider).deleteEvent(calendarId, eventId);
      }
    },
  );
  ref.onDispose(service.stop);
  return service;
});
