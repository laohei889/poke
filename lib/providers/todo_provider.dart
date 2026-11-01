// 待办状态管理：TodoController 承载创建 / 完成 / 接受 / 抽签 / 导入等
// 全部状态流转，并管理与系统日历的同步。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/todo_item.dart';
import '../services/calendar_service.dart';
import '../services/db_service.dart';
import '../services/task_picker.dart';
import '../utils/constants.dart';
import '../utils/date_utils.dart';

/// ---------- 基础服务 ----------
final dbServiceProvider = Provider<DbService>((ref) => DbService());

final calendarServiceProvider = Provider<CalendarService>((ref) => CalendarService());

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('main() 中覆盖为已初始化实例'),
);

/// ---------- 应用设置 ----------
class AppSettings {
  const AppSettings({
    this.backgroundShakeEnabled = false,
    this.calendarSyncEnabled = false,
    this.calendarId,
  });

  final bool backgroundShakeEnabled;
  final bool calendarSyncEnabled;
  final String? calendarId;

  AppSettings copyWith({
    bool? backgroundShakeEnabled,
    bool? calendarSyncEnabled,
    String? calendarId,
    bool clearCalendarId = false,
  }) {
    return AppSettings(
      backgroundShakeEnabled: backgroundShakeEnabled ?? this.backgroundShakeEnabled,
      calendarSyncEnabled: calendarSyncEnabled ?? this.calendarSyncEnabled,
      calendarId: clearCalendarId ? null : (calendarId ?? this.calendarId),
    );
  }
}

class SettingsController extends StateNotifier<AppSettings> {
  SettingsController(this._prefs) : super(const AppSettings()) {
    _load();
  }

  final SharedPreferences _prefs;

  void _load() {
    state = AppSettings(
      backgroundShakeEnabled: _prefs.getBool(prefKeyBackgroundShake) ?? false,
      calendarSyncEnabled: _prefs.getBool(prefKeyCalendarSync) ?? false,
      calendarId: _prefs.getString(prefKeyCalendarId),
    );
  }

  Future<void> setBackgroundShake(bool value) async {
    await _prefs.setBool(prefKeyBackgroundShake, value);
    state = state.copyWith(backgroundShakeEnabled: value);
  }

  Future<void> setCalendarSync(bool value) async {
    await _prefs.setBool(prefKeyCalendarSync, value);
    state = state.copyWith(calendarSyncEnabled: value);
  }

