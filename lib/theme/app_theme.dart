import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
/// 主题组装（亮 / 暗）：视觉原点是图标那颗被戳凹的薄荷绿果冻球。
/// 圆润、轻盈、有弹性、留白多、克制用色。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_motion.dart';
import 'app_spacing.dart';
import 'app_theme_extension.dart';
import 'app_typography.dart';

/// 主题组装（亮 / 暗）
///
/// 视觉原点：图标那颗"被戳凹的薄荷绿果冻球"。
/// 圆润、轻盈、有弹性、留白多、克制用色。
abstract final class AppTheme {
  // ═══════════════ 亮色主题 ═══════════════
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary400,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary400,
      onPrimary: AppColors.neutral0,
      primaryContainer: AppColors.primary50,
      onPrimaryContainer: AppColors.primary600,
      secondary: AppColors.primary500,
      onSecondary: AppColors.neutral0,
      surface: AppColors.neutral0,
      onSurface: AppColors.neutral800,
      surfaceContainerLowest: AppColors.neutral0,
      surfaceContainerLow: AppColors.neutral50,
      surfaceContainer: AppColors.neutral50,
      surfaceContainerHighest: AppColors.neutral100,
      outline: AppColors.neutral200,
      outlineVariant: AppColors.neutral100,
      error: AppColors.danger,
      onError: AppColors.neutral0,
    );

    return _build(
      scheme: scheme,
      extension: AppThemeExtension.light,
      scaffoldBg: AppColors.neutral50,
      textTheme: AppTypography.textTheme(
        AppColors.neutral900,
        AppColors.neutral400,
      ),
    );
  }

  // ═══════════════ 深色主题 ═══════════════
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.darkPrimary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.darkPrimary,
      onPrimary: AppColors.neutral900,
      primaryContainer: const Color(0xFF16241E),
      onPrimaryContainer: AppColors.darkPrimary,
      surface: AppColors.darkCard,
      onSurface: AppColors.darkText,
      surfaceContainerLowest: AppColors.darkBg,
      surfaceContainerLow: const Color(0xFF131D19),
      surfaceContainer: AppColors.darkCard,
      surfaceContainerHighest: const Color(0xFF22302B),
      outline: const Color(0xFF3A4A44),
      outlineVariant: const Color(0x14FFFFFF),
      error: AppColors.danger,
      onError: AppColors.neutral0,
    );

    return _build(
      scheme: scheme,
      extension: AppThemeExtension.dark,
      scaffoldBg: AppColors.darkBg,
      textTheme: AppTypography.textTheme(
        AppColors.darkText,
        AppColors.darkSubText,
      ),
    );
  }

  // ═══════════════ 共用组装 ═══════════════
  static ThemeData _build({
    required ColorScheme scheme,
    required AppThemeExtension extension,
    required Color scaffoldBg,
    required TextTheme textTheme,
  }) {
    final isDark = scheme.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      textTheme: textTheme,
      fontFamily: AppTypography.fontFamily,
      extensions: [extension],

      // ── 卡片：圆角 20，极轻阴影
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
      ),

      // ── 主按钮（胶囊）：按压 = 缩小 + 加深，不加重阴影
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.disabled)) return scheme.primaryContainer;
            if (s.contains(WidgetState.pressed)) return AppColors.primary500;
            return scheme.primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.disabled)) {
              return isDark ? AppColors.darkSubText : AppColors.primary200;
            }
            return scheme.onPrimary;
          }),
          minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 28),
          ),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadius.pillRadius),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          elevation: const WidgetStatePropertyAll(0),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),

      // ── 次按钮（描边）
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(scheme.primary),
          side: WidgetStatePropertyAll(
            BorderSide(color: scheme.primary, width: 1.5),
          ),
          minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24),
          ),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      ),

      // ── 文字按钮
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(
            isDark ? AppColors.darkPrimary : AppColors.primary500,
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
      ),

      // ── 输入框：圆角 14，聚焦描边主色
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: extension.inputBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        hintStyle: TextStyle(color: extension.placeholder, fontSize: 15),
        border: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),

      // ── 勾选框：圆形，呼应果冻球
      checkboxTheme: CheckboxThemeData(
        shape: const CircleBorder(),
        side: BorderSide(color: scheme.outline, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return scheme.primary;
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),

      // ── 开关
      switchTheme: SwitchThemeData(
        thumbColor:
            WidgetStatePropertyAll(isDark ? AppColors.darkBg : Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return scheme.primary;
          return scheme.outlineVariant;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),

      // ── 标签 Chip：胶囊
      chipTheme: ChipThemeData(
        backgroundColor: extension.chipBg,
        labelStyle: TextStyle(
          color: extension.chipFg,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // ── 弹窗
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        elevation: 0,
        shape:
            const RoundedRectangleBorder(borderRadius: AppRadius.dialogRadius),
      ),

      // ── 底部抽屉
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetRadius),
        modalBarrierColor: const Color(0x521F2D28),
        dragHandleColor: scheme.outline,
      ),

      // ── 分隔线
      dividerTheme: DividerThemeData(
        color: extension.divider,
        thickness: 1,
        space: 1,
      ),

      // ── 进度条
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primaryContainer,
        circularTrackColor: scheme.primaryContainer,
      ),

      // ── 页面转场（温和）
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  // ═══════════════ 状态栏样式 ═══════════════
  static SystemUiOverlayStyle overlayStyle(Brightness b) =>
      b == Brightness.light
          ? SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: AppColors.neutral0,
              systemNavigationBarIconBrightness: Brightness.dark,
            )
          : SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: AppColors.darkBg,
              systemNavigationBarIconBrightness: Brightness.light,
            );
}

/// 全局动效开关辅助：出现/确认用 spring，消失/取消用 exit
abstract final class JellyMotion {
  /// 出现 / 确认：果冻回弹
  static const Curve appear = AppMotion.spring;

  /// 消失 / 取消：干净利落
  static const Curve dismiss = AppMotion.exit;
}
