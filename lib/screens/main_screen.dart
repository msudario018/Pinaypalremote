import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'backup_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  final String username;
  const MainScreen({super.key, required this.username});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late final List<Widget> _screens = [
    const DashboardScreen(),
    ProfileScreen(username: widget.username),
    const BackupScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _screens[_currentIndex],
      ),
      floatingActionButton: _currentIndex == 1
          ? FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              child: const Icon(Icons.settings),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
          NavigationDestination(
            icon: Icon(Icons.backup_outlined),
            selectedIcon: Icon(Icons.backup),
            label: 'Backup',
          ),
        ],
      ),
    );
  }
}
