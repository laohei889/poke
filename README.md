# 手欠 🫧

> **没事就手欠，手欠就有事** · *Can't help poking? Then get things done.*
>
> 一款 **数据全本地** 的 Android 待办 App：摇一摇随机抽任务、接入系统日历提醒、
> 手机开局域网 Web 控制台让 PC 浏览器批量管理待办。

技术栈：**Flutter + SQLite（sqflite）+ shelf 局域网 HTTP 服务 + Android 前台服务**。

---

## 功能

| 模块 | 说明 |
|------|------|
| 📝 简洁录入 | 底部快速输入栏，回车即创建；`[今天] [明天] [每周] [定时] [更多]` 快捷标签 |
| 🔁 重复事项 | 每天 / 工作日 / 每周几 / 每月 / 每隔 N 天；完成后复用同一条记录自动排期回待办池 |
| 📅 系统日历提醒 | 待办写入系统日历事件（默认提前 15 分钟提醒），由系统负责通知 |
| 🍾 摇一摇抽任务 | 加速度阈值触发，按权重随机（高优先级 +3 / 当天到期 +2 / 已逾期 +5），弹出卡片 [接受 / 换一个] |
| 🔒 后台摇一摇 | 可选开关（默认关闭）：前台服务常驻监听，锁屏摇动出通知；点开 App 直接看卡片 |
| 🔄 状态流转 | `pending →（摇一摇接受）→ inProgress →（下次打开询问）→ 完成归档 / 重复排期 / 回到池子` |
| 💻 局域网 Web 控制台 | PC 浏览器登录后增删改查、批量导入（CSV/XLSX/JSON，先预览后导入）、一键导出 CSV/JSON |
| 🛡 认证安全 | 密码加盐哈希存储 + 挑战-响应登录（不明文传输）；会话 24h 有效，可一键撤销；连错 5 次锁定 10 分钟 |

---

## 设计语言

视觉原点：**被戳凹的薄荷绿果冻球**（图标方案 A「戳泡泡」· 无手 · 清爽版）。

- **主色**：薄荷绿 `#3DDC97`，只承担「行动 / 选中 / 完成」三类语义 —— 绿色是“点”不是“面”；
- **形状**：全面圆角（卡片 20 / 弹窗 24 / 按钮胶囊 / 圆形勾选框），禁止直角；
- **动效**：出现/确认带轻微 overshoot（`Curves.easeOutBack`，果冻回弹），消失/取消干净利落；
- **优先级**：同色相深浅圆点（高实心 / 中浅空心 / 低灰空心），红色只留给“逾期”；
- **Token**：`lib/theme/`（app_colors / app_spacing / app_motion / app_typography / app_theme_extension / app_theme），组件层不出现硬编码色值，支持深色模式；
- **图标**：`assets/icon/app_icon.svg`（1024 源文件）+ Android 自适应图标（透明前景层 + `#F5FBF8` 背景）；
- **延展**：果冻球复用为空状态插画、摇一摇结果卡片主视觉（JellyBall 组件）。

---

## 快速开始

```bash
# 1. 环境：Flutter 3.24+（Android SDK 已配置）
flutter pub get

# 2. 运行到真机（摇一摇、日历、前台服务需要真机）
flutter run

# 3. 打包 APK
flutter build apk --release
```

> 项目已内置 Android 平台目录与权限配置；iOS 未做适配（方案定位 Android 优先）。

---

## 局域网 Web 控制台使用

1. App 内打开 **PC 局域网控制台** → 设置访问密码（≥ 6 位）→ 开启服务；
2. 手机与 PC 连接同一 Wi-Fi（或手机开热点），浏览器访问屏幕上的地址
   （如 `http://192.168.1.5:8080`，也可扫二维码）；
3. 输入密码登录后即可管理待办、批量导入导出。

### 批量导入格式（CSV）

```csv
title,description,due_date,repeat_type,repeat_days,interval_days,status,priority
买牛奶,,2026-10-22 18:00,daily,,1,pending,2
还信用卡,,2026-10-25 09:00,monthly,,1,pending,3
健身,一周三次,2026-10-26 19:00,weekly,"2,4,6",1,pending,2
```

