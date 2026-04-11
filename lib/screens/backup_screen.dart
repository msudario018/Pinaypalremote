import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _backupFiles = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';
  String _searchQuery = '';
  bool _isPaused = false;
  Map<String, dynamic>? _pcStatus;
  Map<String, dynamic>? _backupHealth;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final files = await FirebaseService.getBackupFiles(
          FirebaseService.currentUsername ?? '');
      final pcStatus = await FirebaseService.getPcStatus(
          FirebaseService.currentUsername ?? '');
      final backupHealth = await FirebaseService.getBackupHealth(
          FirebaseService.currentUsername ?? '');

      if (mounted) {
        setState(() {
          _backupFiles = files;
          _pcStatus = pcStatus;
          _backupHealth = backupHealth;
          _isLoading = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      print('[BackupScreen] Load data failed: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredFiles {
    return _backupFiles.where((file) {
      final category = file['category']?.toString().toLowerCase() ?? 'other';
      final name = file['name']?.toString().toLowerCase() ?? '';

      if (_selectedCategory != 'all' && category != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isNotEmpty &&
          !name.contains(_searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF83509F), Color(0xFF6B3D8E)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.backup,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Backup Management',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: Icon(
              _isPaused
                  ? Icons.play_circle_outline
                  : Icons.pause_circle_outline,
              color: _isPaused ? Colors.orange : Colors.green,
              size: 28,
            ),
            onPressed: _togglePause,
            tooltip: _isPaused ? 'Resume Backups' : 'Pause Backups',
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF83509F), size: 24),
            onPressed: _syncFiles,
            tooltip: 'Sync Backup Files',
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: RefreshIndicator(
                onRefresh: _loadData,
                child: CustomScrollView(
                  slivers: [
                    if (_pcStatus != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildStatusCard(),
                        ),
                      ),
                    if (_backupHealth != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: _buildStorageBreakdown(),
                        ),
                      ),
                    if (_backupHealth != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Backup Health',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildHealthIndicator(
                                  'Website', _backupHealth?['website']),
                              _buildHealthIndicator(
                                  'Mailchimp', _backupHealth?['mailchimp']),
                              _buildHealthIndicator(
                                  'SQL', _backupHealth?['sql']),
                            ],
                          ),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quick Actions',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildModernBackupButton(
                                    'Website',
                                    Icons.language,
                                    Colors.blue,
                                    () => _triggerBackup('ftp'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildModernBackupButton(
                                    'Mailchimp',
                                    Icons.email,
                                    Colors.purple,
                                    () => _triggerBackup('mailchimp'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildModernBackupButton(
                                    'SQL',
                                    Icons.storage,
                                    Colors.orange,
                                    () => _triggerBackup('sql'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          children: [
                            TextField(
                              decoration: InputDecoration(
                                hintText: 'Search backup files...',
                                prefixIcon: const Icon(Icons.search),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide:
                                      BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF83509F)),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                              onChanged: (value) {
                                setState(() => _searchQuery = value);
                              },
                            ),
                            const SizedBox(height: 12),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildModernChip('All', 'all'),
                                  const SizedBox(width: 8),
                                  _buildModernChip('Website', 'website'),
                                  const SizedBox(width: 8),
                                  _buildModernChip('SQL', 'sql'),
                                  const SizedBox(width: 8),
                                  _buildModernChip('Mailchimp', 'mailchimp'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: _filteredFiles.isEmpty
                          ? SliverToBoxAdapter(
                              child: SizedBox(
                                height: 400,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(24),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.folder_open,
                                          size: 48,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Text(
                                        'No backup files found',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Try changing filters or sync your files',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final file = _filteredFiles[index];
                                  return _buildModernFileCard(file, index);
                                },
                                childCount: _filteredFiles.length,
                              ),
                            ),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 100),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    if (_pcStatus == null) return const SizedBox.shrink();

    final isOnline =
        _pcStatus!['status'] == 'online' || _pcStatus!['isOnline'] == true;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isOnline
                        ? Colors.green.withValues(alpha: _pulseAnimation.value)
                        : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                );
              },
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PC Connection',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isOnline ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isOnline ? Icons.cloud_done : Icons.cloud_off,
              color: isOnline ? Colors.green : Colors.grey,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernBackupButton(
      String label, IconData icon, Color color, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageBreakdown() {
    if (_backupFiles.isEmpty) return const SizedBox.shrink();

    final websiteFiles =
        _backupFiles.where((f) => f['category'] == 'website').toList();
    final sqlFiles = _backupFiles.where((f) => f['category'] == 'sql').toList();
    final mailchimpFiles =
        _backupFiles.where((f) => f['category'] == 'mailchimp').toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Storage Breakdown',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildStorageItem('Website', websiteFiles.length, Colors.blue),
            const SizedBox(height: 8),
            _buildStorageItem('SQL', sqlFiles.length, Colors.orange),
            const SizedBox(height: 8),
            _buildStorageItem(
                'Mailchimp', mailchimpFiles.length, Colors.purple),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageItem(String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(label),
        const Spacer(),
        Text('$count files'),
      ],
    );
  }

  Widget _buildHealthIndicator(String label, dynamic status) {
    final statusStr = status?.toString() ?? 'unknown';
    Color color;
    IconData icon;

    switch (statusStr.toLowerCase()) {
      case 'ok':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'outdated':
      case 'incomplete':
        color = Colors.orange;
        icon = Icons.warning;
        break;
      default:
        color = Colors.red;
        icon = Icons.error;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            statusStr.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernChip(String label, String value) {
    final isSelected = _selectedCategory == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedCategory = selected ? value : 'all');
      },
      selectedColor: const Color(0xFF83509F).withValues(alpha: 0.2),
      checkmarkColor: const Color(0xFF83509F),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF83509F) : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isSelected ? const Color(0xFF83509F) : Colors.grey[300]!,
        ),
      ),
      backgroundColor: Colors.white,
    );
  }

  Widget _buildModernFileCard(Map<String, dynamic> file, int index) {
    final category = file['category']?.toString() ?? 'other';
    final color = category == 'website'
        ? Colors.blue
        : category == 'sql'
            ? Colors.orange
            : category == 'mailchimp'
                ? Colors.purple
                : const Color(0xFF83509F);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showFileDetails(file),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: _getCategoryIcon(category),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file['name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.storage,
                          size: 13,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          file['size'] ?? '0',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.calendar_today,
                          size: 13,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            file['date'] ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.download_outlined, size: 20),
                onPressed: () => _downloadFile(file),
                tooltip: 'Download',
                color: Colors.grey[600],
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => _deleteFile(file),
                tooltip: 'Delete',
                color: Colors.red[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _triggerBackup(String type) async {
    bool success = false;
    switch (type) {
      case 'ftp':
        success = await FirebaseService.triggerFtpBackup();
        break;
      case 'mailchimp':
        success = await FirebaseService.triggerMailchimpBackup();
        break;
      case 'sql':
        success = await FirebaseService.triggerSqlBackup();
        break;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Backup triggered successfully'
              : 'Failed to trigger backup'),
          backgroundColor: success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _togglePause() async {
    final success = _isPaused
        ? await FirebaseService.resumeBackups()
        : await FirebaseService.pauseBackups();

    if (success) {
      setState(() => _isPaused = !_isPaused);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isPaused ? 'Backups paused' : 'Backups resumed'),
          backgroundColor: success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _syncFiles() async {
    final success = await FirebaseService.syncBackupFiles();
    if (success) {
      await _loadData();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Backup files synced' : 'Failed to sync'),
          backgroundColor: success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _downloadFile(Map<String, dynamic> file) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading ${file['name']}...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteFile(Map<String, dynamic> file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Backup File'),
        content: Text('Are you sure you want to delete ${file['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted ${file['name']}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadData();
    }
  }

  void _showFileDetails(Map<String, dynamic> file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(file['name'] ?? 'File Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Name', file['name'] ?? 'N/A'),
            const SizedBox(height: 8),
            _buildDetailRow('Size', file['size'] ?? 'N/A'),
            const SizedBox(height: 8),
            _buildDetailRow('Date', file['date'] ?? 'N/A'),
            const SizedBox(height: 8),
            _buildDetailRow('Category', file['category'] ?? 'N/A'),
            const SizedBox(height: 8),
            if (file['downloadUrl'] != null)
              _buildDetailRow('Download URL', file['downloadUrl']),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value ?? 'N/A',
            style: TextStyle(color: Colors.grey[900]),
          ),
        ),
      ],
    );
  }
}
