// 摇一摇检测：短窗口内多次超阈值晃动才算一次有效摇动，
// 单次颠簸（放口袋、走路）不会误触发。
import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

import '../utils/constants.dart';

/// 摇一摇检测服务。
///
/// 判定方式：在 [peakWindow] 时间窗口内出现至少 [requiredPeaks] 次
/// "加速度模长偏离重力超过 [threshold]"的峰值，才视为一次有意摇动。
/// 连续两次触发需间隔 [cooldown] 以上。
class ShakeService {
  ShakeService({
    required this.onShake,
    this.threshold = shakeDeltaThreshold,
    this.cooldown = shakeCooldown,
    this.requiredPeaks = shakeRequiredPeaks,
    this.peakWindow = shakePeakWindow,
  });

  final void Function() onShake;

  /// 单个峰值的触发阈值（m/s²，相对重力的偏差）
  final double threshold;

  /// 两次触发的最小间隔
  final Duration cooldown;

  /// 窗口内需要的峰值个数（区分"摇动"与单次颠簸）
  final int requiredPeaks;

  /// 峰值累计窗口
  final Duration peakWindow;

  static const double _gravity = 9.8;

  StreamSubscription<AccelerometerEvent>? _subscription;
  final List<DateTime> _peaks = [];
  DateTime? _lastShakeAt;

  bool get isListening => _subscription != null;

  void start() {
    _subscription ??= accelerometerEventStream().listen(_onEvent);
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _peaks.clear();
  }

  void _onEvent(AccelerometerEvent event) {
    final magnitude =
        sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    final delta = (magnitude - _gravity).abs();
    if (delta < threshold) return;

    final now = DateTime.now();
    _peaks.add(now);
    _peaks.removeWhere((t) => now.difference(t) > peakWindow);

    if (_peaks.length < requiredPeaks) return;
    if (_lastShakeAt != null && now.difference(_lastShakeAt!) < cooldown) {
      return;
    }
    _lastShakeAt = now;
    _peaks.clear();
    onShake();
  }
}
