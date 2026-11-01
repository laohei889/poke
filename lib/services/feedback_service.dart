// 抽中反馈服务：真实提示音 + 强制振动。
// 系统 HapticFeedback / SystemSound 在静音或关闭触感反馈的机型上完全无感，
// 这里改用 Vibrator 服务 + 音频资源播放，保证任何模式下都有明确反馈。
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

class FeedbackService {
  static final AudioPlayer _player = AudioPlayer();

  /// 抽中任务反馈：提示音 + 振动 400ms
  static Future<void> onDraw() async {
    await _vibrate(400);
    await _playSound();
  }

  /// 接受任务反馈：短振动 150ms
  static Future<void> onAccept() => _vibrate(150);

  static Future<void> _vibrate(int ms) async {
    try {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(duration: ms);
        return;
      }
    } catch (_) {}
    // 兜底：系统触感
    HapticFeedback.vibrate();
  }

  static Future<void> _playSound() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sound/draw.wav'));
    } catch (_) {
      await SystemSound.play(SystemSoundType.alert);
    }
  }
}
