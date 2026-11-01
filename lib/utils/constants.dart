// 全局常量
library;

/// 摇一摇判定参数
/// 单个峰值阈值：加速度模长偏离重力（约 9.8 m/s²）超过该值记一次峰值。
const double shakeDeltaThreshold = 4.5;

/// 1.2 秒窗口内需要 3 次峰值才算一次有效摇动——
/// 区分「有意摇动」与「放口袋/走路颠簸」等单次大幅动作。
const int shakeRequiredPeaks = 3;
const Duration shakePeakWindow = Duration(milliseconds: 1200);

/// 两次摇动之间的冷却时间，防止连续误触发
const Duration shakeCooldown = Duration(seconds: 2);

/// 后台摇一摇前台服务通知
const String foregroundNotificationTitle = '摇一摇待办服务运行中';
const String foregroundNotificationText = '摇一摇手机即可随机抽一个待办';

/// Web 控制台
const int webServerPort = 8080;
const Duration pcSessionTtl = Duration(hours: 24);
const Duration loginNonceTtl = Duration(minutes: 5);
const int maxLoginAttempts = 5;
const Duration loginLockDuration = Duration(minutes: 10);

/// SharedPreferences 键
const String prefKeyPcPwdSalt = 'pc_pwd_salt';
const String prefKeyPcPwdHash = 'pc_pwd_hash';
const String prefKeyBackgroundShake = 'background_shake_enabled';
const String prefKeyCalendarId = 'calendar_id';
const String prefKeyCalendarSync = 'calendar_sync_enabled';
