import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_theme.dart';
import '../models/alarm_sound_config.dart';
import '../models/task_item.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';
import 'auth/login_screen.dart';
import 'edit_profile_screen.dart';
import 'sound_selection_screen.dart';

class ProfileScreen extends StatefulWidget {
  final List<TaskItem> tasks;
  final VoidCallback? onRefreshTasks;

  const ProfileScreen({
    super.key,
    required this.tasks,
    this.onRefreshTasks,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile _userProfile = UserProfile.guest();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await ProfileService.instance.getUserProfile();
    if (mounted) {
      setState(() {
        _userProfile = profile;
        _isLoading = false;
      });
    }
  }

  // Calculated Real Task Statistics
  int get _totalCompleted => widget.tasks.where((t) => t.isCompleted).length;
  int get _completedToday {
    return widget.tasks.where((t) => t.isToday && t.isCompleted).length;
  }
  int get _pendingCount => widget.tasks.where((t) => !t.isCompleted).length;
  int get _completionRate {
    if (widget.tasks.isEmpty) return 0;
    return ((_totalCompleted / widget.tasks.length) * 100).round();
  }

  Future<void> _openEditProfile() async {
    HapticFeedback.lightImpact();
    final updated = await Navigator.push<UserProfile>(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(currentProfile: _userProfile),
      ),
    );

    if (updated != null) {
      setState(() {
        _userProfile = updated;
      });
    }
  }

