import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class InviteCodesScreen extends StatefulWidget {
  const InviteCodesScreen({super.key});

  @override
  State<InviteCodesScreen> createState() => _InviteCodesScreenState();
}

class _InviteCodesScreenState extends State<InviteCodesScreen> {
  List<Map<String, dynamic>> _inviteCodes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInviteCodes();
  }

  Future<void> _loadInviteCodes() async {
    try {
      final codes = await FirebaseService.getInviteCodes();
      if (mounted) {
        setState(() {
          _inviteCodes = codes;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[InviteCodesScreen] Load invite codes failed: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _generateInviteCode() async {
    final code = await FirebaseService.generateInviteCode();
    if (mounted) {
      if (code != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invite code generated: $code')),
        );
        _loadInviteCodes();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate invite code')),
        );
      }
    }
  }

  Future<void> _deleteInviteCode(String code) async {
    final success = await FirebaseService.deleteInviteCode(code);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite code deleted')),
        );
        _loadInviteCodes();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete invite code')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite Codes'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _generateInviteCode,
                      icon: const Icon(Icons.add),
                      label: const Text('Generate Invite Code'),
                    ),
                  ),
                ),
                Expanded(
                  child: _inviteCodes.isEmpty
                      ? const Center(child: Text('No invite codes found'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _inviteCodes.length,
                          itemBuilder: (context, index) {
                            final codeData = _inviteCodes[index];
                            final code = codeData['code']?.toString() ?? 'Unknown';
                            final isUsed = codeData['is_used'] == true;
                            final usedBy = codeData['used_by']?.toString() ?? 'N/A';
                            final createdAt = codeData['created_at']?.toString() ?? 'Unknown';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                title: Text(
                                  code,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Status: ${isUsed ? 'Used' : 'Available'}'),
                                    if (isUsed) Text('Used by: $usedBy'),
                                    Text('Created: $createdAt'),
                                  ],
                                ),
                                trailing: !isUsed
                                    ? IconButton(
                                        icon: const Icon(Icons.delete),
                                        onPressed: () => _deleteInviteCode(code),
                                        tooltip: 'Delete',
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
