import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/splash_screen.dart';
import 'utils/app_theme.dart';
import 'utils/theme_mode_inherited.dart';
import 'services/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase connection
  final firebaseConnected = await FirebaseService.initialize();
  print(
      '[Main] Firebase connection: ${firebaseConnected ? "SUCCESS" : "FAILED"}');

  runApp(const PinayPalRemoteApp());
}

class PinayPalRemoteApp extends StatefulWidget {
  const PinayPalRemoteApp({super.key});

  @override
  State<PinayPalRemoteApp> createState() => _PinayPalRemoteAppState();
}

class _PinayPalRemoteAppState extends State<PinayPalRemoteApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkMode = prefs.getBool('isDarkMode');
    if (isDarkMode != null) {
      setState(() {
        _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
      });
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', mode == ThemeMode.dark);
    setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PinayPal Remote',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: const SplashScreen(),
      builder: (context, child) {
        return ThemeModeInherited(
          themeMode: _themeMode,
          setThemeMode: setThemeMode,
          child: child!,
        );
      },
    );
  }
}
