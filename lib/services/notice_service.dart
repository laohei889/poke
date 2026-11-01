// 本地通知服务：摇一摇在锁屏/后台抽中任务时弹出高优先级通知，
// 点击通知携带任务 ID 跳转到该待办的详情卡片。
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/todo_item.dart';

/// 通知点击回调：由页面注册，用于跳转到待办详情
typedef TaskNoticeCallback = void Function(String taskId);

@pragma('vm:entry-point')
void notificationBackgroundTap(NotificationResponse response) {
  // 后台点击兜底：仅记录，跳转由前台恢复后处理
  NoticeService.pendingTaskId = response.payload;
}

class NoticeService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'shake_task';
  static const String _channelName = '摇一摇抽中任务';
  static const String _channelDesc = '摇一摇抽中待办时的提醒通知';

  /// 固定通知 ID：每次抽中直接替换上一条，只保留最新结果，不堆叠
  static const int _noticeId = 20261029;

  static bool _initialized = false;

  /// 通知点击后待跳转的任务 ID（跨启动暂存）
  static String? pendingTaskId;

  /// 页面注册的跳转回调
  static TaskNoticeCallback? onTaskNoticeTap;

  static Future<void> init({bool requestPermission = true}) async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onTap,
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundTap,
    );

    // Android 13+ 需要通知运行时权限（仅在 UI isolate 申请，后台 isolate 跳过）
    if (requestPermission) {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();

      // 检查是否由通知点击启动
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp ?? false) {
        pendingTaskId = launchDetails?.notificationResponse?.payload;
      }
    }

    _initialized = true;
  }

  static void _onTap(NotificationResponse response) {
    final taskId = response.payload;
    if (taskId == null || taskId.isEmpty) return;
    pendingTaskId = taskId;
    onTaskNoticeTap?.call(taskId);
  }

  /// 消费待跳转任务（页面恢复时调用）
  static String? consumePendingTaskId() {
    final id = pendingTaskId;
    pendingTaskId = null;
    return id;
  }

  /// 弹出"抽中任务"通知：高优先级、带声音与震动
  static Future<void> showTaskNotice(TodoItem todo) async {
    final due = todo.effectiveDue;
    final dueText = due == null
        ? '无截止时间'
        : '${due.month}月${due.day}日 '
            '${due.hour.toString().padLeft(2, '0')}:${due.minute.toString().padLeft(2, '0')}';

    const android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      enableVibration: true,
      playSound: true,
      category: AndroidNotificationCategory.reminder,
      styleInformation: BigTextStyleInformation(''),
    );

    await _plugin.show(
      _noticeId,
      '摇到一个待办：${todo.title}',
      '接下来做这件事 · 截止 $dueText${todo.isOverdue ? '（已逾期）' : ''}',
      const NotificationDetails(android: android),
      payload: todo.id,
    );
  }

  /// 清除抽中任务通知（接受任务 / 重新抽取时调用）
  static Future<void> cancelTaskNotice([String? taskId]) =>
      _plugin.cancel(_noticeId);
}
