import 'package:flutter/material.dart';

class ThemeModeInherited extends InheritedWidget {
  final ThemeMode themeMode;
  final Function(ThemeMode) setThemeMode;

  const ThemeModeInherited({
    super.key,
    required this.themeMode,
    required this.setThemeMode,
    required Widget child,
  }) : super(child: child);

  static ThemeModeInherited of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ThemeModeInherited>()!;
  }

  @override
  bool updateShouldNotify(ThemeModeInherited oldWidget) {
    return themeMode != oldWidget.themeMode;
  }
}
