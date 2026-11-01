// 摇一摇「漂流瓶」抽任务页：加速度检测触发，按权重随机抽取，
// 结果卡片带果冻回弹动效，支持 [接受 / 换一个]。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/todo_item.dart';
import '../providers/todo_provider.dart';
import '../services/feedback_service.dart';
import '../services/foreground_shake_service.dart';
import '../services/notice_service.dart';
import '../services/shake_service.dart';
import '../theme/app_motion.dart';
import '../widgets/jelly_ball.dart';

/// 摇一摇"漂流瓶"抽任务；[initialTaskId] 用于从通知点击直达某条待办
class ShakeScreen extends ConsumerStatefulWidget {
  const ShakeScreen({super.key, this.initialTaskId});

  final String? initialTaskId;

  @override
  ConsumerState<ShakeScreen> createState() => _ShakeScreenState();
}

class _ShakeScreenState extends ConsumerState<ShakeScreen> {
  ShakeService? _shakeService;
  TodoItem? _drawn;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    // 本页自行监听摇动：通知后台服务暂停处理，避免双重抽取
    ForegroundShakeService.sendUiShakeActive(true);
    _shakeService = ShakeService(onShake: _draw)..start();
    // 从通知点击进入：直接展示该待办
    final taskId = widget.initialTaskId;
    if (taskId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showTaskById(taskId));
    }
  }

  Future<void> _showTaskById(String taskId) async {
    await ref.read(todoProvider.notifier).load();
    if (!mounted) return;
    final todo = ref.read(todoProvider).todos
        .where((t) => t.id == taskId)
        .firstOrNull;
    if (todo != null) {
      setState(() => _drawn = todo);
      _feedback();
    }
  }

  @override
  void dispose() {
    _shakeService?.stop();
    ForegroundShakeService.sendUiShakeActive(false);
    WakelockPlus.disable();
    super.dispose();
  }

  void _draw() {
    if (!mounted) return;
    final todo = ref
        .read(todoProvider.notifier)
        .drawRandom(exclude: _drawn);
    setState(() => _drawn = todo);
    // 重新抽取时清掉系统通知里的旧结果，只保留最新
    NoticeService.cancelTaskNotice();
    if (todo == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('抽取池空了，先添加几条待办吧')));
      return;
    }
    _feedback();
  }

  /// 抽中反馈：提示音 + 振动
  void _feedback() {
    FeedbackService.onDraw();
  }

  /// 结果卡片：球以果冻回弹从 scale 0.4 弹到 1.0
  Widget _resultCard(ThemeData theme, TodoItem todo) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(todo.id),
      tween: Tween(begin: 0.4, end: 1.0),
      duration: AppMotion.base,
      curve: AppMotion.spring,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Column(
        children: [
          const JellyBall(size: 150, dented: true),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: _TaskCard(todo: todo),
          ),
        ],
      ),
    );
  }

  Future<void> _accept() async {
    final todo = _drawn;
    if (todo == null) return;
    await ref.read(todoProvider.notifier).accept(todo);
    // 接受后清除系统通知里的抽取结果
    await NoticeService.cancelTaskNotice();
    if (!mounted) return;
    FeedbackService.onAccept();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已接受「${todo.title}」，完成后到列表点勾选')),
    );
    // 回到主界面（无论从哪里进入的摇一摇页）
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final todo = _drawn;

    return Scaffold(
      appBar: AppBar(title: const Text('摇一摇 · 漂流瓶')),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.08),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: Column(
          children: [
            const Spacer(),
            if (todo == null) ...[
              const JellyBall(size: 130),
              const SizedBox(height: 12),
              Text(
                '摇一摇手机，随机抽一个待办',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                '抽到什么做什么 · 再摇一次可换一个',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ] else
              _resultCard(theme, todo),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (todo != null) ...[
                    FilledButton.icon(
                      onPressed: _accept,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('接受'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _draw,
                      icon: const Icon(Icons.casino_outlined),
                      label: const Text('换一个'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ] else
                    FilledButton.icon(
                      onPressed: _draw,
                      icon: const Icon(Icons.casino_outlined),
                      label: const Text('帮我抽一个'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.todo});

  final TodoItem todo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final due = todo.effectiveDue;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              todo.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            if (todo.description != null && todo.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                todo.description!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (due != null)
                  Chip(
                    avatar: Icon(
                      todo.isOverdue
                          ? Icons.error_outline_rounded
                          : Icons.schedule_rounded,
                      size: 16,
                      color: todo.isOverdue
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                    label: Text(
                      '${due.month}月${due.day}日 '
                      '${due.hour.toString().padLeft(2, '0')}:${due.minute.toString().padLeft(2, '0')}'
                      '${todo.isOverdue ? ' · 已逾期' : ''}',
                    ),
                  ),
                Chip(
                  avatar: const Icon(Icons.flag_outlined, size: 16),
                  label: Text('优先级：${switch (todo.priority) {
                    3 => '高',
                    1 => '低',
                    _ => '中',
                  }}'),
                ),
                if (todo.isRepeating)
                  const Chip(
                    avatar: Icon(Icons.repeat_rounded, size: 16),
                    label: Text('重复事项'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
