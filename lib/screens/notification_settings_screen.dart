import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _enableNotifications = true;
  bool _backupNotifications = true;
  bool _healthCheckWarnings = true;
  bool _pcStatusNotifications = true;
  bool _scheduledBackupReminders = false;
  String? _fcmToken;
  bool _isLoadingToken = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadFCMToken();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _enableNotifications = prefs.getBool('enable_notifications') ?? true;
      _backupNotifications = prefs.getBool('backup_notifications') ?? true;
      _healthCheckWarnings = prefs.getBool('health_check_warnings') ?? true;
      _pcStatusNotifications = prefs.getBool('pc_status_notifications') ?? true;
      _scheduledBackupReminders =
          prefs.getBool('scheduled_backup_reminders') ?? false;
    });
  }

  Future<void> _loadFCMToken() async {
    try {
      final token = await NotificationService().getFCMToken();
      setState(() {
        _fcmToken = token;
        _isLoadingToken = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingToken = false;
      });
    }
  }

  void _copyTokenToClipboard() {
    if (_fcmToken != null) {
      Clipboard.setData(ClipboardData(text: _fcmToken!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('FCM token copied to clipboard')),
      );
    }
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    setState(() {
      switch (key) {
        case 'enable_notifications':
          _enableNotifications = value;
          break;
        case 'backup_notifications':
          _backupNotifications = value;
          break;
        case 'health_check_warnings':
          _healthCheckWarnings = value;
          break;
        case 'pc_status_notifications':
          _pcStatusNotifications = value;
          break;
        case 'scheduled_backup_reminders':
          _scheduledBackupReminders = value;
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: const Color(0xFF83509F),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          _buildSectionHeader('General'),
          _buildSwitchTile(
            'Enable Notifications',
            'Turn on all notifications',
            _enableNotifications,
            (value) => _saveSetting('enable_notifications', value),
          ),
          const Divider(height: 1),
          _buildSectionHeader('Backup Notifications'),
          _buildSwitchTile(
            'Backup Completion',
            'Get notified when backups complete',
            _backupNotifications,
            (value) => _saveSetting('backup_notifications', value),
            enabled: _enableNotifications,
          ),
          _buildSwitchTile(
            'Backup Failures',
            'Get notified when backups fail',
            true,
            (value) => _saveSetting('backup_notifications', value),
            enabled: _enableNotifications && _backupNotifications,
          ),
          _buildSwitchTile(
            'Scheduled Reminders',
            'Get reminders before scheduled backups',
            _scheduledBackupReminders,
            (value) => _saveSetting('scheduled_backup_reminders', value),
            enabled: _enableNotifications,
          ),
          const Divider(height: 1),
          _buildSectionHeader('System Notifications'),
          _buildSwitchTile(
            'Health Check Warnings',
            'Get notified about health issues',
            _healthCheckWarnings,
            (value) => _saveSetting('health_check_warnings', value),
            enabled: _enableNotifications,
          ),
          _buildSwitchTile(
            'PC Status Changes',
            'Get notified when PC app status changes',
            _pcStatusNotifications,
            (value) => _saveSetting('pc_status_notifications', value),
            enabled: _enableNotifications,
          ),
          const Divider(height: 1),
          _buildSectionHeader('About'),
          _buildInfoTile(
            'Local Notifications',
            'Notifications are shown on your device',
          ),
          _buildInfoTile(
            'FCM Notifications',
            'Configured - push notifications enabled',
          ),
          _buildFCMTokenTile(),
        ],
      ),
    );
  }

  Widget _buildFCMTokenTile() {
    if (_isLoadingToken) {
      return const ListTile(
        title: Text('FCM Token'),
        subtitle: Text('Loading...'),
        leading: Icon(Icons.key, color: Color(0xFF83509F)),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      );
    }

    if (_fcmToken == null) {
      return ListTile(
        title: const Text('FCM Token'),
        subtitle: const Text('Not available'),
        leading: const Icon(Icons.key, color: Color(0xFF83509F)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      );
    }

    return ListTile(
      title: const Text('FCM Token'),
      subtitle: Text(
        _fcmToken!,
        style: const TextStyle(fontSize: 10),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      leading: const Icon(Icons.key, color: Color(0xFF83509F)),
      trailing: IconButton(
        icon: const Icon(Icons.copy),
        onPressed: _copyTokenToClipboard,
        tooltip: 'Copy token',
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF83509F),
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged, {
    bool enabled = true,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: enabled ? Colors.grey[600] : Colors.grey[400],
        ),
      ),
      value: value,
      onChanged: enabled ? onChanged : null,
      activeThumbColor: const Color(0xFF83509F),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildInfoTile(String title, String subtitle) {
    return ListTile(
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12),
      ),
      leading: const Icon(Icons.info_outline, color: Color(0xFF83509F)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
