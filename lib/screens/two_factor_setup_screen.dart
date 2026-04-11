import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../services/firebase_service.dart';

class TwoFactorSetupScreen extends StatefulWidget {
  final String username;
  const TwoFactorSetupScreen({super.key, required this.username});

  @override
  State<TwoFactorSetupScreen> createState() => _TwoFactorSetupScreenState();
}

class _TwoFactorSetupScreenState extends State<TwoFactorSetupScreen> {
  bool _isLoading = true;
  bool _is2FAEnabled = false;
  String? _secretKey;
  List<String>? _backupCodes;

  @override
  void initState() {
    super.initState();
    _check2FAStatus();
  }

  Future<void> _check2FAStatus() async {
    final isEnabled = await FirebaseService.is2FAEnabled(widget.username);
    if (mounted) {
      setState(() {
        _is2FAEnabled = isEnabled;
        _isLoading = false;
      });

      // If not enabled, setup new 2FA
      if (!isEnabled) {
        _setup2FA();
      } else {
        // If enabled, get existing data
        await _getExisting2FAData();
      }
    }
  }

  Future<void> _getExisting2FAData() async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://pinaypal-backup-manager-default-rtdb.firebaseio.com/2fa/${widget.username}.json'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null) {
          setState(() {
            _secretKey =
                data['SecretKey']?.toString() ?? data['secret']?.toString();
            _backupCodes = data['BackupCodes'] != null
                ? List<String>.from(data['BackupCodes'])
                : data['backupCodes'] != null
                    ? List<String>.from(data['backupCodes'])
                    : [];
          });
        }
      }
    } catch (e) {
      print('[TwoFactorSetupScreen] Failed to get existing 2FA data: $e');
    }
  }

  Future<void> _setup2FA() async {
    setState(() => _isLoading = true);
    final result = await FirebaseService.setup2FA(widget.username);
    if (mounted) {
      setState(() {
        _secretKey = result['secret'];
        _backupCodes = List<String>.from(result['backupCodes'] ?? []);
        _isLoading = false;
      });
    }
  }

  Future<void> _enable2FA() async {
    final success = await FirebaseService.enable2FA(widget.username);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('2FA enabled successfully')),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to enable 2FA')),
        );
      }
    }
  }

  Future<void> _disable2FA() async {
    final success = await FirebaseService.disable2FA(widget.username);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('2FA disabled successfully')),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to disable 2FA')),
        );
      }
    }
  }

  Future<void> _restorePCSecret() async {
    final success = await FirebaseService.update2FASecret(
        widget.username, 'SA5HBLMUCUJWTD6T');
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PC app secret restored successfully')),
        );
        setState(() {
          _secretKey = 'SA5HBLMUCUJWTD6T';
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to restore PC app secret')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_is2FAEnabled
            ? 'Manage Two-Factor Authentication'
            : 'Setup Two-Factor Authentication'),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF3A0C57), const Color(0xFF1B052A)]
                : [const Color(0xFF83509F), const Color(0xFF50246C)],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      color: isDark
                          ? const Color(0xFF3A0C57).withValues(alpha: 0.9)
                          : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: const Color(0xFF83509F)
                                    .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.security,
                                size: 32,
                                color: Color(0xFF83509F),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _is2FAEnabled
                                  ? 'Two-Factor Authentication Enabled'
                                  : 'Setup Two-Factor Authentication',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF83509F),
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _is2FAEnabled
                                  ? 'Your account is protected with 2FA. You can disable it below.'
                                  : 'Scan the QR code with your authenticator app and save your backup codes.',
                              style: TextStyle(
                                color:
                                    isDark ? Colors.white70 : Colors.grey[600],
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            if (_is2FAEnabled) ...[
                              Card(
                                color: isDark
                                    ? const Color(0xFF2D1B3E)
                                    : Colors.grey[50],
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.green
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Icon(
                                                Icons.check_circle,
                                                color: Colors.green,
                                                size: 18),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Status: Enabled',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Backup Codes',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF1B052A)
                                              : Colors.grey[200],
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _backupCodes?.join('\n') ??
                                              'Loading...',
                                          style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 11),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Save these codes in a safe place.',
                                        style: TextStyle(
                                            fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: FilledButton(
                                  onPressed: _disable2FA,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text('Disable 2FA'),
                                ),
                              ),
                            ] else ...[
                              Card(
                                color: isDark
                                    ? const Color(0xFF2D1B3E)
                                    : Colors.grey[50],
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'Secret Key',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                          const Spacer(),
                                          IconButton(
                                            icon: const Icon(Icons.copy,
                                                size: 18),
                                            onPressed: _secretKey != null
                                                ? () {
                                                    Clipboard.setData(
                                                        ClipboardData(
                                                            text: _secretKey!));
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                            'Secret key copied to clipboard'),
                                                        duration: Duration(
                                                            seconds: 2),
                                                      ),
                                                    );
                                                  }
                                                : null,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF1B052A)
                                              : Colors.grey[200],
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: SelectableText(
                                          _secretKey ?? 'Loading...',
                                          style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 12),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Enter this key in your authenticator app',
                                        style: TextStyle(
                                            fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Card(
                                color: isDark
                                    ? const Color(0xFF2D1B3E)
                                    : Colors.grey[50],
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'Backup Codes',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                          const Spacer(),
                                          IconButton(
                                            icon: const Icon(Icons.copy,
                                                size: 18),
                                            onPressed: _backupCodes != null
                                                ? () {
                                                    Clipboard.setData(
                                                        ClipboardData(
                                                            text: _backupCodes!
                                                                .join('\n')));
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                            'Backup codes copied to clipboard'),
                                                        duration: Duration(
                                                            seconds: 2),
                                                      ),
                                                    );
                                                  }
                                                : null,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF1B052A)
                                              : Colors.grey[200],
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _backupCodes?.join('\n') ??
                                              'Loading...',
                                          style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 12),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Save these codes in a safe place.',
                                        style: TextStyle(
                                            fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: FilledButton(
                                  onPressed: _enable2FA,
                                  style: FilledButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text('Enable 2FA'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _restorePCSecret,
                                child: const Text('Restore PC App Secret'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
