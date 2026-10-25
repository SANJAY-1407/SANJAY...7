/// Represents a dedicated mobile Clock-style alarm in AlertBox.
/// This is completely separate from task-reminder alarms.
class ClockAlarm {
  final String id;
  final int numericId; // Deterministic integer for Android notification IDs
  final int hour; // 0-23
  final int minute; // 0-59
  final String label;
  final bool isEnabled;
  final Set<int> repeatDays; // 1 = Monday ... 7 = Sunday (ISO 8601). Empty = once.
  final String soundType; // 'default', 'ringtone', 'custom_song'
  final String soundName;
  final String soundUri;
  final int snoozeMinutes; // e.g. 5, 10, 15, 20
  final bool vibrate;
  final DateTime createdAt;

  const ClockAlarm({
    required this.id,
    required this.numericId,
    required this.hour,
    required this.minute,
    this.label = '',
    this.isEnabled = true,
    this.repeatDays = const <int>{},
    this.soundType = 'default',
    this.soundName = 'Default Alarm Sound',
    this.soundUri = 'default_alarm',
    this.snoozeMinutes = 10,
    this.vibrate = true,
    required this.createdAt,
  });

  /// Factory for a new alarm at a specified time
  factory ClockAlarm.create({
    required int numericId,
    required int hour,
    required int minute,
    String label = '',
    Set<int> repeatDays = const <int>{},
    String soundType = 'default',
    String soundName = 'Default Alarm Sound',
    String soundUri = 'default_alarm',
    int snoozeMinutes = 10,
    bool vibrate = true,
  }) {
    final now = DateTime.now();
    return ClockAlarm(
      id: 'clock_alarm_${now.millisecondsSinceEpoch}_$numericId',
      numericId: numericId,
      hour: hour,
      minute: minute,
      label: label,
      isEnabled: true,
      repeatDays: Set<int>.unmodifiable(repeatDays),
      soundType: soundType,
      soundName: soundName,
      soundUri: soundUri,
      snoozeMinutes: snoozeMinutes,
      vibrate: vibrate,
      createdAt: now,
    );
  }

  /// Whether the alarm repeats on any day of the week
  bool get isRepeating => repeatDays.isNotEmpty;

  /// Returns 12-hour formatted time (e.g. "07:30")
  String get formattedTime {
    final displayHour = hour == 0
        ? 12
        : (hour > 12 ? hour - 12 : hour);
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$displayHour:$minuteStr';
  }

  /// Returns 24-hour formatted time (e.g. "19:30")
  String get formatted24HourTime {
    final hourStr = hour.toString().padLeft(2, '0');
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$hourStr:$minuteStr';
  }

  /// Returns "AM" or "PM"
  String get period => hour >= 12 ? 'PM' : 'AM';

  /// Summary of repeat days (e.g. "Every day", "Weekdays", "Mon, Wed, Fri", "Once")
  String get repeatSummary {
    if (repeatDays.isEmpty) return 'Once';
    if (repeatDays.length == 7) return 'Every day';

    final isWeekdays = repeatDays.length == 5 &&
        repeatDays.contains(DateTime.monday) &&
        repeatDays.contains(DateTime.tuesday) &&
        repeatDays.contains(DateTime.wednesday) &&
        repeatDays.contains(DateTime.thursday) &&
        repeatDays.contains(DateTime.friday);
    if (isWeekdays) return 'Weekdays (Mon-Fri)';

    final isWeekends = repeatDays.length == 2 &&
        repeatDays.contains(DateTime.saturday) &&
        repeatDays.contains(DateTime.sunday);
    if (isWeekends) return 'Weekends (Sat-Sun)';

    const dayNames = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };

