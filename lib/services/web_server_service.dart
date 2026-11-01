// 局域网 Web 控制台服务：手机开启 HTTP 服务（shelf），
// PC 浏览器登录后可增删改查、批量导入（CSV/XLSX/JSON）、导出 CSV/JSON。
// 认证采用挑战-响应，所有数据仍只在手机本地。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart' as xls;
import 'package:flutter/services.dart' show rootBundle;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../models/todo_item.dart';
import '../utils/constants.dart';
import '../utils/csv.dart';
import '../utils/date_utils.dart';
import 'db_service.dart';
import 'pc_auth.dart';

/// 局域网 Web 控制台服务：
/// 手机开启 HTTP 服务，PC 浏览器登录后可增删改查、批量导入导出。
class WebServerService {
  WebServerService({
    required this.dbService,
    required this.auth,
    this.onDataChanged,
    this.onDelete,
    this.onSyncCalendar,
  });

  final DbService dbService;
  final PcAuth auth;

  /// 数据变化后回调（刷新 App 内列表）
  final void Function()? onDataChanged;

  /// 删除事项时的额外清理（如删除日历事件）
  final Future<void> Function(TodoItem todo)? onDelete;

  /// 写入（创建/更新/完成）后的日历同步回调，与 App 端共用同一套同步逻辑。
  /// 返回非 null 表示同步失败原因，会随响应的 calendar_warning 字段带给页面。
  final Future<String?> Function(TodoItem todo)? onSyncCalendar;

  static const _uuid = Uuid();
  HttpServer? _server;
  String? _pageCache;

  bool get isRunning => _server != null;

  int? get port => _server?.port;

