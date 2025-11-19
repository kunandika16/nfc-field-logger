import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/scan_log.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'scan_logs.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE scan_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        address TEXT,
        city TEXT,
        user_name TEXT,
        user_class TEXT,
        device_info TEXT,
        isSynced INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new columns if they do not exist (safe migration)
      final existingColumns = await db.rawQuery('PRAGMA table_info(scan_logs)');
      final names = existingColumns.map((e) => e['name']).toSet();
      if (!names.contains('user_name')) {
        await db.execute('ALTER TABLE scan_logs ADD COLUMN user_name TEXT');
      }
      if (!names.contains('user_class')) {
        await db.execute('ALTER TABLE scan_logs ADD COLUMN user_class TEXT');
      }
      if (!names.contains('device_info')) {
        await db.execute('ALTER TABLE scan_logs ADD COLUMN device_info TEXT');
      }
    }
  }

  // Insert a new scan log
  Future<int> insertScanLog(ScanLog log) async {
    try {
      final db = await database;
      final id = await db.insert('scan_logs', log.toMap());
      return id;
    } catch (e) {
      rethrow;
    }
  }

  // Get all scan logs
  Future<List<ScanLog>> getAllScanLogs() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'scan_logs',
        orderBy: 'timestamp DESC',
      );
      return List.generate(maps.length, (i) => ScanLog.fromMap(maps[i]));
    } catch (e) {
      return [];
    }
  }

  // Get unsynced scan logs
  Future<List<ScanLog>> getUnsyncedLogs() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'scan_logs',
      where: 'isSynced = ?',
      whereArgs: [0],
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => ScanLog.fromMap(maps[i]));
  }

  // Update scan log sync status
  Future<int> updateSyncStatus(int id, bool isSynced) async {
    final db = await database;
    return await db.update(
      'scan_logs',
      {'isSynced': isSynced ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Get logs by date range
  Future<List<ScanLog>> getLogsByDateRange(DateTime start, DateTime end) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'scan_logs',
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => ScanLog.fromMap(maps[i]));
  }

  // Search logs by UID
  Future<List<ScanLog>> searchByUid(String uidQuery) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'scan_logs',
      where: 'uid LIKE ?',
      whereArgs: ['%$uidQuery%'],
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => ScanLog.fromMap(maps[i]));
  }

  // Get total scan count
  Future<int> getTotalScanCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT COUNT(*) FROM scan_logs');
      final count = Sqflite.firstIntValue(result) ?? 0;
      return count;
    } catch (e) {
      return 0;
    }
  }

  // Get unsynced count
  Future<int> getUnsyncedCount() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) FROM scan_logs WHERE isSynced = 0');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Get most active city
  Future<String?> getMostActiveCity() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT city, COUNT(*) as count 
      FROM scan_logs 
      WHERE city IS NOT NULL 
        AND city NOT LIKE '%kecamatan%'
        AND city NOT LIKE '%kelurahan%'
        AND city NOT LIKE '%desa%'
      GROUP BY city 
      ORDER BY count DESC 
      LIMIT 1
    ''');
    if (result.isNotEmpty) {
      return result.first['city'] as String?;
    }
    return null;
  }

  // Delete a scan log
  Future<int> deleteScanLog(int id) async {
    final db = await database;
    return await db.delete(
      'scan_logs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Clear all logs
  Future<void> clearAllLogs() async {
    final db = await database;
    await db.delete('scan_logs');
  }

  // Insert dummy data for testing
  Future<void> insertDummyData() async {
    final dummyLog = ScanLog(
      uid: 'AA:BB:CC:DD',
      timestamp: DateTime.now(),
      latitude: -6.2088,
      longitude: 106.8456,
      address: 'Jakarta, Indonesia',
      city: 'Jakarta',
      isSynced: false,
    );
    await insertScanLog(dummyLog);
  }
}
