// PC 局域网 Web 控制台管理页：启停服务、展示地址与二维码、
// 管理访问密码、撤销会话。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../providers/web_provider.dart';
import '../utils/constants.dart';

/// PC 局域网 Web 控制台：启停服务、显示地址与二维码、管理访问密码
class WebConsoleScreen extends ConsumerStatefulWidget {
  const WebConsoleScreen({super.key});

  @override
  ConsumerState<WebConsoleScreen> createState() => _WebConsoleScreenState();
}

class _WebConsoleScreenState extends ConsumerState<WebConsoleScreen> {
  bool _running = false;
  String? _url;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _running = ref.read(webServerServiceProvider).isRunning;
    if (_running) _refreshUrl();
  }

  Future<void> _refreshUrl() async {
    final url = await ref.read(webServerServiceProvider).url;
    if (mounted) setState(() => _url = url);
  }

  Future<void> _toggleServer() async {
    final service = ref.read(webServerServiceProvider);
    setState(() => _busy = true);
    try {
      if (_running) {
        await service.stop();
        setState(() {
          _running = false;
          _url = null;
        });
      } else {
        if (!service.auth.hasPassword) {
          final ok = await _showPasswordDialog();
          if (ok != true) return;
        }
        final url = await service.start(port: webServerPort);
        setState(() {
          _running = true;
          _url = url;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('服务已开启：$url')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('操作失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _showPasswordDialog() {
    final pwdController = TextEditingController();
    final confirmController = TextEditingController();

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置 PC 访问密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'PC 浏览器登录时需要该密码，最少 6 位。\n忘记后只能在 App 内重置，无法远程找回。',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pwdController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '密码（至少 6 位）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '确认密码',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final pwd = pwdController.text;
              if (pwd.length < 6) return;
              if (pwd != confirmController.text) return;
              Navigator.pop(context, true);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ).then((ok) async {
      if (ok == true) {
        await ref.read(webServerServiceProvider).auth.setPassword(pwdController.text);
      }
      pwdController.dispose();
      confirmController.dispose();
      return ok;
    });
  }

  Future<void> _resetPassword() async {
    final ok = await _showPasswordDialog();
    if (ok == true && mounted) {
      ref.read(webServerServiceProvider).revokeAllSessions();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密码已重置，所有 PC 会话已撤销')),
      );
    }
  }

  Future<void> _revokeSessions() async {
    ref.read(webServerServiceProvider).revokeAllSessions();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已撤销全部 PC 会话')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPassword = ref.watch(webServerServiceProvider).auth.hasPassword;

    return Scaffold(
      appBar: AppBar(title: const Text('PC 局域网控制台')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _running ? Icons.wifi_tethering_rounded : Icons.wifi_off_rounded,
                        color: _running ? theme.colorScheme.primary : theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _running ? '服务运行中' : '服务未开启',
                        style: theme.textTheme.titleMedium,
                      ),
                      const Spacer(),
                      Switch(
                        value: _running,
                        onChanged: _busy ? null : (_) => _toggleServer(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _running
                        ? 'PC 与手机连接同一 Wi-Fi（或手机热点），浏览器打开下面的地址：'
                        : '开启后，PC 浏览器可管理待办：增删改查、批量导入导出。',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                  if (_running && _url != null) ...[
                    const SizedBox(height: 14),
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: theme.colorScheme.outlineVariant),
                            ),
                            child: QrImageView(data: _url!, size: 156),
                          ),
                          const SizedBox(height: 12),
                          SelectableText(
                            _url!,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: _url!));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('地址已复制')),
                                );
                              }
                            },
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: const Text('复制地址'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_outline_rounded),
                  title: const Text('访问密码'),
                  subtitle: Text(hasPassword ? '已设置（${'•' * 8}）' : '未设置'),
                  trailing: TextButton(
                    onPressed: _resetPassword,
                    child: Text(hasPassword ? '重置' : '设置'),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.phonelink_lock_rounded),
                  title: const Text('撤销所有 PC 会话'),
                  subtitle: const Text('让所有已登录的浏览器立即退出'),
                  trailing: TextButton(
                    onPressed: _revokeSessions,
                    child: const Text('撤销'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('安全说明', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  const Text(
                    '· 服务只在局域网内可达，不暴露到公网\n'
                    '· 密码以加盐哈希存储，登录采用挑战-响应，不在网络上传输明文密码\n'
                    '· 密码连续输错 5 次将锁定 10 分钟；会话有效期 24 小时\n'
                    '· 数据始终保存在手机本地 SQLite',
                    style: TextStyle(fontSize: 13, height: 1.7),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
