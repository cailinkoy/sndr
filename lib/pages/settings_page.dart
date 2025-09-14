import 'package:flutter/material.dart';
import '../theme_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tc = ThemeController.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          ValueListenableBuilder(
            valueListenable: tc.mode,
            builder: (context, ThemeMode current, _) {
              return Card(
                child: Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.system,
                      title: const Text('Use device setting'),
                      subtitle: const Text(
                        'Switches with your phone’s light/dark mode',
                      ),
                    ),
                    const Divider(height: 1),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.light,
                      title: const Text('Light'),
                    ),
                    const Divider(height: 1),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.dark,
                      title: const Text('Dark'),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 18),
          Text('Notifications', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Test reminder notification'),
                  subtitle: const Text(
                    'Sends a local test notification in ~5 seconds',
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          '(Coming soon) Test notification scheduled',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          Text('About', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Card(
            child: Column(
              children: const [
                ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('SNDR'),
                  subtitle: Text('Celebrate your people, right on time.'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
