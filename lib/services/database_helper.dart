import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/task_item.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('task_alert.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE tasks ADD COLUMN alarmSoundType TEXT DEFAULT "default"');
          await db.execute('ALTER TABLE tasks ADD COLUMN alarmSoundName TEXT DEFAULT "Default Alarm Sound"');
          await db.execute('ALTER TABLE tasks ADD COLUMN alarmSoundUri TEXT DEFAULT "default_alarm"');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE tasks ADD COLUMN completedAt TEXT');
        }
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE tasks ADD COLUMN reminderEnabled INTEGER DEFAULT 1');
        }
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const textType = 'TEXT NOT NULL';
    const integerType = 'INTEGER NOT NULL';

    await db.execute('''
      CREATE TABLE tasks (
        id $textType PRIMARY KEY,
        title $textType,
        description TEXT,
        scheduledDateTime $textType,
        category $textType,
        priority $textType,
        isCompleted $integerType,
        createdAt $textType,
        alarmSoundType TEXT DEFAULT 'default',
        alarmSoundName TEXT DEFAULT 'Default Alarm Sound',
        alarmSoundUri TEXT DEFAULT 'default_alarm',
        completedAt TEXT,
        reminderEnabled INTEGER DEFAULT 1
      )
    ''');
  }

  /// Insert a new task or update an existing task safely
  Future<void> insertTask(TaskItem task) async {
    final db = await instance.database;
    await db.insert(
      'tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieve all tasks from the SQLite database
  Future<List<TaskItem>> getAllTasks() async {
    final db = await instance.database;
    final result = await db.query('tasks', orderBy: 'scheduledDateTime ASC');
    return result.map((json) => TaskItem.fromMap(json)).toList();
  }

  /// Retrieve a single task by ID
  Future<TaskItem?> getTaskById(String id) async {
    final db = await instance.database;
    final result = await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return TaskItem.fromMap(result.first);
  }

  /// Update an existing task in the database
  Future<void> updateTask(TaskItem task) async {
    final db = await instance.database;
    await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  /// Delete a task by ID
  Future<void> deleteTask(String id) async {
    final db = await instance.database;
    await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Close database connection
  Future<void> close() async {
    final db = await instance.database;
    await db.close();
  }
}
