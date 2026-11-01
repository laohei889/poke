// 系统日历提醒服务：把待办写入系统日历事件，由系统负责通知。
// 日历事件 ID 存库以便反向删除；查询失败时返回错误详情，便于 UI 明确提示而非静默失败。
import 'dart:convert';

import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/services.dart' show MethodChannel, PlatformException;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/todo_item.dart';

/// 日历列表查询结果：带错误信息，便于选择页展示诊断
class CalendarLoadResult {
  const CalendarLoadResult({required this.calendars, this.error});

  final List<Calendar> calendars;
  final String? error;
}

class CalendarService {
  CalendarService();

  final DeviceCalendarPlugin _plugin = DeviceCalendarPlugin();
  bool _tzReady = false;

  /// 最近一次写入日历的错误信息（供 UI 提示）
  String? lastError;

  Future<void> _ensureTz() async {
    if (_tzReady) return;
    tzdata.initializeTimeZones();
    _tzReady = true;
  }

  /// 是否已授予日历读写权限
  Future<bool> hasPermissions() async {
    final result = await _plugin.hasPermissions();
    return result.isSuccess && (result.data ?? false);
  }

  /// 请求日历读写权限
  Future<bool> requestPermissions() async {
    final result = await _plugin.requestPermissions();
    return result.isSuccess && (result.data ?? false);
  }

  /// 加载日历列表（含错误详情）；[includeReadOnly] 为 true 时包含只读日历。
  ///
  /// 已知坑：R8/ProGuard 混淆会破坏插件的 Gson 反序列化，
  /// retrieveCalendars() 返回的日历 id/name 全为 null（无法选择日历）。
  /// 检测到该症状时改走原始通道自救（[_loadCalendarsRaw]）。
  Future<CalendarLoadResult> loadCalendars({
    bool includeReadOnly = true,
  }) async {
    try {
      final result = await _plugin.retrieveCalendars();
      if (result.isSuccess) {
        final data = result.data;
        var all = data == null ? <Calendar>[] : data.toList();
        String? warning;
        if (all.isNotEmpty && all.every((c) => c.id == null)) {
          final rescued = await _loadCalendarsRaw();
          if (rescued != null && rescued.isNotEmpty) {
            all = rescued;
          } else {
            warning =
                '插件返回的日历缺少 ID（打包时 R8 混淆破坏了插件序列化的典型症状），'
                '请在 android/app/proguard-rules.pro 中保留 com.builttoroam.devicecalendar.** 后重新打包';
          }
        }
        return CalendarLoadResult(
          calendars: _filter(all, includeReadOnly),
          error: warning,
        );
      }
      final msg = result.errors.map((e) => e.errorMessage).join('；');
      // 插件解析失败时也尝试原始通道自救
      final rescued = await _loadCalendarsRaw();
      if (rescued != null && rescued.isNotEmpty) {
        return CalendarLoadResult(
            calendars: _filter(rescued, includeReadOnly));
      }
      return CalendarLoadResult(
        calendars: const [],
        error: msg.isEmpty ? '读取日历列表失败，请重试' : msg,
      );
    } catch (e) {
      // 插件内部解析抛异常（如混淆后字段类型错乱）时同样自救
      final rescued = await _loadCalendarsRaw();
      if (rescued != null && rescued.isNotEmpty) {
        return CalendarLoadResult(
            calendars: _filter(rescued, includeReadOnly));
      }
      return CalendarLoadResult(calendars: const [], error: '$e');
    }
  }

  List<Calendar> _filter(List<Calendar> all, bool includeReadOnly) =>
      includeReadOnly ? all : all.where((c) => c.isReadOnly != true).toList();

  static const _rawChannel =
      MethodChannel('plugins.builttoroam.com/device_calendar');

