import 'package:shared_preferences/shared_preferences.dart';
import '../models/alarm_sound_config.dart';

/// Persists the user's preferred sound for newly created tasks.
/// Existing TaskItem sound fields remain the source of truth when editing.
class AlarmSoundPreferences {
  static const _typeKey = 'alertbox_default_alarm_sound_type';
  static const _nameKey = 'alertbox_default_alarm_sound_name';
  static const _uriKey = 'alertbox_default_alarm_sound_uri';

  static Future<AlarmSoundConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AlarmSoundConfig(
      soundType: prefs.getString(_typeKey) ?? 'default',
      soundName: prefs.getString(_nameKey) ?? 'Default Alarm Sound',
      soundUri: prefs.getString(_uriKey) ?? 'default_alarm',
    );
  }

  static Future<void> save(AlarmSoundConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_typeKey, config.soundType),
      prefs.setString(_nameKey, config.soundName),
      prefs.setString(_uriKey, config.soundUri),
    ]);
  }
}
