// lib/widgets/permission_primer_dialog.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

const _kPrimerSeenKey = 'seen_contacts_notif_primer_v1';

Future<void> showPermissionPrimerIfNeeded(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final seen = prefs.getBool(_kPrimerSeenKey) ?? false;
  if (seen) return;

  // Only show once per install (or until you bump the key)
  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      title: const Text('Permissions needed'),
      content: const Text(
        'Sndr will ask to send notifications (for reminders) and access your contacts '
        '(to find birthdays & suggest gifts).',
      ),
      actions: [
        TextButton(
          onPressed: () async {
            // Mark as seen even if they skip; avoids nagging
            await prefs.setBool(_kPrimerSeenKey, true);
            Navigator.of(ctx).pop();
          },
          child: const Text('Not now'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Continue'),
          onPressed: () async {
            Navigator.of(ctx).pop(); // close the notice first

            // 1) Notifications (Android 13+/iOS)
            await Permission.notification.request();

            // 1a) Exact alarm (Android 12+) — safe no-op elsewhere
            await Permission.scheduleExactAlarm.request();

            // 2) Contacts
            await Permission.contacts.request();

            // Don’t manage any app state here. Just mark as seen.
            await prefs.setBool(_kPrimerSeenKey, true);
          },
        ),
      ],
    ),
  );
}
