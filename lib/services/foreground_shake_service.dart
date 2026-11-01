// 后台 / 锁屏摇一摇：前台服务（常驻通知）+ 传感器监听。
// 抽取与通知在服务 isolate 内自完成——App 被划掉后主 isolate 已销毁，
// 不能依赖"转交主 isolate 弹通知"，否则纯后台时摇动毫无反应。
// 耗电较高，默认关闭，仅当用户在设置里显式开启时启动。
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../models/todo_item.dart';
import '../utils/constants.dart';
import 'db_service.dart';
import 'notice_service.dart';
import 'shake_service.dart';
import 'task_picker.dart';

/// 后台/锁屏摇一摇：前台服务（常驻通知）+ 传感器监听。
/// 默认关闭，仅当用户在设置里显式开启时启动。
@pragma('vm:entry-point')
void backgroundShakeStartCallback() {
  FlutterForegroundTask.setTaskHandler(BackgroundShakeTaskHandler());
}

class BackgroundShakeTaskHandler extends TaskHandler {
  ShakeService? _shake;

  /// 主界面是否前台可见（由主 isolate 生命周期同步）。
  /// 前台时只派发结果、不弹本地通知，避免使用中被通知打扰。
  bool _uiResumed = false;

  /// 摇一摇页是否已自行监听摇动：是则服务端跳过，避免双重抽取。
  bool _uiShakeActive = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // 服务运行在独立引擎 isolate：通知渠道需在本 isolate 内初始化
    try {
      await NoticeService.init(requestPermission: false);
    } catch (_) {
      // 通知初始化失败不阻断摇一摇监听
    }
    _shake = ShakeService(onShake: _onShake)..start();
  }

  /// 摇动：服务 isolate 内直接抽任务；后台弹通知，前台仅派发结果。
  Future<void> _onShake() async {
    if (_uiShakeActive) return; // 前台摇一摇页自行处理
    TodoItem? todo;
    try {
      final pool = await DbService().query(status: TodoStatus.pending);
      todo = pickWeightedRandom(pool);
    } catch (_) {
      return;
    }

    if (todo == null) {
      FlutterForegroundTask.updateService(
        notificationTitle: foregroundNotificationTitle,
        notificationText: '待执行池是空的，先去添加待办吧',
      );
      return;
    }

    if (!_uiResumed) {
      // 后台/锁屏：弹高优先级本地通知（带声音震动），点通知直达结果页
      try {
        await NoticeService.showTaskNotice(todo);
      } catch (_) {}
    }
    FlutterForegroundTask.updateService(
      notificationTitle: foregroundNotificationTitle,
      notificationText: '摇到了：${todo.title}',
    );
    // 主 isolate 存活时同步界面展示同一任务（避免二次随机抽成两条）
    FlutterForegroundTask.sendDataToMain({'event': 'shake', 'taskId': todo.id});
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // 传感器监听在 onStart 中常驻，无需周期处理
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _shake?.stop();
    _shake = null;
  }

  @override
  void onReceiveData(Object data) {
    if (data is! Map) return;
    switch (data['event']) {
      case 'uiResumed': // 主 isolate 同步界面可见性：前台摇动不弹通知
        _uiResumed = data['value'] == true;
      case 'uiShakeActive': // 摇一摇页自行监听中：服务端跳过避免双重抽取
        _uiShakeActive = data['value'] == true;
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    FlutterForegroundTask.sendDataToMain({'event': 'notificationButton', 'id': id});
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.sendDataToMain({'event': 'notificationPressed'});
  }

  @override
  void onNotificationDismissed() {
    FlutterForegroundTask.sendDataToMain({'event': 'notificationDismissed'});
  }
}

class ForegroundShakeService {
  /// 初始化（需在启动服务前调用）
  static Future<void> init() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'shake_foreground_service',
        channelName: '摇一摇后台服务',
        channelDescription: '后台摇一摇抽待办时显示的常驻通知',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// 申请通知与电池优化白名单等权限
  static Future<void> requestPermissions() async {
    final permission = await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
  }

  static Future<bool> get isRunning => FlutterForegroundTask.isRunningService;

  static Future<void> start() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
    } else {
      await FlutterForegroundTask.startService(
        notificationTitle: foregroundNotificationTitle,
        notificationText: foregroundNotificationText,
        callback: backgroundShakeStartCallback,
      );
    }
  }

  static Future<void> stop() => FlutterForegroundTask.stopService();

  static void addDataCallback(void Function(Object data) callback) =>
      FlutterForegroundTask.addTaskDataCallback(callback);

  static void removeDataCallback(void Function(Object data) callback) =>
      FlutterForegroundTask.removeTaskDataCallback(callback);

  /// 向服务同步主界面可见性（前台时摇动不弹本地通知）
  static void sendUiActive(bool resumed) {
    try {
      FlutterForegroundTask.sendDataToTask({
        'event': 'uiResumed',
        'value': resumed,
      });
    } catch (_) {
      // 服务未运行时忽略
    }
  }

  /// 向服务同步"摇一摇页自行监听中"（服务端跳过，避免双重抽取）
  static void sendUiShakeActive(bool active) {
    try {
      FlutterForegroundTask.sendDataToTask({
        'event': 'uiShakeActive',
        'value': active,
      });
    } catch (_) {
      // 服务未运行时忽略
    }
  }
}