  Future<void> setCalendarId(String? id) async {
    if (id == null) {
      await _prefs.remove(prefKeyCalendarId);
      state = state.copyWith(clearCalendarId: true);
    } else {
      await _prefs.setString(prefKeyCalendarId, id);
      state = state.copyWith(calendarId: id);
    }
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsController, AppSettings>((ref) {
  return SettingsController(ref.watch(sharedPreferencesProvider));
});

/// ---------- 待办状态 ----------
class TodoState {
  const TodoState({this.todos = const [], this.loading = true});

  final List<TodoItem> todos;
  final bool loading;

  List<TodoItem> byStatus(TodoStatus status) =>
      todos.where((t) => t.status == status).toList();

  List<TodoItem> get pending => byStatus(TodoStatus.pending);
  List<TodoItem> get inProgress => byStatus(TodoStatus.inProgress);
  List<TodoItem> get done =>
      todos
          .where((t) =>
              t.status == TodoStatus.completed || t.status == TodoStatus.archived)
          .toList();

  /// 今日视图：今天到期或已逾期
  List<TodoItem> get today => todos
      .where((t) => t.status == TodoStatus.pending && (t.isDueToday || t.isOverdue))
      .toList();

  TodoState copyWith({List<TodoItem>? todos, bool? loading}) => TodoState(
        todos: todos ?? this.todos,
        loading: loading ?? this.loading,
      );
}

class TodoController extends StateNotifier<TodoState> {
  TodoController(this._db, this._calendar, this._settingsRef)
      : super(const TodoState()) {
    load();
  }

  final DbService _db;
  final CalendarService _calendar;
  final Ref _settingsRef;

  AppSettings get _settings => _settingsRef.read(settingsProvider);

  Future<void> load() async {
    final todos = await _db.query();
    state = TodoState(todos: todos, loading: false);
  }

  /// 创建待办
  ///
  /// 单次：`dueDate` 有值则记录到期时间；
  /// 重复：写入 `nextDueDate`，完成后复用同一条记录回到 pending。
  ///
  /// [syncCalendar]：true 强制写入系统日历，false 强制不写入，
  /// null 跟随全局设置（快捷录入等无逐条开关的入口使用）。
  Future<TodoItem> create({
    required String title,
    String? description,
    DateTime? dueDate,
    RepeatType repeatType = RepeatType.none,
    List<int> repeatDays = const [],
    int intervalDays = 1,
    int priority = 2,
    bool? syncCalendar,
  }) async {
    final now = DateTime.now();
    final firstDue = dueDate ?? DateTime(now.year, now.month, now.day, 9, 0);

    final todo = TodoItem(
      id: const Uuid().v4(),
      title: title.trim(),
      description: (description == null || description.trim().isEmpty)
          ? null
          : description.trim(),
      dueDate: firstDue,
      repeatType: repeatType,
      repeatDays: repeatDays,
      intervalDays: intervalDays,
      nextDueDate: repeatType == RepeatType.none ? null : firstDue,
      status: TodoStatus.pending,
      priority: priority,
      createdAt: now,
      updatedAt: now,
    );

    await _db.insert(todo);
    // 新记录无事件 ID，wantsEvent 传 null 时按全局设置推断
    await syncCalendarEvent(todo, wantsEvent: syncCalendar);
    await load();
    return (await _db.getById(todo.id)) ?? todo;
  }

  /// 更新待办（保持日历同步）
  ///
  /// [syncCalendar] 语义同 [create]；false 时会删除已有的日历事件，
  /// null 时按「已有事件或全局同步开启」推断。
  Future<void> save(TodoItem todo, {bool? syncCalendar}) async {
    final updated = todo.copyWith(updatedAt: DateTime.now());
    await _db.update(updated);
    await syncCalendarEvent(updated, wantsEvent: syncCalendar);
    await load();
  }

  /// 删除待办（同时删除日历事件）
  Future<void> remove(TodoItem todo) async {
    await _deleteCalendarEvent(todo);
    await _db.delete(todo.id);
    await load();
  }

  /// 完成：单次归档；重复事项自动排期回 pending。
  /// 已是完成/归档状态的事项直接忽略，避免重复触发把重复事项"复活"排期。
  Future<void> complete(TodoItem todo) async {
    if (todo.status == TodoStatus.completed ||
        todo.status == TodoStatus.archived) {
      return;
    }
    final updated = applyCompletion(todo, DateTime.now());
    await _db.update(updated);
    await syncCalendarEvent(updated);
    await load();
  }

  /// 摇一摇接受任务
  Future<void> accept(TodoItem todo) async {
    final updated = todo.copyWith(
      status: TodoStatus.inProgress,
      acceptedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _db.update(updated);
    await load();
  }

  /// 未完成，放回抽取池
  Future<void> returnToPool(TodoItem todo) async {
    final updated = todo.copyWith(
      status: TodoStatus.pending,
      clearAcceptedAt: true,
      updatedAt: DateTime.now(),
    );
    await _db.update(updated);
    await load();
  }

  /// 摇一摇抽取：pending 池中按权重随机。
  /// 与后台服务共用 [pickWeightedRandom]（含"只剩一条时回退全池"）。
  TodoItem? drawRandom({TodoItem? exclude}) =>
      pickWeightedRandom(state.pending, exclude: exclude);

  /// 批量导入
  Future<List<TodoItem>> importItems(List<TodoItem> items) async {
    for (final item in items) {
      await _db.insert(item);
    }
    await load();
    return items;
  }

  // ---------- 日历同步 ----------
  /// 同步该待办的系统日历事件：删除旧事件后按需重建（排期后换新事件）。
  ///
  /// [wantsEvent] 显式指定该待办是否应有日历事件；null 表示按
  /// 「已有事件或全局同步开启」推断（Web 控制台等无逐条开关的入口使用）。
  /// 重建失败或不再需要时会清掉库里的事件 ID，避免残留指向已删除事件。
  /// 不负责刷新列表，由调用方在写入完成后统一 [load]。
  ///
  /// 返回失败原因（同步了但没写进去时非 null），供 UI 明确提示，
  /// 避免"静默丢失提醒"；结果同时记录在 [lastCalendarError]。
  Future<String?> syncCalendarEvent(TodoItem todo, {bool? wantsEvent}) async {
    final want = wantsEvent ??
        (todo.calendarEventId != null || _settings.calendarSyncEnabled);
    final oldId = todo.calendarEventId;
    if (oldId != null) await _deleteCalendarEvent(todo);

    String? newId;
    final active = todo.status == TodoStatus.pending ||
        todo.status == TodoStatus.inProgress;
    if (want && active) {
      newId = await _createCalendarEvent(todo);
      // 事件写入成功但提醒未生效时也返回原因（提醒兕底失败），供 UI 告警
      _lastCalendarError = newId == null
          ? (_calendar.lastError ?? '写入系统日历失败，请检查日历权限与默认日历设置')
          : _calendar.lastError;
    } else {
      // 本次未请求同步：清掉旧错误，避免上一次的失败提示被重复展示
      _lastCalendarError = null;
    }
    if (newId != oldId) {
      await _db.update(todo.copyWith(
        clearCalendarEventId: newId == null,
        calendarEventId: newId,
      ));
    }
    return _lastCalendarError;
  }

  /// 最近一次日历同步的失败原因（成功/未请求同步时为 null）
  String? get lastCalendarError => _lastCalendarError;
  String? _lastCalendarError;

  Future<String?> _createCalendarEvent(TodoItem todo) async {
    final calendarId = _settings.calendarId;
    if (calendarId == null) {
      _calendar.lastError = '尚未选择用于提醒的日历';
      return null;
    }
    if (!await _calendar.hasPermissions()) {
      _calendar.lastError = '未授予日历权限';
      return null;
    }
    return _calendar.createEventForTodo(todo, calendarId: calendarId);
  }

  Future<void> _deleteCalendarEvent(TodoItem todo) async {
    final eventId = todo.calendarEventId;
    final calendarId = _settings.calendarId;
    if (eventId == null || calendarId == null) return;
    await _calendar.deleteEvent(calendarId, eventId);
  }
}

final todoProvider = StateNotifierProvider<TodoController, TodoState>((ref) {
  return TodoController(
    ref.watch(dbServiceProvider),
    ref.watch(calendarServiceProvider),
    ref,
  );
});
