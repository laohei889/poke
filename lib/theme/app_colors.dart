import 'package:flutter/material.dart';

/// 颜色 Token —— 与设计规范一一对应
///
/// 核心原则：主色（薄荷绿）只承担"行动 / 选中 / 完成"三类语义，
/// 页面主背景永远用中性色 —— 绿色是"点"不是"面"。
abstract final class AppColors {
  // ── 主色阶（薄荷绿，源于图标那颗果冻球）
  static const primary50 = Color(0xFFEAFBF3);
  static const primary100 = Color(0xFFC9F4E1);
  static const primary200 = Color(0xFF7FE8C0);
  static const primary300 = Color(0xFF4FE0A8);
  static const primary400 = Color(0xFF3DDC97); // 主色
  static const primary500 = Color(0xFF2BB57A); // 按压态 / 凹陷阴影
  static const primary600 = Color(0xFF1F8F5E);

  // ── 中性色阶（暖灰，避免冷硬）
  static const neutral0 = Color(0xFFFFFFFF);
  static const neutral50 = Color(0xFFF5FBF8); // 页面背景（带一丝薄荷）
  static const neutral100 = Color(0xFFEDF3F0);
  static const neutral200 = Color(0xFFDCE5E1);
  static const neutral400 = Color(0xFF9AA8A3);
  static const neutral600 = Color(0xFF5C6B66);
  static const neutral800 = Color(0xFF2E3A36);
  static const neutral900 = Color(0xFF1F2D28);

  // ── 语义色（克制，仅状态用）
  static const success = primary400;
  static const warning = Color(0xFFFFB020);
  static const danger = Color(0xFFFF5A5F);
  static const info = Color(0xFF4FC3F7);

  /// 点缀色：仅高光时刻（摇一摇抽中闪光），默认不出现在常规界面
  static const accent = Color(0xFFFFD23F);

  // ── 深色模式专用
  static const darkBg = Color(0xFF0F1714);
  static const darkCard = Color(0xFF1A2420);
  static const darkText = Color(0xFFEAFBF3);
  static const darkSubText = Color(0xFF7A8A84);
  static const darkPrimary = Color(0xFF4FE0A8); // 绿色提亮一档保证对比
}
