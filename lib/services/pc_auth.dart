// PC 端访问认证：密码加盐哈希存储 + 挑战-响应登录（不明文传输），
// 会话 Token 有效期 24 小时，连错 5 次锁定 10 分钟。
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../utils/constants.dart';

/// PC 端访问认证：
/// - 密码以 `sha256(password + salt)`（verifier）形式存储，不存明文
/// - 登录采用挑战-响应：客户端提交 `sha256(verifier + nonce)`，避免明文传输密码
/// - 会话 Token 有效期 24 小时，可一键撤销
class PcAuth {
  PcAuth(this._prefs);

  final SharedPreferences _prefs;
  static const _uuid = Uuid();

  // ---------- 密码 ----------
  bool get hasPassword => (_prefs.getString(prefKeyPcPwdHash) ?? '').isNotEmpty;

  String get salt => _prefs.getString(prefKeyPcPwdSalt) ?? '';

  String get _verifier => _prefs.getString(prefKeyPcPwdHash) ?? '';

  /// 设置 / 重置访问密码（最少 6 位）
  Future<void> setPassword(String password) async {
    final newSalt = _randomToken(16);
    await _prefs.setString(prefKeyPcPwdSalt, newSalt);
    await _prefs.setString(prefKeyPcPwdHash, verifier(password, newSalt));
  }

  /// verifier = sha256(password + salt)
  static String verifier(String password, String salt) =>
      sha256.convert(utf8.encode(password + salt)).toString();

  /// 客户端登录摘要 = sha256(verifier + nonce)
  static String loginDigest(String password, String salt, String nonce) =>
      sha256.convert(utf8.encode(verifier(password, salt) + nonce)).toString();

  // ---------- 挑战-响应 ----------
  String? _pendingNonce;
  DateTime? _pendingNonceExpires;

  /// 一次性登录挑战
  String issueNonce() {
    final nonce = _randomToken(24);
    _pendingNonce = nonce;
    _pendingNonceExpires = DateTime.now().add(loginNonceTtl);
    return nonce;
  }

  /// 校验登录摘要，成功返回 true 并使 nonce 失效
  bool verifyLogin(String digest) {
    final nonce = _pendingNonce;
    if (nonce == null || _pendingNonceExpires == null) return false;
    if (DateTime.now().isAfter(_pendingNonceExpires!)) return false;

    _pendingNonce = null;
    _pendingNonceExpires = null;

    final expected =
        sha256.convert(utf8.encode(_verifier + nonce)).toString();
    return _constantTimeEquals(expected, digest);
  }

  // ---------- 登录锁定 ----------
  int _failedAttempts = 0;
  DateTime? _lockedUntil;

  bool get isLocked =>
      _lockedUntil != null && DateTime.now().isBefore(_lockedUntil!);

  Duration? get lockRemaining {
    if (!isLocked) return null;
    return _lockedUntil!.difference(DateTime.now());
  }

  void recordFailure() {
    _failedAttempts++;
    if (_failedAttempts >= maxLoginAttempts) {
      _lockedUntil = DateTime.now().add(loginLockDuration);
      _failedAttempts = 0;
    }
  }

  void recordSuccess() {
    _failedAttempts = 0;
    _lockedUntil = null;
  }

  // ---------- 会话 ----------
  final Map<String, DateTime> _sessions = {};

  int get activeSessionCount => _sessions.length;

  String createSession() {
    final token = _uuid.v4();
    _sessions[token] = DateTime.now().add(pcSessionTtl);
    return token;
  }

  bool isValidSession(String? token) {
    if (token == null || token.isEmpty) return false;
    final expiresAt = _sessions[token];
    if (expiresAt == null) return false;
    if (DateTime.now().isAfter(expiresAt)) {
      _sessions.remove(token);
      return false;
    }
    // 有效则顺延过期时间
    _sessions[token] = DateTime.now().add(pcSessionTtl);
    return true;
  }

  void revokeSession(String token) => _sessions.remove(token);

  void revokeAllSessions() => _sessions.clear();

  // ---------- 工具 ----------
  static String _randomToken(int bytes) {
    final rng = Random.secure();
    final data = List<int>.generate(bytes, (_) => rng.nextInt(256));
    return base64UrlEncode(data).replaceAll('=', '');
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
