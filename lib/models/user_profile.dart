import 'dart:io';

class UserProfile {
  final String displayName;
  final String email;
  final String avatarInitials;
  final String? avatarPath;
  final bool isAuthenticated;
  final bool enableNotifications;

  const UserProfile({
    required this.displayName,
    required this.email,
    required this.avatarInitials,
    this.avatarPath,
    required this.isAuthenticated,
    this.enableNotifications = true,
  });

  /// Default Guest profile configuration
  factory UserProfile.guest() {
    return const UserProfile(
      displayName: 'TaskAlert User',
      email: 'guest@taskalert.app',
      avatarInitials: 'TU',
      avatarPath: null,
      isAuthenticated: false,
      enableNotifications: true,
    );
  }

  /// Derive initials from display name (e.g. "Alex Morgan" -> "AM")
  static String deriveInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'TU';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
  }

  /// Checks if avatarPath points to an existing file
  bool get hasValidAvatarPath {
    if (avatarPath == null || avatarPath!.trim().isEmpty) return false;
    try {
      return File(avatarPath!).existsSync();
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'email': email,
      'avatarInitials': avatarInitials,
      'avatarPath': avatarPath,
      'isAuthenticated': isAuthenticated,
      'enableNotifications': enableNotifications,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      displayName: map['displayName'] as String? ?? 'TaskAlert User',
      email: map['email'] as String? ?? 'guest@taskalert.app',
      avatarInitials: map['avatarInitials'] as String? ?? 'TU',
      avatarPath: map['avatarPath'] as String?,
      isAuthenticated: map['isAuthenticated'] as bool? ?? false,
      enableNotifications: map['enableNotifications'] as bool? ?? true,
    );
  }

  UserProfile copyWith({
    String? displayName,
    String? email,
    String? avatarInitials,
    String? avatarPath,
    bool clearAvatarPath = false,
    bool? isAuthenticated,
    bool? enableNotifications,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      avatarInitials: avatarInitials ?? this.avatarInitials,
      avatarPath: clearAvatarPath ? null : (avatarPath ?? this.avatarPath),
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      enableNotifications: enableNotifications ?? this.enableNotifications,
    );
  }
}
