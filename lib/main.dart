import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
// import 'dev/logo_export_page.dart'; // ← removed (file was deleted)
import 'home_page.dart';
import 'theme_controller.dart';
import 'widgets/permission_primer_dialog.dart'; // <— new
import 'core/feature_flags.dart';
import 'core/entitlements.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// ✅ Navigator key to access a context inside the Navigator
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> _setupNotifications() async {
  // Init plugin
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const init = InitializationSettings(android: androidInit);
  await flutterLocalNotificationsPlugin.initialize(init);

  // Timezones
  tz.initializeTimeZones();

  // Create (or no-op if exists) a high-importance channel for reminders
  const channel = AndroidNotificationChannel(
    'reminder_channel',
    'Reminders',
    description: 'Occasion reminders from [sndr]',
    importance: Importance.max,
  );
  final android = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await android?.createNotificationChannel(channel);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FeatureFlags.init();
  await Entitlements.init();

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
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(18)),
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
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(18)),
              ),
              elevation: 1,
            ),
          ),

          themeMode: mode, // live updates from Settings
          // routes: {'/logo-export': (_) => const LogoExportPage()}, // ← removed
          home: const HomePage(),

          // ✅ Provide a navigatorKey so we can get a Navigator-aware context
          navigatorKey: appNavigatorKey,

          // ❗ One-time primer popup (does not block UI; no overlays)
          builder: (context, child) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final ctx = appNavigatorKey.currentContext; // has a Navigator
              if (ctx != null) {
                showPermissionPrimerIfNeeded(ctx);
              }
            });
            return child ?? const SizedBox.shrink();
          },
        );
      },
    );
  }
}
