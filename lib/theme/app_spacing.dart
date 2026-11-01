import 'package:flutter/material.dart';

/// 间距 Token：基础单位 4
abstract final class AppSpacing {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s48 = 48;

  /// 页面左右边距
  static const double pagePadding = 20;

  /// 卡片间距
  static const double cardGap = 10;

  /// 列表底部留白（避开快速输入栏）
  static const double listBottomPadding = 96;
}

/// 圆角 Token：一切"圆润可回弹"，禁止直角
abstract final class AppRadius {
  static const double card = 20;
  static const double dialog = 24;
  static const double input = 14;
  static const double chip = 999;
  static const double pill = 999;
  static const double sheetTop = 24;

  static const BorderRadius cardRadius =
      BorderRadius.all(Radius.circular(card));
  static const BorderRadius dialogRadius =
      BorderRadius.all(Radius.circular(dialog));
  static const BorderRadius inputRadius =
      BorderRadius.all(Radius.circular(input));
  static const BorderRadius pillRadius =
      BorderRadius.all(Radius.circular(pill));
  static const BorderRadius sheetRadius =
      BorderRadius.vertical(top: Radius.circular(sheetTop));
}

/// 阴影：极轻，靠浅色和留白撑层次，像纸片浮起
abstract final class AppShadows {
  static const card = [
    BoxShadow(
      color: Color(0x0F2E3A36),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];
  static const cardHover = [
    BoxShadow(
      color: Color(0x1A2E3A36),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
  static const dialog = [
    BoxShadow(
      color: Color(0x242E3A36),
      blurRadius: 40,
      offset: Offset(0, 16),
    ),
  ];
  static const bottomBar = [
    BoxShadow(
      color: Color(0x0F2E3A36),
      blurRadius: 16,
      offset: Offset(0, -4),
    ),
  ];

  /// 深色模式用描边替代阴影
  static const darkBorder = BorderSide(color: Color(0x0AFFFFFF), width: 1);
}
