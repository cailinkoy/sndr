import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'dev/logo_export_page.dart'; // for logo
import 'home_page.dart';
import 'theme_controller.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _setupNotifications() async {
  // Init plugin
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const init = InitializationSettings(android: androidInit);
  await flutterLocalNotificationsPlugin.initialize(init);

  // Timezones
  tz.initializeTimeZones();
  // If you ever need to force a specific location:
  // tz.setLocalLocation(tz.getLocation('America/Los_Angeles'));

  // Android-specific permissions & channel
  final android = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  // Android 13+ runtime notification permission
  await android?.requestNotificationsPermission();

  // ---- Added safety: check before requesting exact alarms
  final canExact = await android?.canScheduleExactNotifications() ?? false;
  if (!canExact) {
    await android?.requestExactAlarmsPermission();
  }

  // Create (or no-op if exists) a high-importance channel for reminders
  const channel = AndroidNotificationChannel(
    'reminder_channel',
    'Reminders',
    description: 'Occasion reminders from [sndr]',
    importance: Importance.max,
  );
  await android?.createNotificationChannel(channel);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Notifications setup
  await _setupNotifications();

  // Load saved theme before runApp
  await ThemeController.instance.load();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final tc = ThemeController.instance;

    return ValueListenableBuilder(
      valueListenable: tc.mode,
      builder: (context, ThemeMode mode, _) {
        return MaterialApp(
          title: 'SNDR',

          // Light theme
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              scrolledUnderElevation: 0,
              toolbarHeight: 64, // room for logo/bow
            ),
            cardTheme: CardThemeData(
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 1,
            ),
          ),

          // Dark theme
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.amber,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              scrolledUnderElevation: 0,
              toolbarHeight: 35, // compact variant
            ),
            cardTheme: CardThemeData(
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 1,
            ),
          ),

          themeMode: mode, // live updates from Settings
          routes: {'/logo-export': (_) => const LogoExportPage()},
          home: const HomePage(),
        );
      },
    );
  }
}
