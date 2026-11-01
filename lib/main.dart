// 手欠（Poke）— 本地待办事项 App
//
// 入口：初始化后台服务通信端口、SharedPreferences，
// 装配 Riverpod 容器与主题（亮/暗双主题，跟随系统）。
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/todo_provider.dart';
import 'screens/home_screen.dart';
import 'services/notice_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 后台摇一摇服务的主 isolate 通信端口
  FlutterForegroundTask.initCommunicationPort();

  // 本地通知（摇一摇抽中任务提醒）
  await NoticeService.init();

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const PokeApp(),
    ),
  );
}

class PokeApp extends StatelessWidget {
  const PokeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '手欠',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
      builder: (context, child) {
        // 状态栏样式跟随主题
        return AnnotatedRegion(
          value: AppTheme.overlayStyle(Theme.of(context).brightness),
          child: child!,
        );
      },
    );
  }
}
