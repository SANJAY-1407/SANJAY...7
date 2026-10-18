class TaskItem {
  final String id;
  final String title;
  final String description;
  final DateTime scheduledDateTime;
  final String category;
  final String priority;
  bool isCompleted;
  final DateTime createdAt;
  final String alarmSoundType; // 'default', 'ringtone', 'custom_song'
  final String alarmSoundName; // Display name
  final String alarmSoundUri;  // URI or persistent path
  DateTime? completedAt;

  TaskItem({
    required this.id,
    required this.title,
    this.description = '',
    required this.scheduledDateTime,
    required this.category,
    required this.priority,
    this.isCompleted = false,
    DateTime? createdAt,
    this.alarmSoundType = 'default',
    this.alarmSoundName = 'Default Alarm Sound',
    this.alarmSoundUri = 'default_alarm',
    this.completedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Convert TaskItem instance into a Map for SQLite persistence
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'scheduledDateTime': scheduledDateTime.toIso8601String(),
      'category': category,
      'priority': priority,
      'isCompleted': isCompleted ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'alarmSoundType': alarmSoundType,
      'alarmSoundName': alarmSoundName,
      'alarmSoundUri': alarmSoundUri,
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  /// Construct a TaskItem instance from SQLite Map record
  factory TaskItem.fromMap(Map<String, dynamic> map) {
    return TaskItem(
      id: map['id'] as String,
      title: map['title'] as String,
      description: (map['description'] as String?) ?? '',
      scheduledDateTime: DateTime.parse(map['scheduledDateTime'] as String),
      category: map['category'] as String,
      priority: map['priority'] as String,
      isCompleted: (map['isCompleted'] as int) == 1,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      alarmSoundType: (map['alarmSoundType'] as String?) ?? 'default',
      alarmSoundName: (map['alarmSoundName'] as String?) ?? 'Default Alarm Sound',
      alarmSoundUri: (map['alarmSoundUri'] as String?) ?? 'default_alarm',
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'] as String)
          : null,
    );
  }

  /// Check if the task is scheduled for today's calendar date
  bool get isToday {
    final now = DateTime.now();
    return scheduledDateTime.year == now.year &&
        scheduledDateTime.month == now.month &&
        scheduledDateTime.day == now.day;
  }

  /// Check if the task is scheduled for a future calendar date
  bool get isFuture {
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return scheduledDateTime.isAfter(todayEnd);
  }

  /// Check if an incomplete task has passed its scheduled date and time
  bool get isOverdue {
    if (isCompleted) return false; // Completed tasks are NEVER overdue
    return scheduledDateTime.isBefore(DateTime.now());
  }

  /// Weight for priority sorting (High=3, Medium=2, Low=1)
  int get priorityWeight {
    switch (priority.toLowerCase()) {
      case 'high':
        return 3;
      case 'medium':
        return 2;
      case 'low':
      default:
        return 1;
    }
  }

  /// Format scheduled time into readable 12-hour format (e.g. "10:00 AM")
  String get formattedTime {
    final hour = scheduledDateTime.hour == 0
        ? 12
        : (scheduledDateTime.hour > 12
            ? scheduledDateTime.hour - 12
            : scheduledDateTime.hour);
    final minute = scheduledDateTime.minute.toString().padLeft(2, '0');
    final period = scheduledDateTime.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  /// Format scheduled date into readable string (e.g. "Oct 24, 2026")
  String get formattedDate {
    if (isToday) return 'Today';
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final monthStr = months[scheduledDateTime.month - 1];
    return '$monthStr ${scheduledDateTime.day}, ${scheduledDateTime.year}';
  }

  /// Copy method to support immutable updates
  TaskItem copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? scheduledDateTime,
    String? category,
    String? priority,
    bool? isCompleted,
    DateTime? createdAt,
    String? alarmSoundType,
    String? alarmSoundName,
    String? alarmSoundUri,
    DateTime? completedAt,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      alarmSoundType: alarmSoundType ?? this.alarmSoundType,
      alarmSoundName: alarmSoundName ?? this.alarmSoundName,
      alarmSoundUri: alarmSoundUri ?? this.alarmSoundUri,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
