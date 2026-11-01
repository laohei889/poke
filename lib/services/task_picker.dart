// 摇一摇抽取算法：纯函数，UI isolate 与前台服务 isolate 共用。
import 'dart:math';

import '../models/todo_item.dart';

/// 从待执行池中按权重随机抽取一个事项。
///
/// 权重规则：基础 1，高优先级 +3，当天到期 +2，已逾期 +5。
/// [exclude] 可排除上一次抽中的事项（"换一个"）；
/// 若排除后池子为空则回退到全池（只剩一条时重复显示同一条）。
TodoItem? pickWeightedRandom(
  List<TodoItem> pool, {
  TodoItem? exclude,
  Random? rng,
}) {
  var candidates =
      pool.where((t) => t.status == TodoStatus.pending && t.id != exclude?.id).toList();
  if (candidates.isEmpty) {
    candidates = pool.where((t) => t.status == TodoStatus.pending).toList();
  }
  if (candidates.isEmpty) return null;

  final random = rng ?? Random();
  final weighted = <(TodoItem, int)>[];
  for (final todo in candidates) {
    var weight = 1;
    if (todo.priority >= 3) weight += 3;
    if (todo.isDueToday) weight += 2;
    if (todo.isOverdue) weight += 5;
    weighted.add((todo, weight));
  }

  final total = weighted.fold<int>(0, (sum, e) => sum + e.$2);
  var pick = random.nextInt(total);
  for (final entry in weighted) {
    pick -= entry.$2;
    if (pick < 0) return entry.$1;
  }
  return candidates.last;
}