  /// 启动服务，返回访问地址
  Future<String> start({int port = webServerPort}) async {
    if (_server != null) return await url ?? '';
    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(_router.call);
    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    return await url ?? '';
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  /// 访问地址（如 http://192.168.1.5:8080）
  Future<String?> get url async {
    final server = _server;
    if (server == null) return null;
    final ip = await localIp();
    return 'http://${ip ?? 'localhost'}:${server.port}';
  }

  /// 手机在局域网中的 IPv4。
  ///
  /// Wi-Fi 与移动数据同时开启时会存在多个网卡，
  /// 这里优先返回 Wi-Fi / 热点网卡（wlan/softap/ap/swlan），
  /// 与 PC 同局域网可访问的地址保持一致；找不到时才回退到第一个非环回地址。
  static Future<String?> localIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      String? fallback;
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.isLoopback) continue;
          final name = interface.name.toLowerCase();
          final isWifi = name.startsWith('wlan') ||
              name.startsWith('softap') ||
              name.startsWith('ap') ||
              name.startsWith('swlan') ||
              name.startsWith('wifi');
          if (isWifi) return address.address;
          fallback ??= address.address;
        }
      }
      return fallback;
    } catch (_) {}
    return null;
  }

  void revokeAllSessions() => auth.revokeAllSessions();

  // ---------- 路由 ----------
  Router get _router {
    final router = Router();

    router.get('/', _handlePage);
    router.get('/api/auth/challenge', _handleChallenge);
    router.post('/api/login', _handleLogin);

    router.post('/api/logout', _authed(_handleLogout));
    router.get('/api/todos', _authed(_handleList));
    router.post('/api/todos', _authed(_handleCreate));
    router.put('/api/todos/<id>', _authed(_handleUpdate));
    router.post('/api/todos/<id>/complete', _authed(_handleComplete));
    router.delete('/api/todos/<id>', _authed(_handleDelete));
    router.post('/api/import', _authed(_handleImport));
    router.get('/api/export', _authed(_handleExport));

    return router;
  }

  Handler _authed(FutureOr<Response> Function(Request) inner) {
    return (Request request) {
      if (!auth.isValidSession(_tokenFrom(request))) {
        return _json({'error': '未登录或会话已过期'}, status: 401);
      }
      return inner(request);
    };
  }

  String? _tokenFrom(Request request) {
    final cookies = request.headers[HttpHeaders.cookieHeader] ?? '';
    for (final part in cookies.split(';')) {
      final index = part.indexOf('=');
      if (index <= 0) continue;
      if (part.substring(0, index).trim() == 'pc_session_token') {
        return part.substring(index + 1).trim();
      }
    }
    final authHeader = request.headers[HttpHeaders.authorizationHeader] ?? '';
    if (authHeader.startsWith('Bearer ')) {
      return authHeader.substring(7).trim();
    }
    return null;
  }

  // ---------- 页面 ----------
  Future<Response> _handlePage(Request request) async {
    _pageCache ??= await rootBundle.loadString('assets/web/console.html');
    return Response.ok(
      _pageCache,
      headers: {'content-type': 'text/html; charset=utf-8'},
    );
  }

  // ---------- 认证 ----------
  Future<Response> _handleChallenge(Request request) async {
    if (!auth.hasPassword) {
      return _json({'error': '请先在手机 App 中设置 PC 访问密码'}, status: 403);
    }
    return _json({'salt': auth.salt, 'nonce': auth.issueNonce()});
  }

  Future<Response> _handleLogin(Request request) async {
    if (auth.isLocked) {
      final minutes = (auth.lockRemaining?.inMinutes ?? 0) + 1;
      return _json({'error': '尝试次数过多，请 $minutes 分钟后再试'}, status: 429);
    }

    final body = await _readJson(request);
    if (body == null) {
      return _json({'error': '请求体必须是 JSON 对象'}, status: 400);
    }
    final digest = (body['digest'] ?? '').toString();

    if (!auth.verifyLogin(digest)) {
      auth.recordFailure();
      return _json({'error': '密码错误'}, status: 401);
    }

    auth.recordSuccess();
    final token = auth.createSession();
    return _json(
      {'ok': true},
      headers: {
        'set-cookie':
            'pc_session_token=$token; HttpOnly; Path=/; Max-Age=${pcSessionTtl.inSeconds}',
      },
    );
  }

  Future<Response> _handleLogout(Request request) async {
    final token = _tokenFrom(request);
    if (token != null) auth.revokeSession(token);
    // 注意：清除 Cookie 必须走响应头，放在 JSON 体里浏览器不会处理
    return _json(
      {'ok': true},
      headers: {
        'set-cookie': 'pc_session_token=; HttpOnly; Path=/; Max-Age=0',
      },
    );
  }

  // ---------- 增删改查 ----------
  Future<Response> _handleList(Request request) async {
    final todos = await dbService.query();
    return _json({'todos': todos.map((t) => t.toJson()).toList()});
  }

  Future<Response> _handleCreate(Request request) async {
    final body = await _readJson(request);
    if (body == null) {
      return _json({'error': '请求体必须是 JSON 对象'}, status: 400);
    }
    final title = (body['title'] ?? '').toString().trim();
    if (title.isEmpty) return _json({'error': '标题不能为空'}, status: 400);

    final now = DateTime.now();
    final repeatType = RepeatTypeX.fromName(body['repeat_type']?.toString());
    final dueDate = parseFlexibleDate(body['due_date']?.toString());
    final firstDue = dueDate ?? DateTime(now.year, now.month, now.day, 9, 0);
    final desc = body['description']?.toString().trim();

    final todo = TodoItem(
      id: _uuid.v4(),
      title: title,
      description: (desc == null || desc.isEmpty) ? null : desc,
      dueDate: firstDue,
      repeatType: repeatType,
      repeatDays: _parseDays(body['repeat_days']),
      intervalDays: _toInt(body['interval_days'], 1),
      nextDueDate: repeatType == RepeatType.none ? null : firstDue,
      status: TodoStatus.values.firstWhere(
        (e) => e.name == body['status']?.toString(),
        orElse: () => TodoStatus.pending,
      ),
      priority: _toInt(body['priority'], 2),
      createdAt: now,
      updatedAt: now,
    );

    await dbService.insert(todo);
    final calendarWarn = await onSyncCalendar?.call(todo);
    onDataChanged?.call();
    final saved = await dbService.getById(todo.id) ?? todo;
    return _json(
      {
        'todo': saved.toJson(),
        if (calendarWarn != null) 'calendar_warning': calendarWarn,
      },
      status: 201,
    );
  }

  Future<Response> _handleUpdate(Request request) async {
    final id = request.params['id']!;
    final existing = await dbService.getById(id);
    if (existing == null) return _json({'error': '事项不存在'}, status: 404);

    final body = await _readJson(request);
    if (body == null) {
      return _json({'error': '请求体必须是 JSON 对象'}, status: 400);
    }

    final title = body.containsKey('title')
        ? (body['title'] ?? '').toString().trim()
        : existing.title;
    if (title.isEmpty) return _json({'error': '标题不能为空'}, status: 400);

    final repeatType = body.containsKey('repeat_type')
        ? RepeatTypeX.fromName(body['repeat_type']?.toString())
        : existing.repeatType;

    // 截止时间：显式传 null / 空字符串表示清除
    final hasDue = body.containsKey('due_date');
    DateTime? dueDate = existing.dueDate;
    var clearDue = false;
    if (hasDue) {
      dueDate = parseFlexibleDate(body['due_date']?.toString());
      clearDue = dueDate == null;
    }

    // 备注：显式传 null / 空字符串表示清除
    final hasDesc = body.containsKey('description');
    String? description = existing.description;
    var clearDesc = false;
    if (hasDesc) {
      final desc = body['description']?.toString().trim();
      description = (desc == null || desc.isEmpty) ? null : desc;
      clearDesc = description == null;
    }

    // 不再重复（或截止时间被清除）时同步清空 next_due_date，
    // 否则残留值会让控制台与 App 显示的到期时间不一致
    final clearNextDue =
        repeatType == RepeatType.none || (hasDue && dueDate == null);

    final updated = existing.copyWith(
      title: title,
      description: description,
      clearDescription: clearDesc,
      dueDate: dueDate,
      clearDueDate: clearDue,
      repeatType: repeatType,
      repeatDays: body.containsKey('repeat_days')
          ? _parseDays(body['repeat_days'])
          : existing.repeatDays,
      intervalDays: body.containsKey('interval_days')
          ? _toInt(body['interval_days'], 1)
          : existing.intervalDays,
      nextDueDate: repeatType == RepeatType.none
          ? null
          : (hasDue ? dueDate : existing.nextDueDate),
      clearNextDueDate: clearNextDue,
      status: body.containsKey('status')
          ? TodoStatus.values.firstWhere(
              (e) => e.name == body['status']?.toString(),
              orElse: () => existing.status,
            )
          : existing.status,
      priority: body.containsKey('priority')
          ? _toInt(body['priority'], existing.priority)
          : existing.priority,
      updatedAt: DateTime.now(),
    );

    await dbService.update(updated);
    final calendarWarn = await onSyncCalendar?.call(updated);
    onDataChanged?.call();
    final saved = await dbService.getById(id) ?? updated;
    return _json({
      'todo': saved.toJson(),
      if (calendarWarn != null) 'calendar_warning': calendarWarn,
    });
  }

  Future<Response> _handleComplete(Request request) async {
    final id = request.params['id']!;
    final todo = await dbService.getById(id);
    if (todo == null) return _json({'error': '事项不存在'}, status: 404);
    // 已完成/已归档的事项忽略，避免重复请求把重复事项"复活"排期
    if (todo.status == TodoStatus.completed ||
        todo.status == TodoStatus.archived) {
      return _json({'todo': todo.toJson(), 'skipped': true});
    }

    final completed = applyCompletion(todo, DateTime.now());
    await dbService.update(completed);
    final calendarWarn = await onSyncCalendar?.call(completed);
    onDataChanged?.call();
    final saved = await dbService.getById(id) ?? completed;
    return _json({
      'todo': saved.toJson(),
      if (calendarWarn != null) 'calendar_warning': calendarWarn,
    });
  }

  Future<Response> _handleDelete(Request request) async {
    final id = request.params['id']!;
    final todo = await dbService.getById(id);
    if (todo == null) return _json({'error': '事项不存在'}, status: 404);

    await onDelete?.call(todo);
    await dbService.delete(id);
    onDataChanged?.call();
    return _json({'ok': true});
  }

  // ---------- 批量导入 ----------
  Future<Response> _handleImport(Request request) async {
    final params = request.url.queryParameters;
    final name = params['name'] ?? 'import.csv';
    final dryRun = params['dryRun'] == '1';

    const maxImportBytes = 20 * 1024 * 1024;
    final bytes = <int>[];
    await for (final chunk in request.read()) {
      bytes.addAll(chunk);
      if (bytes.length > maxImportBytes) {
        return _json({'error': '导入文件过大（上限 20MB）'}, status: 413);
      }
    }

    final List<Map<String, String>> rows;
    try {
      rows = _parseImportRows(name, bytes);
    } catch (e) {
      return _json({'error': '解析失败：$e'}, status: 400);
    }

    if (dryRun) {
      return _json({'rows': rows, 'total': rows.length});
    }

    final now = DateTime.now();
    final inserted = <Map<String, dynamic>>[];
    final failed = <Map<String, dynamic>>[];

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final title = (row['title'] ?? '').trim();
      if (title.isEmpty) {
        failed.add({'index': i, 'title': title, 'error': '标题为空'});
        continue;
      }
      try {
        final repeatType = RepeatTypeX.fromName(row['repeat_type']);
        final dueDate = parseFlexibleDate(row['due_date']);
        final firstDue = dueDate ?? DateTime(now.year, now.month, now.day, 9, 0);
        // 保留导出文件里的排期状态（JSON 导出含 next_due_date / last_done_at），
        // 重导入重复事项时不把排期重置回原始到期时间
        final nextDue = parseFlexibleDate(row['next_due_date']);
        final lastDone = parseFlexibleDate(row['last_done_at']);
        final todo = TodoItem(
          id: _uuid.v4(),
          title: title,
          description: (row['description'] ?? '').isEmpty
              ? null
              : row['description'],
          dueDate: firstDue,
          repeatType: repeatType,
          repeatDays: _parseDays(row['repeat_days']),
          intervalDays: int.tryParse(row['interval_days'] ?? '') ?? 1,
          lastDoneAt: lastDone,
          nextDueDate: repeatType == RepeatType.none
              ? null
              : (nextDue ?? firstDue),
          status: TodoStatus.values.firstWhere(
            (e) => e.name == row['status'],
            orElse: () => TodoStatus.pending,
          ),
          priority: int.tryParse(row['priority'] ?? '') ?? 2,
          createdAt: now,
          updatedAt: now,
        );
        await dbService.insert(todo);
        inserted.add(todo.toJson());
      } catch (e) {
        failed.add({'index': i, 'title': title, 'error': '$e'});
      }
    }

    onDataChanged?.call();
    return _json({
      'inserted': inserted.length,
      'failed': failed,
      'total': rows.length,
    });
  }

  List<Map<String, String>> _parseImportRows(String name, List<int> bytes) {
    final lower = name.toLowerCase();

    if (lower.endsWith('.json')) {
      final list = jsonDecode(utf8.decode(bytes)) as List;
      return list
          .map((e) => (e as Map).map(
                (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
              ))
          .toList();
    }

    if (lower.endsWith('.xlsx')) {
      final excel = xls.Excel.decodeBytes(bytes);
      final rows = <Map<String, String>>[];
      for (final sheetName in excel.tables.keys) {
        final sheet = excel.tables[sheetName];
        if (sheet == null) continue;
        List<String>? headers;
        for (final row in sheet.rows) {
          final cells = row.map(_cellText).toList();
          if (cells.every((c) => c.trim().isEmpty)) continue;
          if (headers == null) {
            headers = cells.map((c) => c.trim().toLowerCase()).toList();
            continue;
          }
          rows.add(_rowToMap(headers, cells));
        }
        break; // 仅导入第一个工作表
      }
      return rows;
    }

    // 默认按 CSV 处理
    final text = utf8.decode(bytes, allowMalformed: true);
    final table = parseCsv(text);
    if (table.isEmpty) return <Map<String, String>>[];
    final headers =
        table.first.map((h) => h.trim().toLowerCase()).toList();
    return table
        .skip(1)
        .map((cells) => _rowToMap(headers, cells))
        .where((row) => (row['title'] ?? '').trim().isNotEmpty)
        .toList();
  }

  Map<String, String> _rowToMap(List<String> headers, List<String> cells) {
    final map = <String, String>{};
    for (var i = 0; i < headers.length; i++) {
      map[headers[i]] = i < cells.length ? cells[i] : '';
    }
    return map;
  }

  String _cellText(xls.Data? cell) {
    final value = cell?.value;
    if (value == null) return '';
    if (value is xls.TextCellValue) return value.value.toString();
    if (value is xls.IntCellValue) return value.value.toString();
    if (value is xls.DoubleCellValue) return value.value.toString();
    if (value is xls.BoolCellValue) return value.value.toString();
    if (value is xls.DateTimeCellValue) {
      final v = value;
      return DateTime(v.year, v.month, v.day, v.hour, v.minute, v.second)
          .toIso8601String();
    }
    return value.toString();
  }

  List<int> _parseDays(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw.map((e) => int.tryParse('$e')).whereType<int>().toList();
    }
    return raw
        .toString()
        .replaceAll(RegExp(r'[\[\]]'), '')
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList();
  }

  // ---------- 导出 ----------
  Future<Response> _handleExport(Request request) async {
    final format = request.url.queryParameters['format'] ?? 'csv';
    final todos = await dbService.query();

    if (format == 'json') {
      return Response.ok(
        const JsonEncoder.withIndent('  ')
            .convert(todos.map((t) => t.toJson()).toList()),
        headers: {
          'content-type': 'application/json; charset=utf-8',
          'content-disposition': 'attachment; filename="todos.json"',
        },
      );
    }

    const headers = [
      'title',
      'description',
      'due_date',
      'repeat_type',
      'repeat_days',
      'interval_days',
      'status',
      'priority',
    ];
    final rows = <List<String>>[
      headers,
      for (final t in todos)
        [
          t.title,
          t.description ?? '',
          // 导出当前生效的到期时间：重复事项重导入后排期不回退
          t.effectiveDue?.toIso8601String() ?? '',
          t.repeatType.storageName,
          t.repeatDays.join(','),
          '${t.intervalDays}',
          t.status.name,
          '${t.priority}',
        ],
    ];

    // BOM 让 Excel 正确识别 UTF-8
    return Response.ok(
      '\uFEFF${toCsv(rows)}',
      headers: {
        'content-type': 'text/csv; charset=utf-8',
        'content-disposition': 'attachment; filename="todos.csv"',
      },
    );
  }

  // ---------- 工具 ----------
  /// 读取 JSON 对象请求体；非法 JSON 或非对象返回 null（由调用方回 400）
  Future<Map<String, dynamic>?> _readJson(Request request) async {
    try {
      final decoded = jsonDecode(await request.readAsString());
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  /// 宽容取整：数字或数字字符串均可
  int _toInt(dynamic value, int fallback) {
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? fallback;
  }

  Response _json(
    Map<String, dynamic> body, {
    int status = 200,
    Map<String, String>? headers,
  }) {
    return Response(
      status,
      body: jsonEncode(body),
      headers: {
        'content-type': 'application/json; charset=utf-8',
        if (headers != null) ...headers,
      },
    );
  }
}