  /// 兔底：直接调用插件的 retrieveCalendars 并自行解析 JSON。
  ///
  /// 绕过插件的 Calendar.fromJson：R8 混淆后 JSON 键名被改，
  /// 键名缺失时按 Gson 字段声明顺序恢复。
  Future<List<Calendar>?> _loadCalendarsRaw() async {
    try {
      final raw = await _rawChannel.invokeMethod<String>('retrieveCalendars');
      if (raw == null) return null;
      final decoded = json.decode(raw);
      if (decoded is! List) return null;
      final out = <Calendar>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final cal = _calendarFromMap(Map<String, dynamic>.from(item));
        if (cal != null) out.add(cal);
      }
      return out.isEmpty ? null : out;
    } catch (_) {
      return null;
    }
  }

  /// 解析单个日历 JSON：优先标准键名；键名被混淆时按 Gson 字段声明顺序恢复
  /// （id, name, color, accountName, accountType, ownerAccount, isReadOnly, isDefault）。
  Calendar? _calendarFromMap(Map<String, dynamic> map) {
    String? id = map['id']?.toString();
    String? name = map['name']?.toString();
    int? color = (map['color'] as num?)?.toInt();
    String? accountName = map['accountName']?.toString();
    String? accountType = map['accountType']?.toString();
    bool? isReadOnly = map['isReadOnly'] as bool?;
    bool? isDefault = map['isDefault'] as bool?;

    if (id == null) {
      final v = map.values.toList();
      if (v.length < 6) return null;
      id = v[0]?.toString();
      name = v[1]?.toString();
      color = int.tryParse('${v[2]}');
      accountName = v[3]?.toString();
      accountType = v[4]?.toString();
      // v[5] = ownerAccount，插件 Dart 模型不接收，跳过
      if (v.length > 6) isReadOnly = '${v[6]}' == 'true';
      if (v.length > 7) isDefault = '${v[7]}' == 'true';
    }
    if (id == null || id.isEmpty) return null;
    return Calendar(
      id: id,
      name: name,
      isReadOnly: isReadOnly,
      isDefault: isDefault,
      color: color,
      accountName: accountName,
      accountType: accountType,
    );
  }

  /// 日历列表（只返回可写日历）；查询失败时返回空列表
  Future<List<Calendar>> retrieveCalendars({bool includeReadOnly = false}) async {
    final r = await loadCalendars(includeReadOnly: includeReadOnly);
    return r.calendars;
  }

  /// 默认日历：优先系统默认且可写，其次可写，再次系统默认，最后任取一个。
  /// 不再因只读标记过滤——部分国产 ROM 会错报 accessLevel，
  /// 只读标记仅供参考，实际可写性以写入验证为准。
  Future<Calendar?> defaultCalendar() async {
    final r = await loadCalendars(includeReadOnly: true);
    if (r.calendars.isEmpty) return null;
    for (final c in r.calendars) {
      if (c.isDefault == true && c.isReadOnly != true) return c;
    }
    for (final c in r.calendars) {
      if (c.isReadOnly != true) return c;
    }
    for (final c in r.calendars) {
      if (c.isDefault == true) return c;
    }
    return r.calendars.first;
  }

  /// 写入验证：插入一条测试事件并立即删除。
  /// 返回 null 表示可写；否则返回真实错误信息（供 UI 展示）。
  /// 部分 ROM 会把本机日历错报为只读，标记不可信，实测才为准。
  Future<String?> verifyWritable(String calendarId) async {
    await _ensureTz();
    try {
      final now = tz.TZDateTime.from(DateTime.now(), tz.local);
      // 放在过去时间，避免测试事件被当成待办打扰用户
      final event = Event(
        calendarId,
        title: '手欠 日历写入测试（自动删除）',
        start: now.subtract(const Duration(hours: 1)),
        end: now.subtract(const Duration(minutes: 30)),
      );
      final result = await _plugin.createOrUpdateEvent(event);
      if (result == null || !result.isSuccess || result.data == null) {
        return result == null
            ? '创建测试事件失败'
            : (result.errors.isNotEmpty
                ? result.errors.first.errorMessage
                : '创建测试事件失败');
      }
      await _plugin.deleteEvent(calendarId, result.data!);
      lastError = null;
      return null;
    } catch (e) {
      return '$e';
    }
  }

  /// 为待办创建日历事件，返回事件 ID；失败时把原因写入 [lastError]
  Future<String?> createEventForTodo(
    TodoItem todo, {
    required String calendarId,
    Duration remindBefore = const Duration(minutes: 15),
  }) async {
    final due = todo.effectiveDue;
    if (due == null) {
      lastError = '待办没有截止时间，无法写入日历';
      return null;
    }
    await _ensureTz();

    final event = Event(
      calendarId,
      title: todo.title,
      description: todo.description,
      start: tz.TZDateTime.from(due, tz.local),
      end: tz.TZDateTime.from(due.add(const Duration(minutes: 30)), tz.local),
      reminders: [Reminder(minutes: remindBefore.inMinutes)],
    );

    final result = await _plugin.createOrUpdateEvent(event);
    if (result == null || !result.isSuccess) {
      lastError = result == null
          ? '创建日历事件失败'
          : (result.errors.isNotEmpty
              ? result.errors.first.errorMessage
              : '创建日历事件失败');
      return null;
    }
    // 部分 ROM 的日历提供程序会静默丢弃插件写入的提醒行：
    // 走原生通道重建提醒并回查校验；事件已写入时失败原因另行提示
    final eventId = result.data!;
    final reminderErr = await _ensureNativeReminder(
      eventId,
      minutes: remindBefore.inMinutes,
    );
    lastError =
        reminderErr == null ? null : '事件已写入，但提醒未生效：$reminderErr';
    return eventId;
  }

  /// 原生提醒兕底通道：删除旧提醒行后按 METHOD_ALERT → METHOD_DEFAULT
  /// 重写并回查校验；返回 null 表示成功，否则为失败原因
  static const MethodChannel _reminderChannel =
      MethodChannel('poke/calendar_reminder');

  Future<String?> _ensureNativeReminder(
    String eventId, {
    int minutes = 15,
  }) async {
    final id = int.tryParse(eventId);
    if (id == null) return '事件 ID 无法解析：$eventId';
    try {
      final resp = await _reminderChannel.invokeMapMethod<String, dynamic>(
        'ensureReminder',
        {'eventId': id, 'minutes': minutes},
      );
      if (resp == null) return '提醒设置无响应';
      if (resp['ok'] == true) return null;
      return resp['error']?.toString() ?? '提醒写入失败';
    } on PlatformException catch (e) {
      return e.message ?? e.code;
    } catch (e) {
      return '$e';
    }
  }

  /// 删除日历事件
  Future<void> deleteEvent(String calendarId, String eventId) async {
    await _plugin.deleteEvent(calendarId, eventId);
  }
}
