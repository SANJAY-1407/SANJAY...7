import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/clock_alarm.dart';

/// Dedicated SQLite helper for Clock-Style Alarms.
/// Operates on an isolated database ('task_alert_clock_alarms.db') so that
/// existing task records and DatabaseHelper are completely decoupled and safe.
class ClockAlarmDatabaseHelper {
  static final ClockAlarmDatabaseHelper instance = ClockAlarmDatabaseHelper._init();
  static Database? _database;

  ClockAlarmDatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('task_alert_clock_alarms.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const textType = 'TEXT NOT NULL';
    const integerType = 'INTEGER NOT NULL';

    await db.execute('''
      CREATE TABLE clock_alarms (
        id $textType PRIMARY KEY,
        numericId $integerType,
        hour $integerType,
        minute $integerType,
        label TEXT,
        isEnabled $integerType,
        repeatDays TEXT,
        soundType TEXT,
        soundName TEXT,
        soundUri TEXT,
        snoozeMinutes $integerType,
        vibrate $integerType,
        createdAt $textType
      )
    ''');
  }

  /// Allocates the next available integer ID for deterministic notification scheduling
  Future<int> getNextNumericId() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT MAX(numericId) as maxId FROM clock_alarms');
    final maxId = result.first['maxId'] as int?;
    if (maxId == null || maxId < 1) {
      return 1;
    }
    return maxId + 1;
  }

  /// Insert a new alarm
  Future<void> insertAlarm(ClockAlarm alarm) async {
    final db = await instance.database;
    await db.insert(
      'clock_alarms',
      alarm.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieve all alarms, ordered by time of day
  Future<List<ClockAlarm>> getAllAlarms() async {
    final db = await instance.database;
    final result = await db.query(
      'clock_alarms',
      orderBy: 'hour ASC, minute ASC',
    );
    return result.map((json) => ClockAlarm.fromMap(json)).toList();
  }

  /// Retrieve a single alarm by ID
  Future<ClockAlarm?> getAlarmById(String id) async {
    final db = await instance.database;
    final result = await db.query(
      'clock_alarms',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return ClockAlarm.fromMap(result.first);
  }

  /// Update an existing alarm
  Future<void> updateAlarm(ClockAlarm alarm) async {
    final db = await instance.database;
    await db.update(
      'clock_alarms',
      alarm.toMap(),
      where: 'id = ?',
      whereArgs: [alarm.id],
    );
  }

  /// Delete an alarm by ID
  Future<void> deleteAlarm(String id) async {
    final db = await instance.database;
    await db.delete(
      'clock_alarms',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Finds the earliest upcoming enabled alarm, or null if none are enabled.
  Future<ClockAlarm?> getNextActiveAlarm() async {
    final allAlarms = await getAllAlarms();
    final enabledAlarms = allAlarms.where((a) => a.isEnabled).toList();
    if (enabledAlarms.isEmpty) return null;

    final now = DateTime.now();
    enabledAlarms.sort((a, b) {
      final aNext = a.getNextOccurrence(now);
      final bNext = b.getNextOccurrence(now);
      return aNext.compareTo(bNext);
    });

    return enabledAlarms.first;
  }

  /// Close the database
  Future<void> close() async {
    final db = await instance.database;
    await db.close();
    _database = null;
  }
}
