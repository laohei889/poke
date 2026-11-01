import 'package:flutter/material.dart';

/// 动效 Token —— "弹性"是灵魂
///
/// 原则：所有"出现 / 确认"类动效带轻微 overshoot（果冻回弹）；
/// 所有"消失 / 取消"类动效不带 overshoot，干净利落。
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 600);

  /// 出现 / 确认类：果冻回弹
  static const Curve spring = Curves.easeOutBack;

  /// 消失 / 取消类
  static const Curve exit = Curves.easeInCubic;

  /// 常规进出
  static const Curve standard = Curves.easeOutCubic;

  /// 按钮按压缩放
  static const double pressScale = 0.97;
}
