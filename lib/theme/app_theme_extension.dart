// ThemeExtension：承载 Material 3 覆盖不到的语义色
// （选中行底色、Chip、优先级色阶、输入框底、占位符），深浅主题自动切换。
import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Material 3 ColorScheme 覆盖不到的语义色，用 ThemeExtension 承载
@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final Color primarySoft; // 选中行背景
  final Color chipBg; // 标签底
  final Color chipFg; // 标签字
  final Color priorityHigh;
  final Color priorityMid;
  final Color priorityLow;
  final Color accent; // 仅高光时刻
  final Color divider;
  final Color inputBg;
  final Color placeholder;

  const AppThemeExtension({
    required this.primarySoft,
    required this.chipBg,
    required this.chipFg,
    required this.priorityHigh,
    required this.priorityMid,
    required this.priorityLow,
    required this.accent,
    required this.divider,
    required this.inputBg,
    required this.placeholder,
  });

  static const light = AppThemeExtension(
    primarySoft: AppColors.primary50,
    chipBg: AppColors.primary50,
    chipFg: AppColors.primary500,
    priorityHigh: AppColors.primary500,
    priorityMid: AppColors.primary200,
    priorityLow: AppColors.neutral200,
    accent: AppColors.accent,
    divider: AppColors.neutral100,
    inputBg: AppColors.neutral50,
    placeholder: AppColors.neutral400,
  );

  static const dark = AppThemeExtension(
    primarySoft: Color(0xFF16241E),
    chipBg: Color(0xFF1A2420),
    chipFg: AppColors.darkPrimary,
    priorityHigh: AppColors.darkPrimary,
    priorityMid: Color(0xFF2BB57A),
    priorityLow: Color(0xFF3A4A44),
    accent: AppColors.accent,
    divider: Color(0x14FFFFFF),
    inputBg: Color(0xFF131D19),
    placeholder: AppColors.darkSubText,
  );

  @override
  AppThemeExtension copyWith({
    Color? primarySoft,
    Color? chipBg,
    Color? chipFg,
    Color? priorityHigh,
    Color? priorityMid,
    Color? priorityLow,
    Color? accent,
    Color? divider,
    Color? inputBg,
    Color? placeholder,
  }) {
    return AppThemeExtension(
      primarySoft: primarySoft ?? this.primarySoft,
      chipBg: chipBg ?? this.chipBg,
      chipFg: chipFg ?? this.chipFg,
      priorityHigh: priorityHigh ?? this.priorityHigh,
      priorityMid: priorityMid ?? this.priorityMid,
      priorityLow: priorityLow ?? this.priorityLow,
      accent: accent ?? this.accent,
      divider: divider ?? this.divider,
      inputBg: inputBg ?? this.inputBg,
      placeholder: placeholder ?? this.placeholder,
    );
  }

  @override
  AppThemeExtension lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      chipBg: Color.lerp(chipBg, other.chipBg, t)!,
      chipFg: Color.lerp(chipFg, other.chipFg, t)!,
      priorityHigh: Color.lerp(priorityHigh, other.priorityHigh, t)!,
      priorityMid: Color.lerp(priorityMid, other.priorityMid, t)!,
      priorityLow: Color.lerp(priorityLow, other.priorityLow, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      inputBg: Color.lerp(inputBg, other.inputBg, t)!,
      placeholder: Color.lerp(placeholder, other.placeholder, t)!,
    );
  }
}

/// 便捷访问：context.appTheme.primarySoft
extension AppThemeX on BuildContext {
  AppThemeExtension get appTheme =>
      Theme.of(this).extension<AppThemeExtension>()!;
}
