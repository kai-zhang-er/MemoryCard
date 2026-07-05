import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/memory_record.dart';

class MemoryRepository {
  MemoryRepository({
    DatabaseFactory? databaseFactory,
    String? databasePath,
  })  : _databaseFactory = databaseFactory,
        _databasePath = databasePath;

  static const String tableName = 'memory_records';
  static const String databaseName = 'memory_cards.db';

  final DatabaseFactory? _databaseFactory;
  final String? _databasePath;
  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }

    final dbPath = _databasePath ?? await _defaultDatabasePath();
    final factory = _databaseFactory;
    final opened = factory == null
        ? await openDatabase(
            dbPath,
            version: 1,
            onCreate: _createDatabase,
          )
        : await factory.openDatabase(
            dbPath,
            options: OpenDatabaseOptions(
              version: 1,
              onCreate: _createDatabase,
            ),
          );
    _database = opened;
    return opened;
  }

  Future<void> upsert(MemoryRecord record) async {
    final db = await database;
    await db.insert(
      tableName,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MemoryRecord>> getAll() async {
    final db = await database;
    final rows = await db.query(tableName, orderBy: 'updated_at DESC');
    return rows.map(MemoryRecord.fromMap).toList(growable: false);
  }

  Future<MemoryRecord?> getByMemoryId(String memoryId) => getById(memoryId);

  Future<MemoryRecord?> getById(String memoryId) async {
    final db = await database;
    final rows = await db.query(
      tableName,
      where: 'memory_id = ?',
      whereArgs: [memoryId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return MemoryRecord.fromMap(rows.first);
  }

  Future<MemoryRecord?> getByAssetId(String assetId) async {
    final db = await database;
    final rows = await db.query(
      tableName,
      where: 'asset_id = ?',
      whereArgs: [assetId],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return MemoryRecord.fromMap(rows.first);
  }

  Future<List<MemoryRecord>> getImportant() async {
    return _getWhereFlag('important');
  }

  Future<List<MemoryRecord>> getDeleteCandidates() async {
    return _getWhereFlag('delete_candidate');
  }

  Future<int> update(MemoryRecord record) async {
    final db = await database;
    return db.update(
      tableName,
      record.toMap(),
      where: 'memory_id = ?',
      whereArgs: [record.memoryId],
    );
  }

  Future<int> deleteByMemoryId(String memoryId) => deleteById(memoryId);

  Future<int> deleteById(String memoryId) async {
    final db = await database;
    return db.delete(
      tableName,
      where: 'memory_id = ?',
      whereArgs: [memoryId],
    );
  }

  Future<void> close() async {
    final existing = _database;
    if (existing != null) {
      await existing.close();
      _database = null;
    }
  }

  Future<List<MemoryRecord>> _getWhereFlag(String flagColumn) async {
    final db = await database;
    final rows = await db.query(
      tableName,
      where: '$flagColumn = ?',
      whereArgs: [1],
      orderBy: 'updated_at DESC',
    );
    return rows.map(MemoryRecord.fromMap).toList(growable: false);
  }

  Future<String> _defaultDatabasePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return p.join(directory.path, databaseName);
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableName (
        memory_id TEXT PRIMARY KEY,
        asset_id TEXT NOT NULL,
        asset_fingerprint TEXT,
        media_type TEXT NOT NULL,
        photo_time TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        important INTEGER NOT NULL DEFAULT 0,
        delete_candidate INTEGER NOT NULL DEFAULT 0,
        skipped INTEGER NOT NULL DEFAULT 0,
        user_tags TEXT NOT NULL DEFAULT '[]',
        ai_light_tags TEXT NOT NULL DEFAULT '[]',
        prompt_question TEXT NOT NULL,
        audio_path TEXT,
        transcript TEXT NOT NULL DEFAULT '',
        memory_text TEXT NOT NULL DEFAULT '',
        review_status TEXT NOT NULL DEFAULT 'raw'
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_memory_records_asset_id ON $tableName(asset_id)',
    );
    await db.execute(
      'CREATE INDEX idx_memory_records_important ON $tableName(important)',
    );
    await db.execute(
      'CREATE INDEX idx_memory_records_delete_candidate '
      'ON $tableName(delete_candidate)',
    );
  }
}
