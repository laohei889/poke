import 'dart:convert';

/// 重复类型
enum RepeatType {
  none, // 单次
  daily, // 每天
  workday, // 工作日
  weekly, // 每周（可指定周几）
  monthly, // 每月
  yearly, // 每年（生日、纪念日）
  customInterval, // 自定义间隔（每隔 N 天）
}

/// 事项状态
enum TodoStatus {
  pending, // 待执行（摇一摇抽取池）
  inProgress, // 执行中（用户已接受）
  completed, // 已完成（保留展示）
  archived, // 已归档（单次事项完成后的最终态）
}

extension RepeatTypeX on RepeatType {
  String get label {
    switch (this) {
      case RepeatType.none:
        return '不重复';
      case RepeatType.daily:
        return '每天';
      case RepeatType.workday:
        return '工作日';
      case RepeatType.weekly:
        return '每周';
      case RepeatType.monthly:
        return '每月';
      case RepeatType.yearly:
        return '每年';
      case RepeatType.customInterval:
        return '自定义间隔';
    }
  }

  String get storageName => name;

  static RepeatType fromName(String? name) => RepeatType.values.firstWhere(
        (e) => e.name == name,
        orElse: () => RepeatType.none,
      );
}

extension TodoStatusX on TodoStatus {
  String get label {
    switch (this) {
      case TodoStatus.pending:
        return '待执行';
      case TodoStatus.inProgress:
        return '执行中';
      case TodoStatus.completed:
        return '已完成';
      case TodoStatus.archived:
        return '已归档';
    }
  }
}

/// 待办事项数据模型
class TodoItem {
  final String id; // UUID
  final String title;
  final String? description;
  final DateTime? dueDate; // 单次/本次到期时间
  final RepeatType repeatType;
  final List<int> repeatDays; // 每周几（1=周一 ... 7=周日）
  final int intervalDays; // 自定义间隔天数
  final DateTime? lastDoneAt; // 上次完成时间
  final DateTime? nextDueDate; // 下次到期时间（重复事项核心）
  final TodoStatus status;
  final int priority; // 1低 2中 3高
  final String? calendarEventId; // 系统日历事件 ID
  final DateTime? acceptedAt; // 摇一摇接受时间
  final DateTime createdAt;
  final DateTime updatedAt;

  const TodoItem({
    required this.id,
    required this.title,
    this.description,
    this.dueDate,
    this.repeatType = RepeatType.none,
    this.repeatDays = const [],
    this.intervalDays = 1,
    this.lastDoneAt,
    this.nextDueDate,
    this.status = TodoStatus.pending,
    this.priority = 2,
    this.calendarEventId,
    this.acceptedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isRepeating => repeatType != RepeatType.none;

  /// 当前生效的到期时间：重复事项看 nextDueDate，单次看 dueDate
  DateTime? get effectiveDue => isRepeating ? (nextDueDate ?? dueDate) : dueDate;

  /// 是否已逾期
  bool get isOverdue {
    final due = effectiveDue;
    return status == TodoStatus.pending &&
        due != null &&
        due.isBefore(DateTime.now());
  }

  /// 是否今天到期
  bool get isDueToday {
    final due = effectiveDue;
    if (due == null) return false;
    final now = DateTime.now();
    return due.year == now.year && due.month == now.month && due.day == now.day;
  }

  TodoItem copyWith({
    String? title,
    String? description,
    bool clearDescription = false,
    DateTime? dueDate,
    bool clearDueDate = false,
    RepeatType? repeatType,
    List<int>? repeatDays,
    int? intervalDays,
    DateTime? lastDoneAt,
    DateTime? nextDueDate,
    bool clearNextDueDate = false,
    TodoStatus? status,
    int? priority,
    String? calendarEventId,
    bool clearCalendarEventId = false,
    DateTime? acceptedAt,
    bool clearAcceptedAt = false,
    DateTime? updatedAt,
  }) {
    return TodoItem(
      id: id,
      title: title ?? this.title,
      description: clearDescription ? null : (description ?? this.description),
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      repeatType: repeatType ?? this.repeatType,
      repeatDays: repeatDays ?? this.repeatDays,
      intervalDays: intervalDays ?? this.intervalDays,
      lastDoneAt: lastDoneAt ?? this.lastDoneAt,
      nextDueDate: clearNextDueDate ? null : (nextDueDate ?? this.nextDueDate),
      status: status ?? this.status,
      priority: priority ?? this.priority,
      calendarEventId: clearCalendarEventId
          ? null
          : (calendarEventId ?? this.calendarEventId),
      acceptedAt: clearAcceptedAt ? null : (acceptedAt ?? this.acceptedAt),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'due_date': dueDate?.millisecondsSinceEpoch,
      'repeat_type': repeatType.storageName,
      'repeat_days': jsonEncode(repeatDays),
      'interval_days': intervalDays,
      'last_done_at': lastDoneAt?.millisecondsSinceEpoch,
      'next_due_date': nextDueDate?.millisecondsSinceEpoch,
      'status': status.name,
      'priority': priority,
      'calendar_event_id': calendarEventId,
      'accepted_at': acceptedAt?.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory TodoItem.fromMap(Map<String, dynamic> map) {
    List<int> days = const [];
    final rawDays = map['repeat_days'];
    if (rawDays is String && rawDays.isNotEmpty) {
      try {
        days = (jsonDecode(rawDays) as List).cast<int>();
      } catch (_) {
        days = rawDays
            .split(',')
            .map((e) => int.tryParse(e.trim()))
            .whereType<int>()
            .toList();
      }
    }

    DateTime? ts(dynamic v) =>
        v == null ? null : DateTime.fromMillisecondsSinceEpoch(v as int);

    return TodoItem(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      dueDate: ts(map['due_date']),
      repeatType: RepeatTypeX.fromName(map['repeat_type'] as String?),
      repeatDays: days,
      intervalDays: (map['interval_days'] as int?) ?? 1,
      lastDoneAt: ts(map['last_done_at']),
      nextDueDate: ts(map['next_due_date']),
      status: TodoStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => TodoStatus.pending,
      ),
      priority: (map['priority'] as int?) ?? 2,
      calendarEventId: map['calendar_event_id'] as String?,
      acceptedAt: ts(map['accepted_at']),
      createdAt: ts(map['created_at']) ?? DateTime.now(),
      updatedAt: ts(map['updated_at']) ?? DateTime.now(),
    );
  }

  /// 供 Web 控制台导出使用
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'due_date': dueDate?.toIso8601String(),
        'repeat_type': repeatType.storageName,
        'repeat_days': repeatDays,
        'interval_days': intervalDays,
        'last_done_at': lastDoneAt?.toIso8601String(),
        'next_due_date': nextDueDate?.toIso8601String(),
        'status': status.name,
        'priority': priority,
        'calendar_event_id': calendarEventId,
        'accepted_at': acceptedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
