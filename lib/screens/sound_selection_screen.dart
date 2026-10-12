import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../core/theme/app_theme.dart';
import '../models/alarm_sound_config.dart';
import '../services/audio_service.dart';

class SoundSelectionScreen extends StatefulWidget {
  final AlarmSoundConfig currentConfig;

  const SoundSelectionScreen({super.key, required this.currentConfig});

  @override
  State<SoundSelectionScreen> createState() => _SoundSelectionScreenState();
}

class _SoundSelectionScreenState extends State<SoundSelectionScreen> {
  late AlarmSoundConfig _selectedConfig;
  bool _isPickingFile = false;

  final List<AlarmSoundConfig> _presetTones = [
    const AlarmSoundConfig(
      soundType: 'default',
      soundName: 'Default Alarm Sound',
      soundUri: 'default_alarm',
    ),
    const AlarmSoundConfig(
      soundType: 'ringtone',
      soundName: 'Gentle Chimes',
      soundUri: 'gentle_chimes',
    ),
    const AlarmSoundConfig(
      soundType: 'ringtone',
      soundName: 'Radar Alert',
      soundUri: 'radar_alert',
    ),
    const AlarmSoundConfig(
      soundType: 'ringtone',
      soundName: 'Morning Breeze',
      soundUri: 'morning_breeze',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedConfig = widget.currentConfig;
  }

  @override
  void dispose() {
    AudioService.instance.stopPreview();
    super.dispose();
  }

  Future<void> _pickCustomAudioFile() async {
    setState(() {
      _isPickingFile = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final pickedFile = File(result.files.single.path!);
        final fileName = result.files.single.name;

        // Copy into app-private directory for durable persistent access
        final appDir = await getApplicationDocumentsDirectory();
        final savedDir = Directory('${appDir.path}/custom_sounds');
        if (!await savedDir.exists()) {
          await savedDir.create(recursive: true);
        }

        final localPath = '${savedDir.path}/${DateTime.now().millisecondsSinceEpoch}_$fileName';
        await pickedFile.copy(localPath);

        setState(() {
          _selectedConfig = AlarmSoundConfig(
            soundType: 'custom_song',
            soundName: fileName,
            soundUri: localPath,
          );
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Custom song "$fileName" selected successfully!'),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting audio file: $e'),
          backgroundColor: AppTheme.urgentRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        _isPickingFile = false;
      });
    }
  }

  Future<void> _togglePreview(AlarmSoundConfig config) async {
    if (AudioService.instance.isPlaying && AudioService.instance.currentUri == config.soundUri) {
      await AudioService.instance.stopPreview();
    } else {
      await AudioService.instance.playPreview(
        soundType: config.soundType,
        soundUri: config.soundUri,
      );
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Select Alarm Sound',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            AudioService.instance.stopPreview();
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              AudioService.instance.stopPreview();
              Navigator.pop(context, _selectedConfig);
            },
            child: const Text(
              'Save',
              style: TextStyle(
                color: AppTheme.accentCyan,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: AppTheme.cardGradient,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.audiotrack_rounded,
                        color: AppTheme.accentCyan,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current Sound',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.accentCyan,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedConfig.soundName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textWhite,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Section 1: Preset Tones
              const Text(
                'Default & Preset Alarm Tones',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textWhite,
                ),
              ),
              const SizedBox(height: 12),
              ..._presetTones.map((tone) {
                final isSelected = _selectedConfig.soundUri == tone.soundUri;
                final isPlayingThis = AudioService.instance.isPlaying &&
                    AudioService.instance.currentUri == tone.soundUri;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardNavy,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.accentCyan
                          : AppTheme.primaryPurple.withValues(alpha: 0.2),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: ListTile(
                    onTap: () {
                      setState(() {
                        _selectedConfig = tone;
                      });
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    leading: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? AppTheme.accentCyan : AppTheme.textMuted,
                          width: 2,
                        ),
                        color: isSelected ? AppTheme.accentCyan : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Center(
                              child: Icon(Icons.circle, size: 8, color: Colors.white),
                            )
                          : null,
                    ),
                    title: Text(
                      tone.soundName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textWhite,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        isPlayingThis
                            ? Icons.stop_circle_rounded
                            : Icons.play_circle_fill_rounded,
                        color: isPlayingThis ? AppTheme.urgentRed : AppTheme.accentCyan,
                        size: 28,
                      ),
                      onPressed: () => _togglePreview(tone),
                      tooltip: isPlayingThis ? 'Stop Preview' : 'Play Preview',
                    ),
                  ),
                );
              }),
              const SizedBox(height: 28),

              // Section 2: Custom Song / Audio File
              const Text(
                'Custom Audio File',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textWhite,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.cardNavy,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _selectedConfig.soundType == 'custom_song'
                        ? AppTheme.accentCyan
                        : AppTheme.primaryPurple.withValues(alpha: 0.2),
                    width: _selectedConfig.soundType == 'custom_song' ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.folder_open_rounded,
                          color: AppTheme.accentCyan,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Choose My Song',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textWhite,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _selectedConfig.soundType == 'custom_song'
                                    ? _selectedConfig.soundName
                                    : 'Select MP3, WAV, or M4A from storage',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _selectedConfig.soundType == 'custom_song'
                                      ? AppTheme.accentCyan
                                      : AppTheme.textMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isPickingFile ? null : _pickCustomAudioFile,
                            icon: _isPickingFile
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.accentCyan,
                                    ),
                                  )
                                : const Icon(Icons.music_note_rounded, size: 18),
                            label: const Text('Choose Audio File'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textWhite,
                              side: const BorderSide(color: AppTheme.accentCyan),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        if (_selectedConfig.soundType == 'custom_song') ...[
                          const SizedBox(width: 10),
                          IconButton(
                            icon: Icon(
                              AudioService.instance.isPlaying &&
                                      AudioService.instance.currentUri ==
                                          _selectedConfig.soundUri
                                  ? Icons.stop_circle_rounded
                                  : Icons.play_circle_fill_rounded,
                              color: AppTheme.accentCyan,
                              size: 32,
                            ),
                            onPressed: () => _togglePreview(_selectedConfig),
                            tooltip: 'Preview Selected Song',
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