  Future<void> _openSoundSettings() async {
    HapticFeedback.lightImpact();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SoundSelectionScreen(
          currentConfig: AlarmSoundConfig(
            soundType: 'default',
            soundName: 'Default Alarm Sound',
            soundUri: 'default_alarm',
          ),
        ),
      ),
    );
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardNavy,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.primaryPurple.withValues(alpha: 0.3)),
        ),
        title: const Text('Sign Out?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to sign out? Your tasks remain safely stored locally on this device.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.urgentRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final guest = await ProfileService.instance.logout();
      setState(() {
        _userProfile = guest;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signed out to Guest Mode.'),
          backgroundColor: AppTheme.primaryPurple,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openSignIn() async {
    HapticFeedback.lightImpact();
    final user = await Navigator.push<UserProfile>(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );

    if (user != null) {
      setState(() {
        _userProfile = user;
      });
    }
  }

  void _showPrivacyDialog() {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardNavy,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.primaryPurple.withValues(alpha: 0.3)),
        ),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: AppTheme.accentCyan),
            SizedBox(width: 10),
            Text('Privacy Policy & Safety', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            'TaskAlert respects your privacy.\n\n'
            '• Local Data Ownership: All your tasks, custom audio files, and alarm settings are stored locally on your device.\n'
            '• Offline Capabilities: TaskAlert operates completely offline.\n'
            '• Zero Data Harvesting: Your personal data and audio recordings are never collected or sold to third parties.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  bool get _hasValidAvatarFile {
    if (_userProfile.avatarPath == null || _userProfile.avatarPath!.isEmpty) return false;
    try {
      return File(_userProfile.avatarPath!).existsSync();
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.darkBackground,
        body: Center(child: CircularProgressIndicator(color: AppTheme.accentCyan)),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Screen Header
              const Text(
                'My Profile',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textWhite,
                ),
              ),
              const SizedBox(height: 20),

              // Profile Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppTheme.cardGradient,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.35),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.accentCyan.withValues(alpha: 0.6),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 36,
                        backgroundColor: AppTheme.primaryPurple,
                        backgroundImage: _hasValidAvatarFile
                            ? FileImage(File(_userProfile.avatarPath!))
                            : null,
                        child: !_hasValidAvatarFile
                            ? Text(
                                _userProfile.avatarInitials,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _userProfile.displayName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textWhite,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _userProfile.isAuthenticated
                                      ? AppTheme.successGreen.withValues(alpha: 0.2)
                                      : AppTheme.warningOrange.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _userProfile.isAuthenticated
                                        ? AppTheme.successGreen
                                        : AppTheme.warningOrange,
                                  ),
                                ),
                                child: Text(
                                  _userProfile.isAuthenticated ? 'VERIFIED' : 'GUEST',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: _userProfile.isAuthenticated
                                        ? AppTheme.successGreen
                                        : AppTheme.warningOrange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _userProfile.email,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _openEditProfile,
                            icon: const Icon(Icons.edit_outlined, size: 14),
                            label: const Text('Edit Profile'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.accentCyan,
                              side: BorderSide(color: AppTheme.accentCyan.withValues(alpha: 0.5)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Statistics Header
              const Text(
                'Task Statistics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textWhite,
                ),
              ),
              const SizedBox(height: 12),

              // Stats Grid
              Row(
                children: [
                  Expanded(
                    child: _buildStatTile(
                      label: 'Total Completed',
                      value: '$_totalCompleted',
                      icon: Icons.task_alt_rounded,
                      color: AppTheme.successGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatTile(
                      label: 'Completed Today',
                      value: '$_completedToday',
                      icon: Icons.today_rounded,
                      color: AppTheme.accentCyan,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatTile(
                      label: 'Pending Tasks',
                      value: '$_pendingCount',
                      icon: Icons.pending_actions_rounded,
                      color: AppTheme.warningOrange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatTile(
                      label: 'Completion Rate',
                      value: '$_completionRate%',
                      icon: Icons.pie_chart_outline_rounded,
                      color: AppTheme.primaryPurple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Settings Menu Header
              const Text(
                'Account & Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textWhite,
                ),
              ),
              const SizedBox(height: 12),

              // Settings Items List
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardNavy,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  children: [
                    // Notifications Toggle
                    SwitchListTile(
                      value: _userProfile.enableNotifications,
                      activeTrackColor: AppTheme.primaryPurple,
                      thumbColor: WidgetStateProperty.all(AppTheme.accentCyan),
                      onChanged: (val) async {
                        HapticFeedback.lightImpact();
                        final updated = _userProfile.copyWith(enableNotifications: val);
                        await ProfileService.instance.saveUserProfile(updated);
                        setState(() {
                          _userProfile = updated;
                        });
                      },
                      secondary: const Icon(Icons.notifications_outlined, color: AppTheme.accentCyan),
                      title: const Text('Task Notifications', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Receive scheduled task alarm alerts', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    ),
                    const Divider(color: Colors.white10, height: 1),

                    // Alarm Ringtone Shortcut
                    ListTile(
                      onTap: _openSoundSettings,
                      leading: const Icon(Icons.audiotrack_outlined, color: AppTheme.accentCyan),
                      title: const Text('Default Alarm Sound', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Ringtones and custom audio files', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted),
                    ),
                    const Divider(color: Colors.white10, height: 1),

                    // Privacy & Security
                    ListTile(
                      onTap: _showPrivacyDialog,
                      leading: const Icon(Icons.shield_outlined, color: AppTheme.accentCyan),
                      title: const Text('Privacy & Security', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Local data ownership & offline safety', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted),
                    ),
                    const Divider(color: Colors.white10, height: 1),

                    // About App
                    ListTile(
                      leading: const Icon(Icons.info_outline_rounded, color: AppTheme.accentCyan),
                      title: const Text('About TaskAlert', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      subtitle: const Text('TaskAlert v1.0.0 (Day 10 Build)', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Auth Action Button (Sign In or Sign Out)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: _userProfile.isAuthenticated
                    ? OutlinedButton.icon(
                        onPressed: _handleSignOut,
                        icon: const Icon(Icons.logout_rounded, size: 20),
                        label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.urgentRed,
                          side: const BorderSide(color: AppTheme.urgentRed),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: _openSignIn,
                        icon: const Icon(Icons.login_rounded, size: 20),
                        label: const Text('Sign In or Register', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                        ),
                      ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardNavy,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 22, color: color),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(scale: anim, child: child),
                ),
                child: Text(
                  value,
                  key: ValueKey(value),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
