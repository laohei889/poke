// 首页：待办列表 + 过滤（全部/今天/待执行/执行中/已完成）
// + 底部快速录入栏；启动时询问上次接受任务的完成情况。
import 'package:flutter/material.dart';

import '../widgets/jelly_ball.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/todo_item.dart';
import '../providers/todo_provider.dart';
import '../services/feedback_service.dart';
import '../services/foreground_shake_service.dart';
import '../services/notice_service.dart';
import '../services/task_picker.dart';
import '../widgets/quick_input_bar.dart';
import '../widgets/todo_list_item.dart';
import 'add_todo_screen.dart';
import 'settings_screen.dart';
import 'shake_screen.dart';
import 'web_console_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  String _filter = 'all';
  bool _askedAboutInProgress = false;
  TodoItem? _lastDrawn;

  static const _filters = <(String, String)>[
    ('all', '全部'),
    ('today', '今天'),
    ('pending', '待执行'),
    ('inProgress', '执行中'),
    ('done', '已完成'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ForegroundShakeService.addDataCallback(_onTaskData);
    NoticeService.onTaskNoticeTap = _openShakeResult;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _askAboutInProgress();
      _resumeBackgroundShake();
      // 冷启动时由通知点击拉起：直达抽中的待办
      final pending = NoticeService.consumePendingTaskId();
      if (pending != null) _openShakeResult(pending);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ForegroundShakeService.removeDataCallback(_onTaskData);
    NoticeService.onTaskNoticeTap = null;
    super.dispose();
  }

  /// 同步前台/后台状态给摇一摇服务：
  /// 前台摇动只展示结果不弹通知，后台摇动弹本地通知。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ForegroundShakeService.sendUiActive(state == AppLifecycleState.resumed);
  }

  /// 打开摇一摇结果页并定位到指定待办
  void _openShakeResult(String taskId) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShakeScreen(initialTaskId: taskId),
      ),
    );
  }

  /// 下次打开 App 时询问上次接受任务的完成情况
  /// （必须等数据加载完成后再查，否则启动瞬间列表为空会漏问）
  Future<void> _askAboutInProgress() async {
    if (_askedAboutInProgress) return;
    _askedAboutInProgress = true;

    // 确保数据已加载完成
    await ref.read(todoProvider.notifier).load();
    if (!mounted) return;

    final items = ref.read(todoProvider).inProgress;
    for (final todo in items) {
      if (!mounted) return;
      final completed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('上次接受的待办'),
          content: Text('【${todo.title}】完成了吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('没完成'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('完成了'),
            ),
          ],
        ),
      );
      if (completed == true) {
        await ref.read(todoProvider.notifier).complete(todo);
      }
      // 选择"没完成"：保持"执行中"，下次打开 App 继续询问；
      // 不退回待执行池（退还会丢失"已接受"上下文）
    }
  }

  /// 若用户开启了后台摇一摇，恢复前台服务
  Future<void> _resumeBackgroundShake() async {
    if (!ref.read(settingsProvider).backgroundShakeEnabled) return;
    await ForegroundShakeService.init();
    await ForegroundShakeService.start();
    ForegroundShakeService.sendUiActive(true);
  }

  void _onTaskData(Object data) {
    if (data is! Map) return;
    final event = data['event'];

    // 后台/锁屏摇动：服务已抽好任务并弹好通知，
    // 这里展示同一任务（不再二次随机），前台可见时直达结果页
    if (event == 'shake') {
      final taskId = data['taskId'] as String?;
      _showDrawnTask(taskId);
      return;
    }

    // 点击前台服务常驻通知：直接进入摇一摇页
    if (event == 'notificationPressed' && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ShakeScreen()),
      );
    }
  }

  /// 展示服务抽中的任务：前台可见时直达结果页。
  /// [taskId] 为服务已抽中的任务；为空时回退为本地抽取（兼容旧事件）。
  Future<void> _showDrawnTask(String? taskId) async {
    TodoItem? todo;
    if (taskId != null) {
      await ref.read(todoProvider.notifier).load();
      todo = ref
          .read(todoProvider)
          .todos
          .where((t) => t.id == taskId)
          .firstOrNull;
    }
    todo ??= pickWeightedRandom(
      ref.read(todoProvider).pending,
      exclude: _lastDrawn,
    );
    if (todo == null) return;
    _lastDrawn = todo;
    await FeedbackService.onDraw();
    // 前台可见时直接进入结果页（通知已由服务弹出/或不弹）
    final resumed =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (resumed && mounted) {
      _openShakeResult(todo.id);
    }
  }

  List<TodoItem> _visible(List<TodoItem> todos) {
    final List<TodoItem> result;
    switch (_filter) {
      case 'today':
        result = todos
            .where((t) =>
                (t.status == TodoStatus.pending ||
                    t.status == TodoStatus.inProgress) &&
                (t.isDueToday || t.isOverdue))
            .toList();
      case 'pending':
        result = todos.where((t) => t.status == TodoStatus.pending).toList();
      case 'inProgress':
        result = todos.where((t) => t.status == TodoStatus.inProgress).toList();
      case 'done':
        result = todos
            .where((t) =>
                t.status == TodoStatus.completed ||
                t.status == TodoStatus.archived)
            .toList();
      default:
        result = todos.where((t) => t.status != TodoStatus.archived).toList();
    }
    return _sortForDisplay(result);
  }

  /// 展示顺序：执行中优先（方便确认完成情况），其次待执行按到期时间升序
  List<TodoItem> _sortForDisplay(List<TodoItem> items) {
    final sorted = [...items];
    sorted.sort((a, b) {
      int rank(TodoItem t) => switch (t.status) {
            TodoStatus.inProgress => 0,
            TodoStatus.pending => 1,
            _ => 2,
          };
      final r = rank(a).compareTo(rank(b));
      if (r != 0) return r;
      final da = a.effectiveDue ?? a.createdAt;
      final db = b.effectiveDue ?? b.createdAt;
      return da.compareTo(db);
    });
    return sorted;
  }

  Future<void> _confirmDelete(TodoItem todo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除待办'),
        content: Text('确定删除「${todo.title}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(todoProvider.notifier).remove(todo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(todoProvider);
    final items = _visible(state.todos);

    return Scaffold(
      appBar: AppBar(
        title: const Text('待办'),
        actions: [
          IconButton(
            tooltip: '摇一摇抽任务',
            icon: const Icon(Icons.casino_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ShakeScreen()),
            ),
          ),
          IconButton(
            tooltip: 'PC 局域网控制台',
            icon: const Icon(Icons.desktop_windows_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WebConsoleScreen()),
            ),
          ),
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                for (final (value, label) in _filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _filter == value,
                      onSelected: (_) => setState(() => _filter = value),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: state.loading
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                    ? _EmptyView(filter: _filter)
                    : RefreshIndicator(
                        onRefresh: () => ref.read(todoProvider.notifier).load(),
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 4, bottom: 12),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final todo = items[index];
                            return TodoListItem(
                              todo: todo,
                              onComplete: () async {
                                await ref
                                    .read(todoProvider.notifier)
                                    .complete(todo);
                                // 日历同步失败时明确提示，避免"提醒静默丢失"
                                final err = ref
                                    .read(todoProvider.notifier)
                                    .lastCalendarError;
                                if (err != null && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('已完成，但日历提醒未同步：$err'),
                                    ),
                                  );
                                }
                              },
                              onEdit: () async {
                                final changed = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddTodoScreen(todo: todo),
                                  ),
                                );
                                if (changed == true) return;
                              },
                              onDelete: () => _confirmDelete(todo),
                            );
                          },
                        ),
                      ),
          ),
          const QuickInputBar(),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.filter});

  final String filter;

  @override
  Widget build(BuildContext context) {
    final text = switch (filter) {
      'today' => '今天没有到期的事项 🎉',
      'done' => '还没有完成的事项',
      _ => '戳一下试试？手欠一下就有事了',
    };

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const JellyBall(size: 120),
          const SizedBox(height: 20),
          Text(
            text,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ShakeScreen()),
            ),
            icon: const Icon(Icons.casino_outlined),
            label: const Text('摇一摇抽一个'),
          ),
        ],
      ),
    );
  }
}
