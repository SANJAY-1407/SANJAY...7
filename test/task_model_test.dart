import 'package:flutter_test/flutter_test.dart';
import 'package:task_alert/models/task_item.dart';

void main() {
  group('TaskItem Model Tests', () {
    test('TaskItem default reminderEnabled is true', () {
      final task = TaskItem(
        id: '12345',
        title: 'Submit quarterly report',
        scheduledDateTime: DateTime(2026, 10, 25, 14, 30),
        category: 'Work',
        priority: 'High',
      );

      expect(task.reminderEnabled, isTrue);
      expect(task.isCompleted, isFalse);
      expect(task.title, equals('Submit quarterly report'));
    });

    test('TaskItem serialization toMap and fromMap preserves reminderEnabled and fields', () {
      final scheduled = DateTime(2026, 11, 15, 9, 0);
      final created = DateTime(2026, 10, 25, 10, 0);
      final original = TaskItem(
        id: 'test_task_99',
        title: 'Dentist Appointment',
        description: 'Bring insurance card',
        scheduledDateTime: scheduled,
        category: 'Health',
        priority: 'High',
        isCompleted: false,
        createdAt: created,
        alarmSoundType: 'custom_song',
        alarmSoundName: 'My Tune.mp3',
        alarmSoundUri: '/storage/emulated/0/Music/tune.mp3',
        reminderEnabled: true,
      );

      final map = original.toMap();
      expect(map['id'], equals('test_task_99'));
      expect(map['reminderEnabled'], equals(1));
      expect(map['isCompleted'], equals(0));

      final reconstructed = TaskItem.fromMap(map);
      expect(reconstructed.id, equals(original.id));
      expect(reconstructed.title, equals(original.title));
      expect(reconstructed.description, equals(original.description));
      expect(reconstructed.scheduledDateTime, equals(original.scheduledDateTime));
      expect(reconstructed.category, equals(original.category));
      expect(reconstructed.priority, equals(original.priority));
      expect(reconstructed.isCompleted, equals(original.isCompleted));
      expect(reconstructed.alarmSoundType, equals(original.alarmSoundType));
      expect(reconstructed.alarmSoundName, equals(original.alarmSoundName));
      expect(reconstructed.alarmSoundUri, equals(original.alarmSoundUri));
      expect(reconstructed.reminderEnabled, isTrue);
    });

    test('TaskItem from legacy map without reminderEnabled defaults to true', () {
      final legacyMap = <String, dynamic>{
        'id': 'legacy_1',
        'title': 'Legacy Task',
        'description': '',
        'scheduledDateTime': DateTime(2026, 10, 26, 15, 0).toIso8601String(),
        'category': 'Personal',
        'priority': 'Medium',
        'isCompleted': 0,
        'createdAt': DateTime(2026, 10, 20).toIso8601String(),
      };

      final task = TaskItem.fromMap(legacyMap);
      expect(task.reminderEnabled, isTrue);
    });

    test('TaskItem copyWith toggles reminderEnabled and updates due time without mutating', () {
      final initial = TaskItem(
        id: 'task_1',
        title: 'Gym session',
        scheduledDateTime: DateTime(2026, 10, 25, 18, 0),
        category: 'Fitness',
        priority: 'Low',
        reminderEnabled: true,
      );

      final modified = initial.copyWith(
        reminderEnabled: false,
        scheduledDateTime: DateTime(2026, 10, 25, 19, 0),
      );

      expect(initial.reminderEnabled, isTrue);
      expect(initial.scheduledDateTime.hour, equals(18));

      expect(modified.reminderEnabled, isFalse);
      expect(modified.scheduledDateTime.hour, equals(19));
      expect(modified.id, equals(initial.id));
    });

    test('Task status logic: completed tasks are never overdue', () {
      final pastTime = DateTime.now().subtract(const Duration(hours: 2));
      final pendingOverdue = TaskItem(
        id: 'past_1',
        title: 'Past Task',
        scheduledDateTime: pastTime,
        category: 'Work',
        priority: 'High',
        isCompleted: false,
      );

      expect(pendingOverdue.isOverdue, isTrue);

      final completedPast = pendingOverdue.copyWith(isCompleted: true);
      expect(completedPast.isOverdue, isFalse);
    });
  });
}
