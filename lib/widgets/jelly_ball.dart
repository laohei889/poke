// 果冻球 —— 图标视觉原点的复用：
// 空状态放「完整的球」，摇一摇结果放「被戳凹的球」，
// 勾选框即小球，形成统一的视觉语言。
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

/// 果冻球 —— 图标视觉原点的复用：
/// 空状态放"完整的球"，摇一摇结果放"被戳凹的球"，勾选框即小球。
class JellyBall extends StatelessWidget {
  const JellyBall({
    super.key,
    this.size = 120,
    this.dented = false,
    this.showArcs = true,
  });

  final double size;

  /// 是否带"被戳凹"效果（摇一摇结果）
  final bool dented;

  /// 是否显示动感弧线
  final bool showArcs;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _JellyBallPainter(dented: dented, showArcs: showArcs),
    );
  }
}

class _JellyBallPainter extends CustomPainter {
  _JellyBallPainter({required this.dented, required this.showArcs});

  final bool dented;
  final bool showArcs;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.32;

    if (showArcs) {
      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = size.width * 0.022
        ..color = AppColors.primary400.withValues(alpha: 0.55);
      final rect = Rect.fromCircle(
        center: center + Offset(radius * 1.45, 0),
        radius: radius * 0.62,
      );
      canvas.drawArc(rect, -1.0, 2.0, false, arcPaint);

      final arcPaint2 = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = size.width * 0.018
        ..color = AppColors.primary400.withValues(alpha: 0.35);
      final rect2 = Rect.fromCircle(
        center: center + Offset(radius * 1.95, 0),
        radius: radius * 0.38,
      );
      canvas.drawArc(rect2, -1.0, 2.0, false, arcPaint2);
    }

    final ballPaint = Paint()..color = AppColors.primary400;
    var ballPath = Path();

    if (dented) {
      // 左侧 9-10 点钟方向咬出一段内凹弧（被指尖戳过）
      final dentCenter = center + Offset(-radius * 0.98, -radius * 0.06);
      ballPath.addOval(Rect.fromCircle(center: center, radius: radius));
      final dent = Path()
        ..addOval(Rect.fromCircle(center: dentCenter, radius: radius * 0.42));
      ballPath = Path.combine(PathOperation.difference, ballPath, dent);

      // 凹陷暗部
      final shadePaint = Paint()
        ..color = AppColors.primary500.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      final shade = Path.combine(
        PathOperation.intersect,
        Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
        Path()
          ..addOval(
            Rect.fromCircle(center: dentCenter, radius: radius * 0.42),
          ),
      );
      canvas.drawPath(shade, shadePaint);
    } else {
      ballPath.addOval(Rect.fromCircle(center: center, radius: radius));
    }

    canvas.drawPath(ballPath, ballPaint);

    // 果冻高光
    final highlight = Paint()..color = Colors.white.withValues(alpha: 0.40);
    canvas.save();
    canvas.translate(center.dx - radius * 0.38, center.dy - radius * 0.42);
    canvas.rotate(-0.55);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: radius * 0.62,
        height: radius * 0.36,
      ),
      highlight,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_JellyBallPainter oldDelegate) =>
      oldDelegate.dented != dented || oldDelegate.showArcs != showArcs;
}

/// 果冻按压手感：出现/确认带轻微 overshoot
class JellyTap extends StatefulWidget {
  const JellyTap({super.key, required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<JellyTap> createState() => _JellyTapState();
}

class _JellyTapState extends State<JellyTap> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? AppMotion.pressScale : 1.0,
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        child: widget.child,
      ),
    );
  }
}
