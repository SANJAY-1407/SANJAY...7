import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioService instance = AudioService._init();
  final AudioPlayer _player = AudioPlayer();

  bool _isPlaying = false;
  String? _currentUri;

  AudioService._init();

  bool get isPlaying => _isPlaying;
  String? get currentUri => _currentUri;

  /// Preview a sound (default sound or custom audio file)
  Future<void> playPreview({
    required String soundType,
    required String soundUri,
  }) async {
    try {
      if (_isPlaying) {
        await stopPreview();
      }

      await _player.setReleaseMode(ReleaseMode.stop);

      if (soundType == 'custom_song') {
        await _player.play(DeviceFileSource(soundUri));
      } else {
        // Default alarm sound preview using reliable online notification/alarm tone asset
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

      await _player.setReleaseMode(ReleaseMode.loop);

      if (soundType == 'custom_song') {
        await _player.play(DeviceFileSource(soundUri));
      } else {
        await _player.play(
          UrlSource('https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3'),
        );
      }

      _isPlaying = true;
      _currentUri = soundUri;
    } catch (e) {
      _isPlaying = false;
      _currentUri = null;
      rethrow;
    }
  }

  /// Stop preview or alarm playback
  Future<void> stopPreview() async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.release);
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
