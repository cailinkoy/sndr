import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  /// Notifies the app when theme mode changes
  final ValueNotifier<ThemeMode> mode = ValueNotifier<ThemeMode>(
    ThemeMode.system,
  );

  static const _prefKey = 'theme_mode'; // 'system' | 'light' | 'dark'

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey) ?? 'system';
    switch (raw) {
      case 'light':
        mode.value = ThemeMode.light;
        break;
      case 'dark':
        mode.value = ThemeMode.dark;
        break;
      default:
        mode.value = ThemeMode.system;
    }
  }

  Future<void> setMode(ThemeMode newMode) async {
    mode.value = newMode;
    final prefs = await SharedPreferences.getInstance();
    final raw = switch (newMode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    };
    await prefs.setString(_prefKey, raw);
  }
}
