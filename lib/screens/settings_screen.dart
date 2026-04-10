import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../utils/theme_mode_inherited.dart';
import 'two_factor_login_screen.dart';
import 'two_factor_setup_screen.dart';
import 'user_management_screen.dart';
import 'invite_codes_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = false;
  bool _is2FAEnabled = false;
  String? _username;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check current theme mode from inherited widget
    _isDarkMode = ThemeModeInherited.of(context).themeMode == ThemeMode.dark;
  }

  Future<void> _loadSettings() async {
    _username = FirebaseService.currentUsername;
    if (_username != null) {
      final enabled = await FirebaseService.is2FAEnabled(_username!);
      final userData = await FirebaseService.getUserData(_username!);
      print('[SettingsScreen] User data: $userData');
      print('[SettingsScreen] Role: ${userData?['Role']}');
      print('[SettingsScreen] role (lowercase): ${userData?['role']}');
      if (mounted) {
        setState(() {
          _is2FAEnabled = enabled;
          _userData = userData;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.brightness_6_outlined),
                  title: const Text('Dark Mode'),
                  trailing: Switch(
                    value: _isDarkMode,
                    onChanged: (value) {
                      setState(() => _isDarkMode = value);
                      ThemeModeInherited.of(context).setThemeMode(
                        value ? ThemeMode.dark : ThemeMode.light,
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Notifications'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Notifications settings coming soon')),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('Language'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Language settings coming soon')),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Changelogs'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _showChangelogDialog(context);
                  },
                ),
                if (_userData?['Role'] == 'Admin' ||
                    _userData?['role'] == 'admin' ||
                    _userData?['role'] == 'Admin') ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.people),
                    title: const Text('User Management'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      if (_username != null) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                UserManagementScreen(username: _username!),
                          ),
                        );
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.card_giftcard),
                    title: const Text('Invite Codes'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const InviteCodesScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          Card(
            margin: const EdgeInsets.all(16),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.security),
                  title: const Text('Two-Factor Authentication'),
                  subtitle: Text(_is2FAEnabled ? 'Enabled' : 'Disabled'),
                  trailing: Switch(
                    value: _is2FAEnabled,
                    onChanged: (value) async {
                      if (_username != null) {
                        if (value) {
                          // Navigate to 2FA setup
                          Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                  builder: (_) => TwoFactorSetupScreen(
                                      username: _username!),
                                ),
                              )
                              .then((_) => _loadSettings());
                        } else {
                          // Disable 2FA
                          final success =
                              await FirebaseService.disable2FA(_username!);
                          if (mounted) {
                            if (success) {
                              setState(() => _is2FAEnabled = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('2FA disabled')),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Failed to disable 2FA')),
                              );
                            }
                          }
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          Card(
            margin: const EdgeInsets.all(16),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _showAboutDialog(context);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Logout'),
                  onTap: () {
                    _showLogoutConfirmationDialog(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'PinayPal Remote',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.backup, size: 48),
      children: [
        const Text('Secure backup management for your PC data.'),
        const SizedBox(height: 16),
        const Text('Created by: Wesley'),
        const SizedBox(height: 16),
        const Text('© 2026 PinayPal. All rights reserved.'),
      ],
    );
  }

  void _showChangelogDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Changelogs'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Version 1.0.0',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Initial release'),
              Text('• User authentication with 2FA support'),
              Text('• Remember device for 30 days'),
              Text('• Keep me logged in feature'),
              Text('• Dark mode support'),
              Text('• Profile management'),
              Text('• Login history tracking'),
              Text('• Change password and username'),
              SizedBox(height: 16),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await FirebaseService.logout();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (_) => const TwoFactorLoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
