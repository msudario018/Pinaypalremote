import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import 'change_password_screen.dart';

class UserManagementScreen extends StatefulWidget {
  final String username;
  const UserManagementScreen({super.key, required this.username});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final response = await FirebaseService.getAllUsers();
      if (mounted) {
        setState(() {
          _users = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[UserManagementScreen] Load users failed: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(child: Text('No users found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    final username = user['Username']?.toString() ?? 'Unknown';
                    final status = user['Status']?.toString() ?? 'Unknown';
                    final role = user['Role']?.toString() ?? 'User';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(username),
                        subtitle: Text('Status: $status | Role: $role'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (status == 'Disabled')
                              IconButton(
                                icon: const Icon(Icons.check_circle_outline),
                                onPressed: () => _enableUser(username),
                                tooltip: 'Enable User',
                              )
                            else if (status == 'Pending')
                              IconButton(
                                icon: const Icon(Icons.approval),
                                onPressed: () => _approveUser(username),
                                tooltip: 'Approve User',
                              )
                            else if (role.toLowerCase() != 'admin')
                              IconButton(
                                icon: const Icon(Icons.block),
                                onPressed: () => _disableUser(username),
                                tooltip: 'Disable User',
                              ),
                            IconButton(
                              icon: const Icon(Icons.lock_reset),
                              onPressed: () => _changeUserPassword(username),
                              tooltip: 'Change Password',
                            ),
                            if (role.toLowerCase() != 'admin')
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _changeUsername(username),
                                tooltip: 'Change Username',
                              ),
                          ],
                        ),
                        onTap: () => _showUserDetails(user),
                      ),
                    );
                  },
                ),
    );
  }

  void _showUserDetails(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user['Username']?.toString() ?? 'User Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Username: ${user['Username']?.toString() ?? 'N/A'}'),
            const SizedBox(height: 8),
            Text('Status: ${user['Status']?.toString() ?? 'N/A'}'),
            const SizedBox(height: 8),
            Text('Role: ${user['Role']?.toString() ?? 'N/A'}'),
            const SizedBox(height: 8),
            Text('Created At: ${user['CreatedAt']?.toString() ?? 'N/A'}'),
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

  Future<void> _approveUser(String username) async {
    final success = await FirebaseService.approveUser(username);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'User approved' : 'Failed to approve user'),
        ),
      );
      if (success) _loadUsers();
    }
  }

  Future<void> _disableUser(String username) async {
    // Find the user to check their role
    final user = _users.firstWhere(
      (u) => u['Username']?.toString() == username,
      orElse: () => {},
    );
    final role = user['Role']?.toString() ?? '';

    // Prevent disabling admin users
    if (role.toLowerCase() == 'admin') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot disable admin user'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final success = await FirebaseService.disableUser(username);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'User disabled' : 'Failed to disable user'),
        ),
      );
      if (success) _loadUsers();
    }
  }

  Future<void> _enableUser(String username) async {
    final success = await FirebaseService.enableUser(username);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'User enabled' : 'Failed to enable user'),
        ),
      );
      if (success) _loadUsers();
    }
  }

  void _changeUserPassword(String username) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ChangePasswordScreen(
              username: username,
              isAdminMode: true,
            ),
          ),
        )
        .then((_) => _loadUsers());
  }

  void _changeUsername(String username) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Username'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'New Username',
            hintText: 'Enter new username',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newUsername = controller.text.trim();
              if (newUsername.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Username cannot be empty')),
                );
                return;
              }

              final success =
                  await FirebaseService.changeUsername(username, newUsername);
              if (mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Username changed successfully'
                        : 'Failed to change username'),
                  ),
                );
                if (success) _loadUsers();
              }
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }
}
