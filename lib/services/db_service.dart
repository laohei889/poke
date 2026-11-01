// SQLite 数据访问层：所有待办数据只存手机本地，无需联网。
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/todo_item.dart';

/// SQLite 数据访问层：所有待办数据只存手机本地
class DbService {
  static const String _dbName = 'todo_bottle.db';
  static const int _dbVersion = 1;
  static const String tableTodos = 'todos';

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = p.join(await getDatabasesPath(), _dbName);
    return openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tableTodos (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            description TEXT,
            due_date INTEGER,
            repeat_type TEXT NOT NULL DEFAULT 'none',
            repeat_days TEXT NOT NULL DEFAULT '[]',
            interval_days INTEGER NOT NULL DEFAULT 1,
            last_done_at INTEGER,
            next_due_date INTEGER,
            status TEXT NOT NULL DEFAULT 'pending',
            priority INTEGER NOT NULL DEFAULT 2,
            calendar_event_id TEXT,
            accepted_at INTEGER,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_todos_status ON $tableTodos (status)',
        );
      },
    );
  }

  Future<void> insert(TodoItem todo) async {
    final db = await database;
    await db.insert(
      tableTodos,
      todo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(TodoItem todo) async {
    final db = await database;
    await db.update(
      tableTodos,
      todo.toMap(),
      where: 'id = ?',
      whereArgs: [todo.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await database;
    await db.delete(tableTodos, where: 'id = ?', whereArgs: [id]);
  }

  Future<TodoItem?> getById(String id) async {
    final db = await database;
    final rows =
        await db.query(tableTodos, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return TodoItem.fromMap(rows.first);
  }

  /// 查询事项；不传 [status] 返回全部（含归档）
  Future<List<TodoItem>> query({
    TodoStatus? status,
    bool includeArchived = true,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];

    if (status != null) {
      where.add('status = ?');
      args.add(status.name);
    } else if (!includeArchived) {
      where.add('status != ?');
      args.add(TodoStatus.archived.name);
    }

    final rows = await db.query(
      tableTodos,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'priority DESC, '
          'COALESCE(next_due_date, due_date, created_at) ASC',
    );
    return rows.map(TodoItem.fromMap).toList();
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
