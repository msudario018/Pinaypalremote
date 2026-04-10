import 'package:flutter/material.dart';

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup'),
      ),
      body: const Center(
        child: Text(
          'Backup - Coming Soon',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      ),
    );
  }
}