- `repeat_type`：`none / daily / workday / weekly / monthly / customInterval`
- `repeat_days`：每周几（1=周一 … 7=周日），多个用逗号分隔，仅 `weekly` 生效
- `status`：`pending / inProgress / completed / archived`，可留空默认 `pending`
- 同时支持 `.xlsx` 与 `.json`；导入前会先预览，确认后才写入数据库

---

## 项目结构

```
lib/
├── main.dart                       # 入口：主题、本地化、Riverpod 容器
├── theme/                          # 设计 Token（颜色/间距/动效/字体/ThemeExtension/ThemeData）
├── models/todo_item.dart           # 数据模型 + 状态/重复枚举
├── providers/
│   ├── todo_provider.dart          # 待办状态机（创建/完成/接受/抽签/排期）
│   └── web_provider.dart           # Web 服务单例
├── screens/
│   ├── home_screen.dart            # 列表 + 过滤 + 启动询问 inProgress
│   ├── add_todo_screen.dart        # 完整录入/编辑表单
│   ├── shake_screen.dart           # 摇一摇漂流瓶
│   ├── web_console_screen.dart     # Web 服务开关 / 地址二维码 / 密码管理
│   └── settings_screen.dart        # 后台摇一摇、日历、关于
├── services/
│   ├── db_service.dart             # SQLite
│   ├── calendar_service.dart       # 系统日历（device_calendar）
│   ├── shake_service.dart          # 加速度摇动检测
│   ├── foreground_shake_service.dart # 后台前台服务（可选）
│   ├── web_server_service.dart     # shelf 路由 + 导入导出
│   └── pc_auth.dart                # 密码哈希 / 挑战-响应 / 会话
├── widgets/                        # 快速录入栏、列表项、果冻球、重复规则弹窗等
└── utils/                          # 日期排期、CSV、常量
assets/icon/                        # 图标 SVG 源文件（果冻球）
assets/web/console.html             # PC 端 Web 控制台页面
```

---

## 核心逻辑

**重复事项复用**（完成后不新建记录，直接排期回池子）：

```dart
void onComplete(TodoItem todo) {
  final now = DateTime.now();
  todo.lastDoneAt = now;
  if (todo.repeatType == RepeatType.none) {
    todo.status = TodoStatus.archived;          // 单次归档
  } else {
    todo.nextDueDate = calculateNextDueDate(todo); // 排到下一次
    todo.status = TodoStatus.pending;           // 回到抽取池
  }
}
```

**登录挑战-响应**（密码不上网络）：

```
App 保存：verifier = sha256(password + salt)
登录时：  服务端下发 salt + nonce
PC  端：  digest = sha256(sha256(password + salt) + nonce)
服务端：  用本地 verifier + 同一 nonce 复算比对 → 发放 24h 会话 Token（Cookie）
```

---

## 权限

| 权限 | 用途 |
|------|------|
| `READ/WRITE_CALENDAR` | 写入系统日历提醒 |
| `INTERNET` / `ACCESS_NETWORK_STATE` | 局域网 Web 服务 |
| `POST_NOTIFICATIONS` | 前台服务通知（Android 13+ 运行时申请） |
| `FOREGROUND_SERVICE(_SPECIAL_USE)` | 后台摇一摇前台服务 |
| `VIBRATE` / `WAKE_LOCK` | 震动反馈、监听期间保持唤醒 |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | 引导加入电池优化白名单，避免服务被杀 |
| `RECEIVE_BOOT_COMPLETED` | 开机后恢复后台服务（仅在用户开启后台摇一摇时） |

---

## 已知取舍

1. **数据不加密**：全部明文存 SQLite，敏感场景可后续引入 SQLCipher；
2. **后台摇一摇耗电**：默认关闭，设置页有明确提示；
3. **国产 ROM 清理**：可能杀掉前台服务，建议引导用户加白名单；
4. **局域网 IP 会变**：每次开启服务动态显示 IP + 二维码；
5. **iOS 未适配**：`device_calendar`、前台服务等按 Android 优先实现。
