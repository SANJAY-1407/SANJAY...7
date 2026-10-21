import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static final AudioService instance = AudioService._init();
  final AudioPlayer _player = AudioPlayer();

  bool _isPlaying = false;
  String? _currentUri;

  AudioService._init();

  bool get isPlaying => _isPlaying;
  String? get currentUri => _currentUri;

  /// Configure Android audio context specifically for Alarm Usage Stream
  Future<void> _configureAudioContext() async {
    try {
      await AudioPlayer.global.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.alarm,
          audioFocus: AndroidAudioFocus.gainTransient,
        ),
      ));
    } catch (e) {
      debugPrint('Error configuring AudioContext for Alarm stream: $e');
    }
  }

  /// Preview a sound (default sound or custom audio file)
  Future<void> playPreview({
    required String soundType,
    required String soundUri,
  }) async {
    try {
      if (_isPlaying) {
        await stopPreview();
      }

      await _configureAudioContext();
      await _player.setReleaseMode(ReleaseMode.stop);

      if (soundType == 'custom_song' && soundUri.isNotEmpty) {
        try {
          await _player.play(DeviceFileSource(soundUri));
        } catch (e) {
          debugPrint('Failed to preview custom sound $soundUri: $e');
          await _player.play(
            UrlSource('https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3'),
          );
        }
      } else {
        await _player.play(
          UrlSource('https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3'),
        );
      }

      _isPlaying = true;
      _currentUri = soundUri;

      _player.onPlayerComplete.listen((_) {
        _isPlaying = false;
        _currentUri = null;
      });
    } catch (e) {
      debugPrint('Error in playPreview: $e');
      _isPlaying = false;
      _currentUri = null;
      rethrow;
    }
  }

  /// Play task alarm sound in looping mode until dismissed
  Future<void> playAlarm({
    required String soundType,
    required String soundUri,
  }) async {
    try {
      if (_isPlaying) {
        await stopPreview();
      }

      await _configureAudioContext();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1.0);

      if (soundType == 'custom_song' && soundUri.isNotEmpty) {
        try {
          await _player.play(DeviceFileSource(soundUri));
          _isPlaying = true;
          _currentUri = soundUri;
          return;
        } catch (e) {
          debugPrint('Failed to play custom song "$soundUri", falling back to default alarm: $e');
        }
      }

      // Default or fallback alarm sound sources
      try {
        await _player.play(
          UrlSource('https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3'),
        );
        _isPlaying = true;
        _currentUri = 'default';
      } catch (e) {
        debugPrint('Primary online alarm sound failed: $e. Attempting secondary fallback...');
        try {
          await _player.play(
            UrlSource('https://actions.google.com/sounds/v1/alarms/beep_short.ogg'),
          );
          _isPlaying = true;
          _currentUri = 'default';
        } catch (err) {
          debugPrint('Secondary fallback alarm sound error: $err');
          _isPlaying = false;
        }
      }
    } catch (e) {
      debugPrint('General error in playAlarm: $e');
      _isPlaying = false;
      _currentUri = null;
    }
  }

  /// Stop preview or alarm playback
  Future<void> stopPreview() async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.release);
    } catch (e) {
      debugPrint('Error stopping audio preview: $e');
    } finally {
      _isPlaying = false;
      _currentUri = null;
    }
  }

  /// Dispose audio resources
  void dispose() {
    _player.dispose();
  }
}
