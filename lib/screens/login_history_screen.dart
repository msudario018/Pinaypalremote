import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class LoginHistoryScreen extends StatefulWidget {
  final String username;
  const LoginHistoryScreen({super.key, required this.username});

  @override
  State<LoginHistoryScreen> createState() => _LoginHistoryScreenState();
}

class _LoginHistoryScreenState extends State<LoginHistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await FirebaseService.getLoginHistory(widget.username);
    if (mounted) {
      setState(() {
        _history = history;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login History')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const Center(child: Text('No login history available'))
              : ListView.builder(
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final entry = _history[index];
                    final timestamp = entry['timestamp']?.toString() ??
                        entry['Timestamp']?.toString() ??
                        '';
                    final success = entry['success'] ??
                        entry['Success'] ??
                        entry['isSuccess'] ??
                        entry['IsSuccess'] ??
                        true;
                    final message = entry['message']?.toString() ??
                        entry['Message']?.toString() ??
                        entry['IpAddress']?.toString() ??
                        'Login attempt';
                    final ipAddress = entry['IpAddress']?.toString() ??
                        entry['ipAddress']?.toString() ??
                        '';

                    return ListTile(
                      leading: Icon(
                        success ? Icons.check_circle : Icons.error,
                        color: success ? Colors.green : Colors.red,
                      ),
                      title: Text(message),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(timestamp),
                          if (ipAddress.isNotEmpty) Text('IP: $ipAddress'),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
