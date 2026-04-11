import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class BackupHistoryScreen extends StatefulWidget {
  final String username;
  const BackupHistoryScreen({super.key, required this.username});

  @override
  State<BackupHistoryScreen> createState() => _BackupHistoryScreenState();
}

class _BackupHistoryScreenState extends State<BackupHistoryScreen> {
  List<Map<String, dynamic>> _backupHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBackupHistory();
  }

  Future<void> _loadBackupHistory() async {
    try {
      final history = await FirebaseService.getBackupHistory(widget.username);
      if (mounted) {
        setState(() {
          _backupHistory = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[BackupHistoryScreen] Load backup history failed: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return 'Unknown';
    try {
      final date = DateTime.parse(isoDate);
      return '${date.month}/${date.day}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup History'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _backupHistory.isEmpty
              ? const Center(child: Text('No backup history available'))
              : RefreshIndicator(
                  onRefresh: _loadBackupHistory,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _backupHistory.length,
                    itemBuilder: (context, index) {
                      final backup = _backupHistory[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: Container(
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
                          title: Text(backup['name'] ?? 'Unknown'),
                          subtitle: Text(
                              'Size: ${backup['size'] ?? '0'} • ${_formatDate(backup['timestamp'])}'),
                          trailing: Icon(
                            backup['status'] == 'success'
                                ? Icons.check_circle
                                : Icons.error,
                            color: backup['status'] == 'success'
                                ? Colors.green
                                : Colors.red,
                          ),
                          onTap: () => _showBackupDetails(backup),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  void _showBackupDetails(Map<String, dynamic> backup) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(backup['name'] ?? 'Backup Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${backup['name'] ?? 'N/A'}'),
            const SizedBox(height: 8),
            Text('Size: ${backup['size'] ?? 'N/A'}'),
            const SizedBox(height: 8),
            Text('Status: ${backup['status'] ?? 'N/A'}'),
            const SizedBox(height: 8),
            Text('Timestamp: ${_formatDate(backup['timestamp'])}'),
            const SizedBox(height: 8),
            if (backup['path'] != null)
              Text('Path: ${backup['path']}'),
          ],
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
}
