import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/firebase_service.dart';
import 'change_username_screen.dart';
import 'change_password_screen.dart';
import 'two_factor_setup_screen.dart';
import 'login_history_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String username;
  const ProfileScreen({super.key, required this.username});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  Uint8List? _avatarImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    // Use FirebaseService.currentUsername as fallback if widget.username is empty
    final username = widget.username.isEmpty
        ? FirebaseService.currentUsername
        : widget.username;

    if (username == null || username.isEmpty) {
      print('[ProfileScreen] No username available');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      // Make all Firebase calls in parallel
      final results = await Future.wait([
        FirebaseService.getUserData(username),
        FirebaseService.getUserAvatar(username),
        FirebaseService.is2FAEnabled(username),
      ]);

      final userData = results[0] as Map<String, dynamic>?;
      final avatarData = results[1] as String?;
      final is2FAEnabled = results[2] as bool;

      // Debug: Print user data to see what's being retrieved
      print('[ProfileScreen] User data for $username: $userData');
      print('[ProfileScreen] 2FA enabled status: $is2FAEnabled');

      if (mounted) {
        setState(() {
          _userData = userData ??
              {
                'Username': username,
                'Role': 'User',
                'Status': 'Active',
                'CreatedAt': DateTime.now().toIso8601String(),
              };
          // Add 2FA status to user data for display
          if (_userData != null) {
            _userData!['is2FAEnabled'] = is2FAEnabled;
            _userData!['Is2FAEnabled'] = is2FAEnabled;
          }
          if (avatarData != null) {
            _avatarImage = base64Decode(avatarData);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[ProfileScreen] Error loading user data: $e');
      if (mounted) {
        setState(() {
          _userData = {
            'Username': username,
            'Role': 'User',
            'Status': 'Active',
            'CreatedAt': DateTime.now().toIso8601String(),
            'is2FAEnabled': false,
            'Is2FAEnabled': false,
          };
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading profile data: $e')),
          );
        }
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() => _avatarImage = bytes);

        // Upload to Firebase
        final base64Image = base64Encode(bytes);
        final success = await FirebaseService.uploadUserAvatar(
            widget.username, base64Image);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success
                  ? 'Avatar updated successfully'
                  : 'Failed to upload avatar'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (photo != null) {
        final bytes = await photo.readAsBytes();
        setState(() => _avatarImage = bytes);

        final base64Image = base64Encode(bytes);
        final success = await FirebaseService.uploadUserAvatar(
            widget.username, base64Image);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success
                  ? 'Avatar updated successfully'
                  : 'Failed to upload avatar'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking photo: $e')),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            if (_avatarImage != null)
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title:
                    Text('Remove Photo', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  final success =
                      await FirebaseService.removeUserAvatar(widget.username);
                  if (success) {
                    setState(() => _avatarImage = null);
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(success
                              ? 'Avatar removed'
                              : 'Failed to remove avatar')),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return 'Unknown';
    try {
      final date = DateTime.parse(isoDate);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Check for admin role with multiple field name variations
    final roleValue = _userData?['Role']?.toString() ??
        _userData?['role']?.toString() ??
        _userData?['RoleName']?.toString() ??
        _userData?['roleName']?.toString() ??
        'user';
    final isAdmin = roleValue.toLowerCase() == 'admin';
    final is2FAEnabled = _userData?['is2FAEnabled'] == true ||
        _userData?['Is2FAEnabled'] == true;

    return RefreshIndicator(
      onRefresh: _loadUserData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Header Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            color: const Color(0xFF83509F).withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  // Avatar with edit button
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: _showImageSourceDialog,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF83509F),
                              width: 4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF83509F)
                                    .withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                            image: _avatarImage != null
                                ? DecorationImage(
                                    image: MemoryImage(_avatarImage!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _avatarImage == null
                              ? const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Color(0xFF83509F),
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _showImageSourceDialog,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF83509F),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Username
                  Text(
                    _userData?['Username']?.toString() ?? widget.username,
                    style: tt.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF83509F),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Role Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: isAdmin
                          ? const Color(0xFF83509F)
                          : const Color(0xFFA88BBD),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      isAdmin ? 'ADMIN' : 'USER',
                      style: tt.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Member since
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: const Color(0xFF83509F),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Member since ${_formatDate(_userData?['CreatedAt'])}',
                        style: tt.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Account Info Section
          _buildSectionHeader(cs, tt, 'Account Info', Icons.info_outline),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                _buildInfoTile(
                  icon: Icons.account_circle,
                  label: 'Username',
                  value: _userData?['Username']?.toString() ?? widget.username,
                ),
                const Divider(height: 1),
                _buildInfoTile(
                  icon: Icons.admin_panel_settings,
                  label: 'Role',
                  value: _userData?['Role']?.toString() ??
                      _userData?['role']?.toString() ??
                      _userData?['RoleName']?.toString() ??
                      _userData?['roleName']?.toString() ??
                      'User',
                ),
                const Divider(height: 1),
                _buildInfoTile(
                  icon: Icons.toggle_on,
                  label: 'Status',
                  value: _userData?['Status']?.toString() ?? 'Active',
                  valueColor:
                      (_userData?['Status']?.toString() ?? 'Active') == 'Active'
                          ? Colors.green
                          : Colors.orange,
                ),
                const Divider(height: 1),
                _buildInfoTile(
                  icon: Icons.calendar_today,
                  label: 'Created',
                  value: _formatDate(_userData?['CreatedAt']),
                ),
                const Divider(height: 1),
                _buildInfoTile(
                  icon: Icons.verified_user,
                  label: '2FA Status',
                  value: is2FAEnabled ? 'Enabled' : 'Disabled',
                  valueColor: is2FAEnabled ? Colors.green : cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Account Settings Section
          _buildSectionHeader(
              cs, tt, 'Account Settings', Icons.manage_accounts),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                _buildListTile(
                  icon: Icons.person_outline,
                  title: 'Change Username',
                  subtitle: 'Update your display name',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            ChangeUsernameScreen(username: widget.username)),
                  ),
                ),
                const Divider(height: 1),
                _buildListTile(
                  icon: Icons.lock_outline,
                  title: 'Change Password',
                  subtitle: 'Update your account password',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            ChangePasswordScreen(username: widget.username)),
                  ),
                ),
                const Divider(height: 1),
                _buildListTile(
                  icon: Icons.security,
                  title: 'Two-Factor Authentication',
                  subtitle: is2FAEnabled ? 'Enabled' : 'Add extra security',
                  trailing: is2FAEnabled
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'ON',
                            style: tt.labelSmall?.copyWith(color: cs.onPrimary),
                          ),
                        )
                      : null,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            TwoFactorSetupScreen(username: widget.username)),
                  ).then((_) => _loadUserData()),
                ),
                const Divider(height: 1),
                _buildListTile(
                  icon: Icons.history,
                  title: 'Login History',
                  subtitle: 'View recent login activity',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            LoginHistoryScreen(username: widget.username)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      ColorScheme cs, TextTheme tt, String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF83509F).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF83509F)),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: tt.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF83509F),
          ),
        ),
      ],
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF83509F).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF83509F)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle),
      trailing:
          trailing ?? const Icon(Icons.chevron_right, color: Color(0xFF83509F)),
      onTap: onTap,
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return ListTile(
      leading:
          Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
      title: Text(label, style: const TextStyle(fontSize: 12)),
      subtitle: Text(
        value,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: valueColor,
        ),
      ),
    );
  }
}
