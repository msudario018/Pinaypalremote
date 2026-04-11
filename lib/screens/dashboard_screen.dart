import 'package:flutter/material.dart';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import '../services/firebase_service.dart';
import 'backup_history_screen.dart';
import 'backup_settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isPcOnline = false;
  bool _isLoading = true;
  String? _username;
  Timer? _refreshTimer;
  Timer? _systemStatsTimer;

  // Backup data
  Map<String, dynamic>? _storageUsage;
  Map<String, dynamic>? _backupProgress;
  List<Map<String, dynamic>> _backupHistory = [];

  // System stats
  Map<String, dynamic>? _systemStats;

  // Activity feed
  List<Map<String, dynamic>> _activityLog = [];
  String _selectedActivityFilter = 'all';

  // Backup files
  List<Map<String, dynamic>> _backupFiles = [];

  // Backup schedule
  Map<String, dynamic>? _backupSchedule;

  // Backup health
  Map<String, dynamic>? _backupHealth;

  // Countdown timer
  Timer? _countdownTimer;
  Map<String, DateTime?> _nextBackupTimes = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    // Refresh data every 60 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _loadData();
    });
    // Update countdown every second
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _systemStatsTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    _username = FirebaseService.currentUsername;
    if (_username != null) {
      try {
        final results = await Future.wait([
          FirebaseService.isPcAppOnline(_username!),
          FirebaseService.getStorageUsage(_username!),
          FirebaseService.getBackupProgress(_username!),
          FirebaseService.getBackupHistory(_username!),
          FirebaseService.getSystemStats(_username!),
          FirebaseService.getActivityLog(_username!),
          FirebaseService.getBackupFiles(_username!),
          FirebaseService.getBackupSchedule(),
          FirebaseService.getBackupHealth(_username!),
        ]);

        if (mounted) {
          setState(() {
            _isPcOnline = results[0] as bool;
            _storageUsage = results[1] as Map<String, dynamic>?;
            _backupProgress = results[2] as Map<String, dynamic>?;
            _backupHistory = results[3] as List<Map<String, dynamic>>;
            _systemStats = results[4] as Map<String, dynamic>?;
            _activityLog = results[5] as List<Map<String, dynamic>>;
            _backupFiles = results[6] as List<Map<String, dynamic>>;
            _backupSchedule = results[7] as Map<String, dynamic>?;
            _backupHealth = results[8] as Map<String, dynamic>?;
            _isLoading = false;
          });
          _calculateNextBackupTimes();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // PC Status Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: _isPcOnline
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.red.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isPcOnline ? Icons.computer : Icons.computer,
                              size: 40,
                              color: _isPcOnline ? Colors.green : Colors.red,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'PC App Status',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _isPcOnline ? Colors.green : Colors.red,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isPcOnline
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isPcOnline ? 'Online' : 'Offline',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _isPcOnline
                                ? 'Your PC app is connected and active'
                                : 'Your PC app is not currently connected',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.grey,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Quick Stats Row
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quick Stats',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildQuickStatCard(
                                  'Total Backups',
                                  _backupHistory.length.toString(),
                                  Icons.backup,
                                  const Color(0xFF83509F),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildQuickStatCard(
                                  'Success Rate',
                                  _calculateSuccessRate(),
                                  Icons.check_circle,
                                  Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildQuickStatCard(
                                  'Total Storage',
                                  _calculateTotalStorage(),
                                  Icons.storage,
                                  Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildQuickStatCard(
                                  'Last Backup',
                                  _getLastBackupTime(),
                                  Icons.access_time,
                                  Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Backup Health Summary Cards
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Backup Health',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 16),
                          _buildHealthSummaryCard(
                            'Website',
                            Icons.language,
                            Colors.blue,
                            _getWebsiteBackupHealth(),
                            _getWebsiteLastBackupTime(),
                          ),
                          const SizedBox(height: 12),
                          _buildHealthSummaryCard(
                            'SQL',
                            Icons.storage,
                            Colors.orange,
                            _getSqlBackupHealth(),
                            _getSqlLastBackupTime(),
                          ),
                          const SizedBox(height: 12),
                          _buildHealthSummaryCard(
                            'Mailchimp',
                            Icons.email,
                            Colors.purple,
                            _getMailchimpBackupHealth(),
                            _getMailchimpLastBackupTime(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Recent Backups List
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF83509F)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.history,
                                  color: Color(0xFF83509F),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Recent Backups',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_backupHistory.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Text('No backups yet'),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _backupHistory.length > 5
                                  ? 5
                                  : _backupHistory.length,
                              itemBuilder: (context, index) {
                                final backup = _backupHistory[index];
                                return _buildRecentBackupItem(backup);
                              },
                            ),
                          if (_backupHistory.length > 5) ...[
                            const SizedBox(height: 12),
                            Center(
                              child: TextButton(
                                onPressed: () {
                                  if (_username != null) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => BackupHistoryScreen(
                                          username: _username!,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: const Text('View All'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Backup Schedule Overview
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF83509F)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.schedule,
                                  color: Color(0xFF83509F),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Backup Schedule',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.settings),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const BackupSettingsScreen(),
                                    ),
                                  );
                                },
                                tooltip: 'Configure Schedule',
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildScheduleItem(
                              'Website',
                              _getScheduleText('website'),
                              Icons.language,
                              Colors.blue),
                          const SizedBox(height: 12),
                          _buildScheduleItem('SQL', _getScheduleText('sql'),
                              Icons.storage, Colors.orange),
                          const SizedBox(height: 12),
                          _buildScheduleItem(
                              'Mailchimp',
                              _getScheduleText('mailchimp'),
                              Icons.email,
                              Colors.purple),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Quick Actions Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quick Actions',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 16),
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF83509F)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.refresh,
                                color: Color(0xFF83509F),
                              ),
                            ),
                            title: const Text('Refresh Status'),
                            subtitle: const Text('Check PC connection status'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _loadData,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Backup Management Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF83509F)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.backup,
                                  color: Color(0xFF83509F),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Backup Management',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_backupProgress != null) ...[
                            LinearProgressIndicator(
                              value:
                                  (_backupProgress!['percentage'] ?? 0) / 100,
                              backgroundColor: Colors.grey[300],
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF83509F),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Backup in progress: ${_backupProgress!['percentage'] ?? 0}%',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_storageUsage != null) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Storage Used:'),
                                Text(
                                  '${_storageUsage!['used'] ?? '0'} / ${_storageUsage!['total'] ?? '0'} GB',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value:
                                  (_storageUsage!['usedPercentage'] ?? 0) / 100,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                (_storageUsage!['usedPercentage'] ?? 0) > 80
                                    ? Colors.red
                                    : const Color(0xFF83509F),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          // Backup control buttons
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _isPcOnline ? _startBackup : null,
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('Start Backup'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF83509F),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isPcOnline ? _stopBackup : null,
                                  icon: const Icon(Icons.stop),
                                  label: const Text('Stop Backup'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF83509F)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.history,
                                color: Color(0xFF83509F),
                              ),
                            ),
                            title: const Text('Backup History'),
                            subtitle: Text('${_backupHistory.length} backups'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              if (_username != null) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => BackupHistoryScreen(
                                      username: _username!,
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // System Monitoring Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF83509F)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.monitor,
                                  color: Color(0xFF83509F),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'System Monitoring',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_systemStats != null || _storageUsage != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_systemStats != null) ...[
                                  _buildStatRow(
                                      'CPU',
                                      _systemStats!['cpu'] ?? '0%',
                                      Icons.memory),
                                  const SizedBox(height: 12),
                                  _buildStatRow(
                                      'Memory',
                                      _systemStats!['memory'] ?? '0%',
                                      Icons.storage),
                                  const SizedBox(height: 12),
                                ],
                                if (_storageUsage != null) ...[
                                  _buildStatRow(
                                      'Backup Size',
                                      '${_storageUsage!['total'] ?? '0'} GB',
                                      Icons.sd_storage),
                                  const SizedBox(height: 12),
                                ],
                                if (_systemStats != null)
                                  _buildStatRow(
                                      'PC App Uptime',
                                      _systemStats!['pcAppUptime'] ??
                                          _systemStats!['uptime'] ??
                                          '0h',
                                      Icons.access_time),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Activity Feed Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF83509F)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.feed,
                                  color: Color(0xFF83509F),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Activity Feed',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Activity filter chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildActivityFilterChip('All', 'all'),
                                const SizedBox(width: 8),
                                _buildActivityFilterChip('Backup', 'backup'),
                                const SizedBox(width: 8),
                                _buildActivityFilterChip('Error', 'error'),
                                const SizedBox(width: 8),
                                _buildActivityFilterChip('Warning', 'warning'),
                                const SizedBox(width: 8),
                                _buildActivityFilterChip('Success', 'success'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_activityLog.isEmpty)
                            const Text('No recent activity')
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _getFilteredActivities().length > 5
                                  ? 5
                                  : _getFilteredActivities().length,
                              itemBuilder: (context, index) {
                                final activity =
                                    _getFilteredActivities()[index];
                                return Card(
                                  elevation: 1,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: _getActivityColor(
                                                    activity['type'] ?? 'info')
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: _getActivityIcon(
                                              activity['type'] ?? 'info'),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                activity['message'] ??
                                                    'Unknown',
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w500),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _formatRelativeTime(
                                                    activity['timestamp'] ??
                                                        ''),
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600]),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Next Scheduled Backup Countdown Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF83509F)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.timer_outlined,
                                  color: Color(0xFF83509F),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Next Scheduled Backup',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildCountdownCard('Website', Icons.language,
                              Colors.blue, 'website'),
                          const SizedBox(height: 12),
                          _buildCountdownCard(
                              'SQL', Icons.storage, Colors.orange, 'sql'),
                          const SizedBox(height: 12),
                          _buildCountdownCard('Mailchimp', Icons.email,
                              Colors.purple, 'mailchimp'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // File Browser Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF83509F)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.folder,
                                  color: Color(0xFF83509F),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Backup Files',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_backupFiles.isEmpty)
                            const Text('No backup files available')
                          else
                            ListTile(
                              leading: const Icon(Icons.insert_drive_file,
                                  color: Color(0xFF83509F)),
                              title:
                                  Text('${_backupFiles.length} backup files'),
                              subtitle: Text('Click to view all files'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _showBackupFilesDialog(context),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF83509F)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Icon _getActivityIcon(String type) {
    switch (type.toLowerCase()) {
      case 'backup':
        return const Icon(Icons.backup, color: Color(0xFF83509F));
      case 'error':
        return const Icon(Icons.error, color: Colors.red);
      case 'warning':
        return const Icon(Icons.warning, color: Colors.orange);
      case 'success':
        return const Icon(Icons.check_circle, color: Colors.green);
      default:
        return const Icon(Icons.info, color: Colors.blue);
    }
  }

  Color _getActivityColor(String type) {
    switch (type.toLowerCase()) {
      case 'backup':
        return const Color(0xFF83509F);
      case 'error':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'success':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  List<Map<String, dynamic>> _getFilteredActivities() {
    if (_selectedActivityFilter == 'all') {
      return _activityLog;
    }
    return _activityLog
        .where((activity) =>
            activity['type']?.toString().toLowerCase() ==
            _selectedActivityFilter)
        .toList();
  }

  Widget _buildActivityFilterChip(String label, String value) {
    return FilterChip(
      label: Text(label),
      selected: _selectedActivityFilter == value,
      onSelected: (selected) {
        setState(() {
          _selectedActivityFilter = selected ? value : 'all';
        });
      },
      selectedColor: const Color(0xFF83509F).withValues(alpha: 0.2),
      checkmarkColor: const Color(0xFF83509F),
    );
  }

  String _formatRelativeTime(String timestamp) {
    // Handle "Never" case
    if (timestamp == 'Never' || timestamp.isEmpty) {
      return 'Never';
    }

    try {
      DateTime dateTime;

      // Try parsing as ISO8601 first
      try {
        dateTime = DateTime.parse(timestamp);
      } catch (e) {
        // If that fails, try parsing as milliseconds since epoch
        try {
          final ms = int.parse(timestamp);
          dateTime = DateTime.fromMillisecondsSinceEpoch(ms);
        } catch (_) {
          return 'Unknown';
        }
      }

      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  Widget _buildStoragePieChart() {
    try {
      // Calculate storage by category from backup files
      final websiteFiles =
          _backupFiles.where((f) => f['category'] == 'website').toList();
      final sqlFiles =
          _backupFiles.where((f) => f['category'] == 'sql').toList();
      final mailchimpFiles =
          _backupFiles.where((f) => f['category'] == 'mailchimp').toList();

      final websiteSize = _calculateTotalSize(websiteFiles);
      final sqlSize = _calculateTotalSize(sqlFiles);
      final mailchimpSize = _calculateTotalSize(mailchimpFiles);
      final totalSize = websiteSize + sqlSize + mailchimpSize;

      if (totalSize == 0 || _backupFiles.isEmpty) {
        return const Center(
          child: Text('No storage data available'),
        );
      }

      final data = <PieChartSectionData>[];

      if (websiteSize > 0) {
        data.add(PieChartSectionData(
          value: websiteSize.toDouble(),
          title: '${((websiteSize / totalSize) * 100).toStringAsFixed(1)}%',
          color: Colors.blue,
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ));
      }

      if (sqlSize > 0) {
        data.add(PieChartSectionData(
          value: sqlSize.toDouble(),
          title: '${((sqlSize / totalSize) * 100).toStringAsFixed(1)}%',
          color: Colors.orange,
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ));
      }

      if (mailchimpSize > 0) {
        data.add(PieChartSectionData(
          value: mailchimpSize.toDouble(),
          title: '${((mailchimpSize / totalSize) * 100).toStringAsFixed(1)}%',
          color: Colors.purple,
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ));
      }

      return PieChart(
        PieChartData(
          sections: data,
          centerSpaceRadius: 40,
          sectionsSpace: 2,
          borderData: FlBorderData(show: false),
        ),
      );
    } catch (e) {
      print('[DashboardScreen] Error building pie chart: $e');
      return const Center(
        child: Text('Error loading chart'),
      );
    }
  }

  Widget _buildStorageLegend() {
    try {
      final websiteFiles =
          _backupFiles.where((f) => f['category'] == 'website').toList();
      final sqlFiles =
          _backupFiles.where((f) => f['category'] == 'sql').toList();
      final mailchimpFiles =
          _backupFiles.where((f) => f['category'] == 'mailchimp').toList();

      final websiteSize = _calculateTotalSize(websiteFiles);
      final sqlSize = _calculateTotalSize(sqlFiles);
      final mailchimpSize = _calculateTotalSize(mailchimpFiles);
      final totalSize = websiteSize + sqlSize + mailchimpSize;

      return Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          if (websiteSize > 0)
            _buildLegendItem('Website', Colors.blue, websiteSize, totalSize),
          if (sqlSize > 0)
            _buildLegendItem('SQL', Colors.orange, sqlSize, totalSize),
          if (mailchimpSize > 0)
            _buildLegendItem(
                'Mailchimp', Colors.purple, mailchimpSize, totalSize),
        ],
      );
    } catch (e) {
      print('[DashboardScreen] Error building legend: $e');
      return const SizedBox.shrink();
    }
  }

  Widget _buildLegendItem(String label, Color color, int size, int total) {
    try {
      final percentage =
          total > 0 ? (size / total * 100).toStringAsFixed(1) : '0.0';
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: $percentage%',
            style: const TextStyle(fontSize: 13),
          ),
        ],
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  int _calculateTotalSize(List<Map<String, dynamic>> files) {
    try {
      int total = 0;
      for (var file in files) {
        final sizeStr = file['size']?.toString() ?? '0';
        final size = _parseSize(sizeStr);
        total += size;
      }
      return total;
    } catch (e) {
      return 0;
    }
  }

  int _parseSize(String sizeStr) {
    try {
      if (sizeStr.isEmpty) return 0;
      final numericStr = sizeStr.replaceAll(RegExp(r'[^0-9.]'), '');
      if (numericStr.isEmpty) return 0;

      final value = double.tryParse(numericStr) ?? 0;

      if (sizeStr.toLowerCase().contains('mb')) {
        return (value * 1024 * 1024).toInt();
      } else if (sizeStr.toLowerCase().contains('gb')) {
        return (value * 1024 * 1024 * 1024).toInt();
      } else if (sizeStr.toLowerCase().contains('kb')) {
        return (value * 1024).toInt();
      }
      return value.toInt();
    } catch (e) {
      return 0;
    }
  }

  Widget _buildQuickStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _calculateSuccessRate() {
    if (_backupHistory.isEmpty) return '0%';
    final successful =
        _backupHistory.where((b) => b['status'] == 'success').length;
    final rate = (successful / _backupHistory.length * 100).toStringAsFixed(1);
    return '$rate%';
  }

  String _calculateTotalStorage() {
    final totalSize = _calculateTotalSize(_backupFiles);
    if (totalSize >= 1024 * 1024 * 1024) {
      return '${(totalSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    } else if (totalSize >= 1024 * 1024) {
      return '${(totalSize / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else if (totalSize >= 1024) {
      return '${(totalSize / 1024).toStringAsFixed(2)} KB';
    }
    return '$totalSize B';
  }

  String _getLastBackupTime() {
    if (_backupHistory.isEmpty) return 'Never';
    try {
      final lastBackup = _backupHistory.first;
      final timestamp = lastBackup['timestamp']?.toString() ?? '';
      return _formatRelativeTime(timestamp);
    } catch (e) {
      return 'Unknown';
    }
  }

  Widget _buildHealthSummaryCard(String service, IconData icon, Color color,
      String status, String lastBackup) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Last: $lastBackup',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getHealthColor(status),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getWebsiteBackupHealth() {
    if (_backupHealth != null && _backupHealth!.containsKey('website')) {
      return _backupHealth!['website']?.toString() ?? 'unknown';
    }
    final websiteBackups = _backupHistory
        .where((b) => b['type'] == 'website' || b['type'] == 'ftp')
        .toList();
    if (websiteBackups.isEmpty) return 'unknown';
    return websiteBackups.first['status']?.toString() ?? 'unknown';
  }

  String _getWebsiteLastBackupTime() {
    if (_backupHealth != null &&
        _backupHealth!.containsKey('website_last_backup')) {
      final timestamp = _backupHealth!['website_last_backup']?.toString() ?? '';
      if (timestamp.isNotEmpty) return _formatRelativeTime(timestamp);
    }
    final websiteBackups = _backupHistory
        .where((b) => b['type'] == 'website' || b['type'] == 'ftp')
        .toList();
    if (websiteBackups.isEmpty) return 'Never';
    try {
      final timestamp = websiteBackups.first['timestamp']?.toString() ?? '';
      return _formatRelativeTime(timestamp);
    } catch (e) {
      return 'Unknown';
    }
  }

  String _getSqlBackupHealth() {
    if (_backupHealth != null && _backupHealth!.containsKey('sql')) {
      return _backupHealth!['sql']?.toString() ?? 'unknown';
    }
    final sqlBackups = _backupHistory.where((b) => b['type'] == 'sql').toList();
    if (sqlBackups.isEmpty) return 'unknown';
    return sqlBackups.first['status']?.toString() ?? 'unknown';
  }

  String _getSqlLastBackupTime() {
    if (_backupHealth != null &&
        _backupHealth!.containsKey('sql_last_backup')) {
      final timestamp = _backupHealth!['sql_last_backup']?.toString() ?? '';
      if (timestamp.isNotEmpty) return _formatRelativeTime(timestamp);
    }
    final sqlBackups = _backupHistory.where((b) => b['type'] == 'sql').toList();
    if (sqlBackups.isEmpty) return 'Never';
    try {
      final timestamp = sqlBackups.first['timestamp']?.toString() ?? '';
      return _formatRelativeTime(timestamp);
    } catch (e) {
      return 'Unknown';
    }
  }

  String _getMailchimpBackupHealth() {
    if (_backupHealth != null && _backupHealth!.containsKey('mailchimp')) {
      return _backupHealth!['mailchimp']?.toString() ?? 'unknown';
    }
    final mailchimpBackups =
        _backupHistory.where((b) => b['type'] == 'mailchimp').toList();
    if (mailchimpBackups.isEmpty) return 'unknown';
    return mailchimpBackups.first['status']?.toString() ?? 'unknown';
  }

  String _getMailchimpLastBackupTime() {
    if (_backupHealth != null &&
        _backupHealth!.containsKey('mailchimp_last_backup')) {
      final timestamp =
          _backupHealth!['mailchimp_last_backup']?.toString() ?? '';
      if (timestamp.isNotEmpty) return _formatRelativeTime(timestamp);
    }
    final mailchimpBackups =
        _backupHistory.where((b) => b['type'] == 'mailchimp').toList();
    if (mailchimpBackups.isEmpty) return 'Never';
    try {
      final timestamp = mailchimpBackups.first['timestamp']?.toString() ?? '';
      return _formatRelativeTime(timestamp);
    } catch (e) {
      return 'Unknown';
    }
  }

  Color _getHealthColor(String status) {
    switch (status.toLowerCase()) {
      case 'ok':
      case 'success':
        return Colors.green;
      case 'outdated':
      case 'incomplete':
      case 'warning':
        return Colors.orange;
      case 'error':
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildRecentBackupItem(Map<String, dynamic> backup) {
    final status = backup['status']?.toString() ?? 'unknown';
    final type = backup['type']?.toString() ?? 'backup';
    final timestamp = backup['timestamp']?.toString() ?? '';
    final color = _getHealthColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getBackupTypeIcon(type),
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatRelativeTime(timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getBackupStatusIcon(status),
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  status.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getBackupTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'website':
      case 'ftp':
        return Icons.language;
      case 'sql':
        return Icons.storage;
      case 'mailchimp':
        return Icons.email;
      default:
        return Icons.backup;
    }
  }

  IconData _getBackupStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'ok':
      case 'success':
        return Icons.check_circle;
      case 'outdated':
      case 'incomplete':
      case 'warning':
        return Icons.warning;
      case 'error':
      case 'failed':
        return Icons.error;
      default:
        return Icons.help;
    }
  }

  Widget _buildScheduleItem(
      String service, String schedule, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  schedule,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: Colors.grey[400],
          ),
        ],
      ),
    );
  }

  String _getScheduleText(String serviceKey) {
    if (_backupSchedule == null) return 'Not configured';
    final serviceSchedule =
        _backupSchedule![serviceKey] as Map<String, dynamic>?;
    if (serviceSchedule == null) return 'Not configured';

    final enabled = serviceSchedule['enabled'] as bool? ?? false;
    if (!enabled) return 'Disabled';

    final frequency = serviceSchedule['frequency'] as String? ?? 'daily';
    final time = serviceSchedule['time'] as String? ?? '';
    final day = serviceSchedule['day'] as String? ?? '';

    switch (frequency) {
      case 'daily':
        return time.isNotEmpty
            ? 'Daily at ${_formatTimeTo12Hour(time)}'
            : 'Daily';
      case 'weekly':
        return day.isNotEmpty ? 'Weekly on $day' : 'Weekly';
      case 'monthly':
        return 'Monthly';
      default:
        return 'Not configured';
    }
  }

  void _showBackupFilesDialog(BuildContext context) {
    String selectedCategory = 'all';
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Backup Files'),
          content: SizedBox(
            width: double.maxFinite,
            height: 500,
            child: Column(
              children: [
                // Search bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search backup files...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value.toLowerCase();
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Category filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCategoryChip(
                        'All',
                        'all',
                        selectedCategory,
                        (category) =>
                            setState(() => selectedCategory = category),
                      ),
                      const SizedBox(width: 8),
                      _buildCategoryChip(
                        'Website',
                        'website',
                        selectedCategory,
                        (category) =>
                            setState(() => selectedCategory = category),
                      ),
                      const SizedBox(width: 8),
                      _buildCategoryChip(
                        'SQL',
                        'sql',
                        selectedCategory,
                        (category) =>
                            setState(() => selectedCategory = category),
                      ),
                      const SizedBox(width: 8),
                      _buildCategoryChip(
                        'Mailchimp',
                        'mailchimp',
                        selectedCategory,
                        (category) =>
                            setState(() => selectedCategory = category),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // File list
                Expanded(
                  child: _backupFiles.isEmpty
                      ? const Center(child: Text('No backup files available'))
                      : ListView.builder(
                          itemCount: _backupFiles.length,
                          itemBuilder: (context, index) {
                            final file = _backupFiles[index];
                            final category =
                                file['category']?.toString() ?? 'other';
                            final name =
                                file['name']?.toString().toLowerCase() ?? '';

                            // Filter by category and search query
                            if (selectedCategory != 'all' &&
                                category != selectedCategory) {
                              return const SizedBox.shrink();
                            }
                            if (searchQuery.isNotEmpty &&
                                !name.contains(searchQuery)) {
                              return const SizedBox.shrink();
                            }

                            return ListTile(
                              leading: _getCategoryIcon(category),
                              title: Text(file['name'] ?? 'Unknown'),
                              subtitle: Text(
                                  '${file['size'] ?? '0'} • ${file['date'] ?? ''}'),
                              trailing: const Icon(Icons.download),
                              onTap: () {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Downloading ${file['name'] ?? 'file'}'),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
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
      ),
    );
  }

  Widget _buildCategoryChip(
    String label,
    String value,
    String selectedCategory,
    Function(String) onSelected,
  ) {
    return FilterChip(
      label: Text(label),
      selected: selectedCategory == value,
      onSelected: (selected) {
        onSelected(value);
      },
      selectedColor: const Color(0xFF83509F).withValues(alpha: 0.2),
      checkmarkColor: const Color(0xFF83509F),
    );
  }

  Icon _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'website':
        return const Icon(Icons.language, color: Colors.blue);
      case 'sql':
        return const Icon(Icons.storage, color: Colors.orange);
      case 'mailchimp':
        return const Icon(Icons.email, color: Colors.purple);
      default:
        return const Icon(Icons.insert_drive_file, color: Color(0xFF83509F));
    }
  }

  Future<void> _startBackup() async {
    if (_username == null) return;

    try {
      final success = await FirebaseService.triggerBackup(_username!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(success ? 'Backup started' : 'Failed to start backup'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        if (success) _loadData();
      }
    } catch (e) {
      print('[DashboardScreen] Start backup failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting backup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopBackup() async {
    if (_username == null) return;

    try {
      final success = await FirebaseService.stopBackup(_username!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Backup stopped' : 'Failed to stop backup'),
            backgroundColor: success ? Colors.orange : Colors.red,
          ),
        );
        if (success) _loadData();
      }
    } catch (e) {
      print('[DashboardScreen] Stop backup failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error stopping backup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _calculateNextBackupTimes() {
    if (_backupSchedule == null) return;

    _nextBackupTimes = {
      'website': _calculateNextBackupTime('website'),
      'sql': _calculateNextBackupTime('sql'),
      'mailchimp': _calculateNextBackupTime('mailchimp'),
    };
  }

  DateTime? _calculateNextBackupTime(String serviceKey) {
    if (_backupSchedule == null) return null;
    final serviceSchedule =
        _backupSchedule![serviceKey] as Map<String, dynamic>?;
    if (serviceSchedule == null) return null;

    final enabled = serviceSchedule['enabled'] as bool? ?? false;
    if (!enabled) return null;

    final frequency = serviceSchedule['frequency'] as String? ?? 'daily';
    final time = serviceSchedule['time'] as String? ?? '';
    final day = serviceSchedule['day'] as String? ?? '';

    final now = DateTime.now();
    DateTime nextBackup;

    try {
      final timeParts = time.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      switch (frequency) {
        case 'daily':
          nextBackup = DateTime(now.year, now.month, now.day, hour, minute);
          if (nextBackup.isBefore(now)) {
            nextBackup = nextBackup.add(const Duration(days: 1));
          }
          break;
        case 'weekly':
          final dayIndex = _getDayIndex(day);
          final currentDayIndex = now.weekday;
          int daysUntilNext = dayIndex - currentDayIndex;
          if (daysUntilNext <= 0) {
            daysUntilNext += 7;
          }
          nextBackup = DateTime(now.year, now.month, now.day, hour, minute)
              .add(Duration(days: daysUntilNext));
          break;
        case 'monthly':
          nextBackup = DateTime(now.year, now.month, 1, hour, minute);
          if (nextBackup.isBefore(now)) {
            nextBackup = DateTime(
                nextBackup.year, nextBackup.month + 1, 1, hour, minute);
          }
          break;
        default:
          return null;
      }
      return nextBackup;
    } catch (e) {
      print('[DashboardScreen] Calculate next backup time error: $e');
      return null;
    }
  }

  int _getDayIndex(String dayName) {
    switch (dayName.toLowerCase()) {
      case 'monday':
        return 1;
      case 'tuesday':
        return 2;
      case 'wednesday':
        return 3;
      case 'thursday':
        return 4;
      case 'friday':
        return 5;
      case 'saturday':
        return 6;
      case 'sunday':
        return 7;
      default:
        return 1;
    }
  }

  Widget _buildCountdownCard(
      String label, IconData icon, Color color, String serviceKey) {
    final nextBackup = _nextBackupTimes[serviceKey];
    final isEnabled = _isServiceEnabled(serviceKey);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 4),
                if (!isEnabled)
                  Text(
                    'Disabled',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  )
                else if (nextBackup == null)
                  Text(
                    'Not scheduled',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  )
                else
                  Text(
                    _formatCountdown(nextBackup),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
              ],
            ),
          ),
          if (isEnabled && nextBackup != null)
            Icon(
              Icons.timer,
              size: 18,
              color: color.withOpacity(0.6),
            ),
        ],
      ),
    );
  }

  bool _isServiceEnabled(String serviceKey) {
    if (_backupSchedule == null) return false;
    final serviceSchedule =
        _backupSchedule![serviceKey] as Map<String, dynamic>?;
    return serviceSchedule?['enabled'] as bool? ?? false;
  }

  String _formatCountdown(DateTime nextBackup) {
    final now = DateTime.now();
    final difference = nextBackup.difference(now);

    if (difference.isNegative) {
      return 'Overdue';
    }

    if (difference.inDays > 0) {
      return '${difference.inDays}d ${difference.inHours % 24}h';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes % 60}m';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ${difference.inSeconds % 60}s';
    } else {
      return '${difference.inSeconds}s';
    }
  }

  String _formatTimeTo12Hour(String time24) {
    if (time24.isEmpty) return time24;
    final parts = time24.split(':');
    if (parts.length < 2) return time24;

    try {
      final hour = int.parse(parts[0]);
      final minute = parts[1];

      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour % 12 == 0 ? 12 : hour % 12;

      return '${hour12}:$minute $period';
    } catch (e) {
      return time24;
    }
  }
}
