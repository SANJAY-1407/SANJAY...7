import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../core/theme/app_theme.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';

class EditProfileScreen extends StatefulWidget {
  final UserProfile currentProfile;

  const EditProfileScreen({super.key, required this.currentProfile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  String? _avatarPath;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentProfile.displayName);
    _emailController = TextEditingController(text: widget.currentProfile.email);
    _avatarPath = widget.currentProfile.avatarPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickProfilePhoto() async {
    HapticFeedback.lightImpact();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty && result.files.single.path != null) {
        final pickedPath = result.files.single.path!;
        final sourceFile = File(pickedPath);

        if (await sourceFile.exists()) {
          final appDir = await getApplicationDocumentsDirectory();
          final ext = p.extension(pickedPath).isNotEmpty ? p.extension(pickedPath) : '.jpg';
          final savedFileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}$ext';
          final persistentFile = await sourceFile.copy('${appDir.path}/$savedFileName');

          setState(() {
            _avatarPath = persistentFile.path;
          });

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile photo selected! Save changes to apply.'),
              backgroundColor: AppTheme.primaryPurple,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not select profile photo: $e'),
          backgroundColor: AppTheme.urgentRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _removeProfilePhoto() {
    HapticFeedback.lightImpact();
    setState(() {
      _avatarPath = null;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final newName = _nameController.text.trim();
    final newEmail = _emailController.text.trim();

    final updatedProfile = widget.currentProfile.copyWith(
      displayName: newName,
      email: newEmail,
      avatarInitials: UserProfile.deriveInitials(newName),
      avatarPath: _avatarPath,
      clearAvatarPath: _avatarPath == null,
    );

    await ProfileService.instance.saveUserProfile(updatedProfile);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile updated successfully!'),
        backgroundColor: AppTheme.successGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.pop(context, updatedProfile);
  }

  bool get _hasValidAvatarFile {
    if (_avatarPath == null || _avatarPath!.isEmpty) return false;
    try {
      return File(_avatarPath!).existsSync();
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar Preview & Picker Trigger
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickProfilePhoto,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.accentCyan,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 46,
                                backgroundColor: AppTheme.primaryPurple,
                                backgroundImage: _hasValidAvatarFile
                                    ? FileImage(File(_avatarPath!))
                                    : null,
                                child: !_hasValidAvatarFile
                                    ? Text(
                                        UserProfile.deriveInitials(_nameController.text),
                                        style: const TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppTheme.accentCyan,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black38,
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 18,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: _pickProfilePhoto,
                            icon: const Icon(Icons.photo_library_outlined, size: 16, color: AppTheme.accentCyan),
                            label: const Text(
                              'Select Photo',
                              style: TextStyle(
                                color: AppTheme.accentCyan,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (_hasValidAvatarFile) ...[
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: _removeProfilePhoto,
                              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.urgentRed),
                              label: const Text(
                                'Remove',
                                style: TextStyle(
                                  color: AppTheme.urgentRed,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Display Name Field
                const Text(
                  'Display Name *',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textWhite,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(color: AppTheme.textWhite),
                  decoration: InputDecoration(
                    hintText: 'Enter your name',
                    hintStyle: const TextStyle(color: AppTheme.textMuted),
                    filled: true,
                    fillColor: AppTheme.cardNavy,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: AppTheme.primaryPurple.withValues(alpha: 0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppTheme.accentCyan),
                    ),
                    prefixIcon: const Icon(Icons.person_outline_rounded, color: AppTheme.accentCyan),
                  ),
                  onChanged: (_) {
                    setState(() {}); // Updates live avatar initials preview
                  },
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Display name cannot be empty';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Email Address Field
                const Text(
                  'Email Address',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textWhite,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  enabled: !widget.currentProfile.isAuthenticated, // Disabled if verified auth account
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(
                    color: widget.currentProfile.isAuthenticated
                        ? AppTheme.textMuted
                        : AppTheme.textWhite,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter email address',
                    hintStyle: const TextStyle(color: AppTheme.textMuted),
                    filled: true,
                    fillColor: AppTheme.cardNavy,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: AppTheme.primaryPurple.withValues(alpha: 0.2),
                      ),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.accentCyan),
                    suffixIcon: widget.currentProfile.isAuthenticated
                        ? const Tooltip(
                            message: 'Email belongs to verified account',
                            child: Icon(Icons.verified_user_rounded, color: AppTheme.successGreen, size: 20),
                          )
                        : null,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Email address cannot be empty';
                    }
                    return null;
                  },
                ),
                if (widget.currentProfile.isAuthenticated) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Email changes for verified accounts require authentication provider confirmation.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
                const SizedBox(height: 36),

                // Save Profile Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      foregroundColor: AppTheme.textWhite,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 6,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
