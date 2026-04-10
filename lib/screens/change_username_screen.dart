import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class ChangeUsernameScreen extends StatefulWidget {
  final String username;
  const ChangeUsernameScreen({super.key, required this.username});

  @override
  State<ChangeUsernameScreen> createState() => _ChangeUsernameScreenState();
}

class _ChangeUsernameScreenState extends State<ChangeUsernameScreen> {
  final _newUsernameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _newUsernameController.dispose();
    super.dispose();
  }

  Future<void> _changeUsername() async {
    final newUsername = _newUsernameController.text.trim();
    if (newUsername.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a new username')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final success = await FirebaseService.changeUsername(widget.username, newUsername);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username changed successfully')),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to change username')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Username')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _newUsernameController,
              decoration: const InputDecoration(
                labelText: 'New Username',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isLoading ? null : _changeUsername,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Change Username'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
