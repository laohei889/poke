import 'package:flutter/material.dart';

/// 字体层级 —— 用字重差拉开层级，字号克制，行高偏松（约 1.5）
abstract final class AppTypography {
  /// 接入思源黑体时填 'SourceHanSansSC'，默认跟随系统
  static const String? fontFamily = null;

  static TextTheme textTheme(Color primaryText, Color secondaryText) {
    return TextTheme(
      // 大标题
      displaySmall: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 36 / 28,
        color: primaryText,
        letterSpacing: -0.2,
      ),
      // 页面标题
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 30 / 22,
        color: primaryText,
      ),
      // 卡片标题
      titleMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 24 / 17,
        color: primaryText,
      ),
      // 正文
      bodyMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 22 / 15,
        color: primaryText,
      ),
      // 辅助文字
      bodySmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 18 / 13,
        color: secondaryText,
      ),
      // 标签 / 徽章
      labelSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 16 / 12,
        color: secondaryText,
      ),
    );
  }
}
