import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/event_info.dart';
import '../pages/gift_ideas_page.dart';

typedef PickDays = Future<int?> Function(BuildContext context);
typedef SelectReminder =
    Future<void> Function(
      BuildContext context,
      EventInfo item,
      int? selectedDays,
    );
typedef SetRelationship =
    Future<void> Function(String contactId, String currentRelationship);

class ContactsTab extends StatelessWidget {
  const ContactsTab({
    super.key,
    required this.allEvents,
    required this.reminderDaysMap,
    required this.contactRelationships,
    required this.onPickReminderDays,
    required this.onSelectReminder,
    required this.onSetRelationship,
  });

  final List<EventInfo> allEvents;
  final Map<String, int> reminderDaysMap;
  final Map<String, String> contactRelationships;
  final PickDays onPickReminderDays;
  final SelectReminder onSelectReminder;
  final SetRelationship onSetRelationship;

  String capitalize(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

  @override
  Widget build(BuildContext context) {
    // Group by contact
    final Map<String, List<EventInfo>> byContact = {};
    for (final e in allEvents) {
      byContact.putIfAbsent(e.contact.displayName, () => []).add(e);
    }
    final names = byContact.keys.toList()..sort();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: ListView.separated(
        itemCount: names.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final name = names[i];
          final events = byContact[name]!;
          final c = events.first.contact;

          final relationship = contactRelationships[c.id] ?? '';

          return Card(
            elevation: 1,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: InkWell(
              onTap: () => onSetRelationship(c.id, relationship),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        c.photo != null && c.photo!.isNotEmpty
                            ? CircleAvatar(
                                radius: 22,
                                backgroundImage: MemoryImage(c.photo!),
                              )
                            : CircleAvatar(
                                radius: 22,
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.displayName,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                relationship.isNotEmpty
                                    ? relationship
                                    : 'Set relation',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),

                    const SizedBox(height: 10),
                    const Divider(height: 1),

                    // Events
                    ...events.map((e) {
                      final eventDate = DateTime(
                        DateTime.now().year,
                        e.event.month,
                        e.event.day,
                      );
                      final formatted = DateFormat('MMMM d').format(eventDate);
                      final label = capitalize(e.event.label.name);
                      final firstName = e.contact.displayName.split(' ').first;

                      final eventKey =
                          'reminder_${e.contact.id}_${e.event.label.name}_${e.event.month}_${e.event.day}';
                      final isReminderSet = reminderDaysMap.containsKey(
                        eventKey,
                      );

                      final message =
                          'Hey $firstName, just wanted to wish you a happy ${label.toLowerCase()}! Hope you and yours are doing well. Have a great one!';

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(2, 10, 2, 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                '• $label  —  $formatted',
                                style: Theme.of(context).textTheme.bodyMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _ActionPillRow(
                              isReminderSet: isReminderSet,
                              onRemind: () async {
                                final selected =
                                    await showModalBottomSheet<int>(
                                      context: context,
                                      builder: (sheetCtx) => _ReminderSheet(
                                        isReminderSet: isReminderSet,
                                      ),
                                    );
                                if (!context.mounted) return;
                                await onSelectReminder(context, e, selected);
                              },
                              onShare: () async {
                                await SharePlus.instance.share(
                                  ShareParams(text: message),
                                );
                              },
                              onGift: () async {
                                if (!context.mounted) return;
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => GiftIdeasPage(
                                      prefillPerson: e.contact.displayName,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Row of compact, modern action "pills" (Remind • Message • Gift)
class _ActionPillRow extends StatelessWidget {
  const _ActionPillRow({
    required this.isReminderSet,
    required this.onRemind,
    required this.onShare,
    required this.onGift,
  });

  final bool isReminderSet;
  final VoidCallback onRemind;
  final VoidCallback onShare;
  final VoidCallback onGift;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      children: [
        _PillButton(
          icon: isReminderSet
              ? Icons.notifications_active
              : Icons.notifications_none,
          label: isReminderSet ? 'Set' : 'Remind',
          background: isReminderSet
              ? cs.secondaryContainer
              : cs.surfaceContainerHigh,
          foreground: isReminderSet ? cs.onSecondaryContainer : cs.onSurface,
          onPressed: onRemind,
        ),
        _PillButton(
          icon: Icons.send_rounded,
          label: 'Message',
          background: cs.surfaceContainerHigh,
          foreground: cs.onSurface,
          onPressed: onShare,
        ),
        _PillButton(
          icon: Icons.card_giftcard_rounded,
          label: 'Gift',
          background: cs.primaryContainer,
          foreground: cs.onPrimaryContainer,
          onPressed: onGift,
        ),
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for reminder selection
class _ReminderSheet extends StatelessWidget {
  const _ReminderSheet({required this.isReminderSet});
  final bool isReminderSet;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('Set Reminder')),
          ListTile(
            title: const Text('1 day before'),
            onTap: () => Navigator.pop(context, 1),
          ),
          ListTile(
            title: const Text('3 days before'),
            onTap: () => Navigator.pop(context, 3),
          ),
          ListTile(
            title: const Text('1 week before'),
            onTap: () => Navigator.pop(context, 7),
          ),
          if (isReminderSet)
            ListTile(
              title: const Text('Remove reminder'),
              onTap: () => Navigator.pop(context, 0),
            ),
        ],
      ),
    );
  }
}
