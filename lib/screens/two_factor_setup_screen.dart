import 'dart:convert';
import 'package:flutter/material.dart';
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
    return Scaffold(
      appBar: AppBar(
          title: Text(_is2FAEnabled
              ? 'Manage Two-Factor Authentication'
              : 'Setup Two-Factor Authentication')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  if (_is2FAEnabled) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Two-Factor Authentication is Enabled',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Your account is protected with 2FA. You can disable it below.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Backup Codes',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _backupCodes?.join('\n') ?? 'Loading...',
                              style: const TextStyle(fontFamily: 'monospace'),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Save these codes in a safe place. You can use them to login if you lose access to your authenticator.',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _disable2FA,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Disable 2FA'),
                      ),
                    ),
                  ] else ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Secret Key',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(_secretKey ?? 'Loading...'),
                            const SizedBox(height: 8),
                            const Text(
                              'Scan this QR code with your authenticator app',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Backup Codes',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _backupCodes?.join('\n') ?? 'Loading...',
                              style: const TextStyle(fontFamily: 'monospace'),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Save these codes in a safe place. You can use them to login if you lose access to your authenticator.',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _enable2FA,
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
    );
  }
}
