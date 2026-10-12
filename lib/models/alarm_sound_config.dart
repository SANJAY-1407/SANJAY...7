class AlarmSoundConfig {
  final String soundType; // 'default', 'ringtone', 'custom_song'
  final String soundName; // Display name (e.g., "Default Alarm", "My Track.mp3")
  final String soundUri;  // URI or persistent local file path

  const AlarmSoundConfig({
    required this.soundType,
    required this.soundName,
    required this.soundUri,
  });

  /// Default alarm configuration
  factory AlarmSoundConfig.defaultSound() {
    return const AlarmSoundConfig(
      soundType: 'default',
      soundName: 'Default Alarm Sound',
      soundUri: 'default_alarm',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'soundType': soundType,
      'soundName': soundName,
      'soundUri': soundUri,
    };
  }

  factory AlarmSoundConfig.fromMap(Map<String, dynamic> map) {
    return AlarmSoundConfig(
      soundType: (map['soundType'] as String?) ?? 'default',
      soundName: (map['soundName'] as String?) ?? 'Default Alarm Sound',
      soundUri: (map['soundUri'] as String?) ?? 'default_alarm',
    );
  }

  AlarmSoundConfig copyWith({
    String? soundType,
    String? soundName,
    String? soundUri,
  }) {
    return AlarmSoundConfig(
      soundType: soundType ?? this.soundType,
      soundName: soundName ?? this.soundName,
      soundUri: soundUri ?? this.soundUri,
    );
  }
}