    final sorted = repeatDays.toList()..sort();
    return sorted.map((d) => dayNames[d] ?? '').where((s) => s.isNotEmpty).join(', ');
  }

  /// Computes the exact [DateTime] for the next occurrence of this alarm.
  DateTime getNextOccurrence([DateTime? referenceTime]) {
    final now = referenceTime ?? DateTime.now();

    if (!isRepeating) {
      // One-time alarm
      var candidate = DateTime(now.year, now.month, now.day, hour, minute);
      // Give a small 5-second leeway so creating an alarm at the current minute doesn't trigger immediately
      if (candidate.isBefore(now.add(const Duration(seconds: 5)))) {
        candidate = candidate.add(const Duration(days: 1));
      }
      return candidate;
    }

    // Repeating alarm
    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      final checkDate = now.add(Duration(days: dayOffset));
      final weekday = checkDate.weekday; // 1 = Mon ... 7 = Sun

      if (repeatDays.contains(weekday)) {
        final candidate = DateTime(
          checkDate.year,
          checkDate.month,
          checkDate.day,
          hour,
          minute,
        );

        if (dayOffset > 0 || candidate.isAfter(now.add(const Duration(seconds: 5)))) {
          return candidate;
        }
      }
    }

    // Fallback: 7 days from today at the same time
    return DateTime(now.year, now.month, now.day, hour, minute).add(const Duration(days: 7));
  }

  /// Human-readable duration until the next occurrence (e.g. "in 7 hours and 15 minutes")
  String timeUntilNextOccurrence([DateTime? referenceTime]) {
    final now = referenceTime ?? DateTime.now();
    final next = getNextOccurrence(now);
    final diff = next.difference(now);

    final totalMinutes = diff.inMinutes;
    if (totalMinutes <= 0) {
      return 'in less than a minute';
    }

    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = totalMinutes % 60;

    final parts = <String>[];
    if (days == 1) {
      parts.add('1 day');
    } else if (days > 1) {
      parts.add('$days days');
    }

    if (hours == 1) {
      parts.add('1 hour');
    } else if (hours > 1) {
      parts.add('$hours hours');
    }

    if (minutes == 1) {
      parts.add('1 minute');
    } else if (minutes > 1 || parts.isEmpty) {
      parts.add('$minutes minutes');
    }

    return 'in ${parts.join(' ')}';
  }

  /// Converts this alarm instance to a Map for SQLite persistence
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'numericId': numericId,
      'hour': hour,
      'minute': minute,
      'label': label,
      'isEnabled': isEnabled ? 1 : 0,
      'repeatDays': repeatDays.join(','),
      'soundType': soundType,
      'soundName': soundName,
      'soundUri': soundUri,
      'snoozeMinutes': snoozeMinutes,
      'vibrate': vibrate ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Constructs a ClockAlarm from a SQLite Map record
  factory ClockAlarm.fromMap(Map<String, dynamic> map) {
    final repeatDaysStr = (map['repeatDays'] as String?) ?? '';
    final repeatSet = repeatDaysStr.isEmpty
        ? <int>{}
        : repeatDaysStr
            .split(',')
            .map((s) => int.tryParse(s.trim()))
            .whereType<int>()
            .toSet();

    return ClockAlarm(
      id: map['id'] as String,
      numericId: (map['numericId'] as int?) ?? 1,
      hour: map['hour'] as int,
      minute: map['minute'] as int,
      label: (map['label'] as String?) ?? '',
      isEnabled: (map['isEnabled'] as int) == 1,
      repeatDays: Set<int>.unmodifiable(repeatSet),
      soundType: (map['soundType'] as String?) ?? 'default',
      soundName: (map['soundName'] as String?) ?? 'Default Alarm Sound',
      soundUri: (map['soundUri'] as String?) ?? 'default_alarm',
      snoozeMinutes: (map['snoozeMinutes'] as int?) ?? 10,
      vibrate: ((map['vibrate'] as int?) ?? 1) == 1,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }

  ClockAlarm copyWith({
    String? id,
    int? numericId,
    int? hour,
    int? minute,
    String? label,
    bool? isEnabled,
    Set<int>? repeatDays,
    String? soundType,
    String? soundName,
    String? soundUri,
    int? snoozeMinutes,
    bool? vibrate,
    DateTime? createdAt,
  }) {
    return ClockAlarm(
      id: id ?? this.id,
      numericId: numericId ?? this.numericId,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      label: label ?? this.label,
      isEnabled: isEnabled ?? this.isEnabled,
      repeatDays: repeatDays != null ? Set<int>.unmodifiable(repeatDays) : this.repeatDays,
      soundType: soundType ?? this.soundType,
      soundName: soundName ?? this.soundName,
      soundUri: soundUri ?? this.soundUri,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      vibrate: vibrate ?? this.vibrate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
