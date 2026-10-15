import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

class ProfileService {
  static final ProfileService instance = ProfileService._init();
  static const String _profileKey = 'task_alert_user_profile';

  ProfileService._init();

  /// Retrieve current profile or default Guest profile
  Future<UserProfile> getUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_profileKey);
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final Map<String, dynamic> map = json.decode(jsonString);
        return UserProfile.fromMap(map);
      } catch (_) {
        return UserProfile.guest();
      }
    }
    return UserProfile.guest();
  }

  /// Save profile updates to SharedPreferences
  Future<void> saveUserProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(profile.toMap());
    await prefs.setString(_profileKey, jsonString);
  }

  /// Authenticate user
  Future<UserProfile> login(String email, String password) async {
    final current = await getUserProfile();
    final rawName = email.split('@').first;
    final displayName = rawName.isNotEmpty
        ? rawName[0].toUpperCase() + rawName.substring(1)
        : 'Authenticated User';

    final authenticatedProfile = UserProfile(
      displayName: displayName,
      email: email,
      avatarInitials: UserProfile.deriveInitials(displayName),
      avatarPath: current.avatarPath,
      isAuthenticated: true,
      enableNotifications: current.enableNotifications,
    );

    await saveUserProfile(authenticatedProfile);
    return authenticatedProfile;
  }

  /// Register new user account
  Future<UserProfile> register(String name, String email, String password) async {
    final current = await getUserProfile();
    final newProfile = UserProfile(
      displayName: name.trim(),
      email: email.trim(),
      avatarInitials: UserProfile.deriveInitials(name),
      avatarPath: current.avatarPath,
      isAuthenticated: true,
      enableNotifications: true,
    );

    await saveUserProfile(newProfile);
    return newProfile;
  }

  /// Sign out user back to Guest Mode
  Future<UserProfile> logout() async {
    final guestProfile = UserProfile.guest();
    await saveUserProfile(guestProfile);
    return guestProfile;
  }
}
