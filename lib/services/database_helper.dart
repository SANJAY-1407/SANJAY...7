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
      version: 1,
      onCreate: _createDB,
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
        createdAt $textType
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

  /// Seed initial sample tasks ONLY on first launch if the database is empty
  Future<void> seedInitialTasksIfEmpty() async {
    final existingTasks = await getAllTasks();
    if (existingTasks.isNotEmpty) return;

    final now = DateTime.now();
    final initialSampleTasks = [
      TaskItem(
        id: '1',
        title: 'Review Project Architecture & Specs',
        description: 'Read system specifications and component diagrams.',
        scheduledDateTime: DateTime(now.year, now.month, now.day, 10, 0),
        category: 'Work',
        priority: 'High',
        isCompleted: false,
      ),
      TaskItem(
        id: '2',
        title: 'Complete Weekly Learning Module',
        description: 'Study Dart async patterns and state management.',
        scheduledDateTime: DateTime(now.year, now.month, now.day, 14, 30),
        category: 'Study',
        priority: 'High',
        isCompleted: true,
      ),
      TaskItem(
        id: '3',
        title: 'Pay Utility Invoices & Electricity Bill',
        description: 'Settle monthly electric and internet bills.',
        scheduledDateTime: now.subtract(const Duration(hours: 3)),
        category: 'Bills',
        priority: 'High',
        isCompleted: false,
      ),
      TaskItem(
        id: '4',
        title: 'Evening Fitness & Gym Workout',
        description: '30 mins cardio and core exercises.',
        scheduledDateTime: DateTime(now.year, now.month, now.day, 18, 30),
        category: 'Fitness',
        priority: 'Low',
        isCompleted: false,
      ),
      TaskItem(
        id: '5',
        title: 'Client Presentation & Demo Slides',
        description: 'Prepare prototype demo for stakeholders.',
        scheduledDateTime: DateTime(now.year, now.month, now.day + 1, 10, 0),
        category: 'Work',
        priority: 'Medium',
        isCompleted: false,
      ),
    ];

    for (final task in initialSampleTasks) {
      await insertTask(task);
    }
  }

  /// Close database connection
  Future<void> close() async {
    final db = await instance.database;
    await db.close();
  }
}
