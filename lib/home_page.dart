import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'main.dart' show flutterLocalNotificationsPlugin;
import 'models/event_info.dart';
import 'tabs/events_tab.dart';
import 'tabs/contacts_tab.dart';
import 'pages/settings_page.dart';
import 'pages/about_page.dart';
import 'package:sndr_app_new/widgets/sndr_logo.dart';
import 'widgets/sndr_drawer_header_logo.dart';

/// --- Tab colors (apply in both light & dark because header is black) ---
const kTabBright = Color(0xFFFFB74D);
final kTabDim = kTabBright.withValues(alpha: 0.55);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<EventInfo> allEvents = [];
  Map<DateTime, List<EventInfo>> eventsByDay = {};
  Map<String, int> reminderDaysMap = {};
  Map<String, String> contactRelationships = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchContacts();
    loadReminders();
    loadRelationships();
  }

  // ---------- Relationships ----------
  Future<void> setRelationship(
    String contactId,
    String currentRelationship,
  ) async {
    final newRelation = await showDialog<String>(
      context: context,
      builder: (context) {
        String tempRelation = currentRelationship;
        return AlertDialog(
          title: const Text('Set Relationship'),
          content: TextField(
            controller: TextEditingController(text: currentRelationship),
            decoration: const InputDecoration(
              hintText: 'e.g., Friend, Mom, Boss',
            ),
            onChanged: (value) => tempRelation = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, tempRelation),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (newRelation != null) {
      setState(() {
        contactRelationships[contactId] = newRelation;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('relationship_$contactId', newRelation);
    }
  }

  Future<void> loadRelationships() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final loaded = <String, String>{};
    for (final key in keys) {
      if (key.startsWith('relationship_')) {
        loaded[key.replaceFirst('relationship_', '')] =
            prefs.getString(key) ?? '';
      }
    }
    if (!mounted) return;
    setState(() {
      contactRelationships = loaded;
    });
  }

  // ---------- Reminders / Notifications ----------
  Future<void> loadReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final loaded = <String, int>{};
    for (final key in keys) {
      if (key.startsWith('reminder_')) {
        loaded[key] = prefs.getInt(key) ?? 0;
      }
    }
    if (!mounted) return;
    setState(() {
      reminderDaysMap = loaded;
    });
  }

  Future<void> saveReminder(String key, int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, days);
  }

  Future<void> scheduleReminderNotification(
    int id,
    String title,
    String body,
    DateTime scheduledTime,
  ) async {
    // 1) Anchor to 9:00 AM local time
    DateTime anchored = DateTime(
      scheduledTime.year,
      scheduledTime.month,
      scheduledTime.day,
      9, // 9 AM
    );

    // 2) If that’s still in the past, bump it forward
    final now = DateTime.now();
    if (!anchored.isAfter(now)) {
      anchored = now.add(const Duration(minutes: 1));
    }

    // 3) Schedule
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(anchored, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_channel',
          'Reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }

  // ---------- Contacts & Events ----------
  String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  Future<void> fetchContacts() async {
    final permissionGranted = await FlutterContacts.requestPermission();
    if (!mounted) return;
    if (!permissionGranted) {
      setState(() => isLoading = false);
      return;
    }

    final contacts = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: true,
    );
    if (!mounted) return;

    final List<EventInfo> eventList = [];
    final Map<DateTime, List<EventInfo>> eventMap = {};

    for (final contact in contacts) {
      for (final event in contact.events) {
        final daysLeft = daysUntilMonthDay(event.month, event.day);
        final eventDate = DateTime(DateTime.now().year, event.month, event.day);
        final info = EventInfo(
          contact: contact,
          event: event,
          daysLeft: daysLeft,
        );
        eventList.add(info);
        eventMap.putIfAbsent(eventDate, () => []).add(info);
      }
    }

    eventList.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));

    if (!mounted) return;
    setState(() {
      allEvents = eventList;
      eventsByDay = eventMap;
      isLoading = false;
    });
  }

  int daysUntilMonthDay(int month, int day) {
    final now = DateTime.now();
    final year = now.year;
    final jan1 = DateTime(year, 1, 1);
    final dec31 = DateTime(year, 12, 31);
    final eventDate = DateTime(year, month, day);
    final x = eventDate.difference(jan1).inDays + 1;
    final y = now.difference(jan1).inDays + 1;
    return (x > y) ? x - y : dec31.difference(now).inDays + x;
  }

  List<EventInfo> getEventsForDay(DateTime day) {
    final dayOnly = DateTime(day.year, day.month, day.day);
    return eventsByDay[dayOnly] ?? [];
  }

  // ---------- Reminder handler used by tabs ----------
  Future<void> onSelectReminder({
    required BuildContext context,
    required EventInfo item,
    required int? selectedDays,
  }) async {
    // If null, user dismissed the sheet; do nothing.
    if (selectedDays == null) return;

    final contact = item.contact;
    final event = item.event;
    final eventDate = DateTime(DateTime.now().year, event.month, event.day);
    final eventLabel = capitalize(event.label.name);
    final firstName = contact.displayName.split(' ').first;
    final eventKey =
        'reminder_${contact.id}_${event.label.name}_${event.month}_${event.day}';
    final isCurrentlySet = reminderDaysMap.containsKey(eventKey);

    // NEW: stable notification ID derived from eventKey
    final stableId = eventKey.hashCode;

    if (selectedDays == 0 && isCurrentlySet) {
      await flutterLocalNotificationsPlugin.cancel(stableId); // CHANGED
      await saveReminder(eventKey, 0);
      if (!mounted) return;
      setState(() {
        reminderDaysMap.remove(eventKey);
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reminder removed for $firstName')),
      );
      return;
    }

    if (selectedDays != 0) {
      final reminderTime = eventDate.subtract(Duration(days: selectedDays));
      await scheduleReminderNotification(
        stableId, // CHANGED
        'Reminder: $eventLabel',
        'Get ready for ${contact.displayName}\'s ${eventLabel.toLowerCase()}!',
        reminderTime,
      );
      await saveReminder(eventKey, selectedDays);
      if (!mounted) return;
      setState(() {
        reminderDaysMap[eventKey] = selectedDays;
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reminder set for $firstName, $selectedDays day(s) before!',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        drawer: const _MainDrawer(),
        appBar: AppBar(
          backgroundColor: Colors.black,
          centerTitle: true,
          title: Transform.translate(
            offset: const Offset(0, 4), // nudge logo down a touch
            child: const SndrLogoNew(),
          ),
          actions: [
            IconButton(
              tooltip: 'Export logo PNGs',
              icon: const Icon(Icons.download_rounded),
              onPressed: () => Navigator.pushNamed(context, '/logo-export'),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: const [
              Tab(text: 'Upcoming'),
              Tab(text: 'Calendar'),
              Tab(text: 'By Contact'),
            ],
            labelColor: kTabBright,
            unselectedLabelColor: kTabDim,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
            indicatorSize: TabBarIndicatorSize.label,
            indicator: const UnderlineTabIndicator(
              borderSide: BorderSide(width: 2.5, color: kTabBright),
              insets: EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  // Upcoming tab
                  EventsTab(
                    allEvents: allEvents,
                    reminderDaysMap: reminderDaysMap,
                    onPickReminderDays: (ctx) => _pickReminderDays(ctx),
                    onSelectReminder: (ctx, item, days) => onSelectReminder(
                      context: ctx,
                      item: item,
                      selectedDays: days,
                    ),
                    onSetRelationship: (contactId, current) =>
                        setRelationship(contactId, current),
                  ),

                  // Calendar tab
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TableCalendar<EventInfo>(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2040, 12, 31),
                      focusedDay: DateTime.now(),
                      eventLoader: getEventsForDay,
                      calendarFormat: CalendarFormat.month,
                      startingDayOfWeek: StartingDayOfWeek.sunday,
                      calendarStyle: const CalendarStyle(
                        markerDecoration: BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                        ),
                      ),
                      onDaySelected: (selectedDay, focusedDay) {
                        final events = getEventsForDay(selectedDay);
                        if (events.isNotEmpty) {
                          showModalBottomSheet(
                            context: context,
                            builder: (_) => ListView(
                              shrinkWrap: true,
                              children: events.map((item) {
                                final eventLabel = capitalize(
                                  item.event.label.name,
                                );
                                return ListTile(
                                  leading:
                                      (item.contact.photo != null &&
                                          item.contact.photo!.isNotEmpty)
                                      ? CircleAvatar(
                                          backgroundImage: MemoryImage(
                                            item.contact.photo!,
                                          ),
                                        )
                                      : CircleAvatar(
                                          child: Text(
                                            item.contact.displayName.isNotEmpty
                                                ? item.contact.displayName[0]
                                                      .toUpperCase()
                                                : '?',
                                          ),
                                        ),
                                  title: Text(
                                    "${item.contact.displayName}'s ${eventLabel.toLowerCase()}",
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        }
                      },
                    ),
                  ),

                  // By Contact tab
                  ContactsTab(
                    allEvents: allEvents,
                    reminderDaysMap: reminderDaysMap,
                    contactRelationships: contactRelationships,
                    onPickReminderDays: (ctx) => _pickReminderDays(ctx),
                    onSelectReminder: (ctx, item, days) => onSelectReminder(
                      context: ctx,
                      item: item,
                      selectedDays: days,
                    ),
                    onSetRelationship: (contactId, current) =>
                        setRelationship(contactId, current),
                  ),
                ],
              ),
      ),
    );
  }

  Future<int?> _pickReminderDays(BuildContext context) {
    return showModalBottomSheet<int>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              ListTile(title: Text('Set Reminder')),
              ListTile(
                title: Text('1 day before'),
                subtitle: Text('Notify one day prior'),
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
                dense: true,
              ),
              // You can add onTap handlers where you call Navigator.pop(context, <value>)
            ],
          ),
        );
      },
    );
  }
}

class _MainDrawer extends StatelessWidget {
  const _MainDrawer();

  Future<void> _sendTestNow(BuildContext context) async {
    await flutterLocalNotificationsPlugin.show(
      4242, // any unique id
      'Test from [sndr]',
      'Notifications are working 🎉',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_channel',
          'Reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
    if (!context.mounted) return; // guard BuildContext after await
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sent an instant test notification')),
    );
  }

  Future<void> _scheduleTestIn10s(BuildContext context) async {
    final now = DateTime.now();
    final when = now.add(const Duration(seconds: 15)); // small buffer

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Scheduling for ${when.toLocal()}'),
        duration: const Duration(seconds: 2),
      ),
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      4243,
      'Scheduled Test',
      'This fired ~15 seconds after you tapped.',
      tz.TZDateTime.from(when, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_channel',
          'Reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: null, // one-off
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.black),
              child: Transform.translate(
                offset: const Offset(0, 6),
                child: const SndrDrawerHeaderLogo(),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home_rounded),
              title: const Text('Home'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.settings_rounded),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Send Test Notification (Instant)'),
              onTap: () async {
                Navigator.pop(context);
                await _sendTestNow(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule_outlined),
              title: const Text('Schedule Test in 10s'),
              onTap: () async {
                Navigator.pop(context);
                await _scheduleTestIn10s(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.feedback_outlined),
              title: const Text('About/Contact'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AboutPage(sections: aboutSections),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
