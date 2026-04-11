import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  // Backup schedule settings
  Map<String, dynamic> _schedule = {
    'website': {'enabled': true, 'frequency': 'daily', 'time': '02:00'},
    'sql': {'enabled': true, 'frequency': 'daily', 'time': '03:00'},
    'mailchimp': {'enabled': true, 'frequency': 'weekly', 'day': 'Sunday'},
  };

  // Auto scan settings
  Map<String, dynamic> _autoScan = {
    'website': {'hours': 3, 'minutes': 0},
    'sql': {'hours': 2, 'minutes': 15},
    'mailchimp': {'hours': 2, 'minutes': 0},
  };

  // Health threshold settings
  Map<String, dynamic> _healthThresholds = {
    'website': {'maxAgeHours': 24},
    'sql': {'maxAgeHours': 24},
    'mailchimp': {'maxAgeHours': 168}, // 7 days
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final schedule = await FirebaseService.getBackupSchedule();
      final thresholds = await FirebaseService.getHealthThresholds();
      final autoScan = await FirebaseService.getAutoScanSettings();

      if (mounted) {
        setState(() {
          if (schedule != null) _schedule = schedule;
          if (thresholds != null) _healthThresholds = thresholds;
          if (autoScan != null) _autoScan = autoScan;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[BackupSettingsScreen] Load settings failed: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final scheduleSaved = await FirebaseService.saveBackupSchedule(_schedule);
      final thresholdsSaved =
          await FirebaseService.saveHealthThresholds(_healthThresholds);
      final autoScanSaved = await FirebaseService.saveAutoScanSettings(_autoScan);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(scheduleSaved && thresholdsSaved && autoScanSaved
                ? 'Settings saved successfully'
                : 'Failed to save some settings'),
            backgroundColor:
                scheduleSaved && thresholdsSaved && autoScanSaved ? Colors.green : Colors.orange,
          ),
        );
        setState(() => _isSaving = false);
      }
    } catch (e) {
      print('[BackupSettingsScreen] Save settings failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save settings'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup Settings'),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isSaving ? null : _saveSettings,
              tooltip: 'Save Settings',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionHeader('Backup Schedule'),
                const SizedBox(height: 16),
                _buildServiceSection('Website', 'website', Icons.language, Colors.blue),
                const SizedBox(height: 20),
                _buildServiceSection('SQL', 'sql', Icons.storage, Colors.orange),
                const SizedBox(height: 20),
                _buildServiceSection('Mailchimp', 'mailchimp', Icons.email, Colors.purple),
                const SizedBox(height: 24),
                _buildSectionHeader('Health Thresholds'),
                const SizedBox(height: 16),
                _buildHealthThresholdCard(
                    'Website', 'website', Icons.language, Colors.blue),
                const SizedBox(height: 12),
                _buildHealthThresholdCard(
                    'SQL', 'sql', Icons.storage, Colors.orange),
                const SizedBox(height: 12),
                _buildHealthThresholdCard(
                    'Mailchimp', 'mailchimp', Icons.email, Colors.purple),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildServiceSection(
      String label, String key, IconData icon, Color color) {
    final serviceSchedule = _schedule[key] as Map<String, dynamic>?;
    final autoScanSettings = _autoScan[key] as Map<String, dynamic>?;
    final enabled = serviceSchedule?['enabled'] as bool? ?? false;
    final frequency = serviceSchedule?['frequency'] as String? ?? 'daily';
    final time = serviceSchedule?['time'] as String? ?? '';
    final day = serviceSchedule?['day'] as String? ?? '';
    final autoScanHours = autoScanSettings?['hours'] as int? ?? 0;
    final autoScanMinutes = autoScanSettings?['minutes'] as int? ?? 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with enable switch
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ),
                Switch(
                  value: enabled,
                  onChanged: (value) {
                    setState(() {
                      _schedule[key] = {
                        ..._schedule[key] as Map<String, dynamic>,
                        'enabled': value,
                      };
                    });
                  },
                ),
              ],
            ),
            if (enabled) ...[
              const SizedBox(height: 20),
              // Daily Schedule Section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 18, color: color),
                        const SizedBox(width: 8),
                        Text(
                          'Daily Backup Schedule',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: frequency,
                            decoration: const InputDecoration(
                              labelText: 'Frequency',
                              border: OutlineInputBorder(),
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'daily', child: Text('Daily')),
                              DropdownMenuItem(
                                  value: 'weekly', child: Text('Weekly')),
                              DropdownMenuItem(
                                  value: 'monthly', child: Text('Monthly')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _schedule[key] = {
                                    ..._schedule[key] as Map<String, dynamic>,
                                    'frequency': value,
                                  };
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (frequency == 'daily')
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectTime(context, key),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                    time.isNotEmpty
                                        ? _formatTimeTo12Hour(time)
                                        : 'Select time',
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                    const Spacer(),
                                    const Icon(Icons.access_time, size: 20),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (frequency == 'weekly')
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: day,
                              decoration: const InputDecoration(
                                labelText: 'Day',
                                border: OutlineInputBorder(),
                                contentPadding:
                                    EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: 'Monday', child: Text('Monday')),
                                DropdownMenuItem(
                                    value: 'Tuesday', child: Text('Tuesday')),
                                DropdownMenuItem(
                                    value: 'Wednesday', child: Text('Wednesday')),
                                DropdownMenuItem(
                                    value: 'Thursday', child: Text('Thursday')),
                                DropdownMenuItem(
                                    value: 'Friday', child: Text('Friday')),
                                DropdownMenuItem(
                                    value: 'Saturday', child: Text('Saturday')),
                                DropdownMenuItem(
                                    value: 'Sunday', child: Text('Sunday')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _schedule[key] = {
                                      ..._schedule[key] as Map<String, dynamic>,
                                      'day': value,
                                    };
                                  });
                                }
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Auto Scan Section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.scanner, size: 18, color: color),
                        const SizedBox(width: 8),
                        Text(
                          'Auto-Scan Interval',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Hours', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove, size: 18),
                                      onPressed: () {
                                        setState(() {
                                          _autoScan[key] = {
                                            ..._autoScan[key] as Map<String, dynamic>,
                                            'hours': (autoScanHours > 0) ? autoScanHours - 1 : 0,
                                          };
                                        });
                                      },
                                    ),
                                    SizedBox(
                                      width: 40,
                                      child: Text(
                                        autoScanHours.toString(),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add, size: 18),
                                      onPressed: () {
                                        setState(() {
                                          _autoScan[key] = {
                                            ..._autoScan[key] as Map<String, dynamic>,
                                            'hours': (autoScanHours < 23) ? autoScanHours + 1 : 23,
                                          };
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Minutes', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove, size: 18),
                                      onPressed: () {
                                        setState(() {
                                          _autoScan[key] = {
                                            ..._autoScan[key] as Map<String, dynamic>,
                                            'minutes': (autoScanMinutes > 0) ? autoScanMinutes - 15 : 0,
                                          };
                                        });
                                      },
                                    ),
                                    SizedBox(
                                      width: 40,
                                      child: Text(
                                        autoScanMinutes.toString(),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add, size: 18),
                                      onPressed: () {
                                        setState(() {
                                          _autoScan[key] = {
                                            ..._autoScan[key] as Map<String, dynamic>,
                                            'minutes': (autoScanMinutes < 59) ? autoScanMinutes + 15 : 59,
                                          };
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Periodic health check interval (e.g., 3h 0m = every 3 hours)',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHealthThresholdCard(
      String label, String key, IconData icon, Color color) {
    final threshold = _healthThresholds[key] as Map<String, dynamic>?;
    final maxAgeHours = threshold?['maxAgeHours'] as int? ?? 24;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Max Age: '),
                      SizedBox(
                        width: 80,
                        child: TextFormField(
                          initialValue: maxAgeHours.toString(),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                          ),
                          onChanged: (value) {
                            final hours = int.tryParse(value) ?? 24;
                            setState(() {
                              _healthThresholds[key] = {
                                ..._healthThresholds[key]
                                    as Map<String, dynamic>,
                                'maxAgeHours': hours,
                              };
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('hours'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTime(BuildContext context, String key) async {
    final serviceSchedule = _schedule[key] as Map<String, dynamic>?;
    final time = serviceSchedule?['time'] as String? ?? '';

    TimeOfDay initialTime = TimeOfDay.now();
    if (time.isNotEmpty) {
      final parts = time.split(':');
      try {
        initialTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      } catch (e) {
        // Use default if parsing fails
      }
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null && mounted) {
      setState(() {
        final hour24 = picked.hour.toString().padLeft(2, '0');
        final minute = picked.minute.toString().padLeft(2, '0');
        _schedule[key] = {
          ..._schedule[key] as Map<String, dynamic>,
          'time': '$hour24:$minute',
        };
      });
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
