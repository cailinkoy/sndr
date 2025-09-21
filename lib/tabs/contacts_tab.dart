import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/event_info.dart';
import '../pages/gift_ideas_page.dart';
import '../widgets/relation_picker_section.dart';
import '../gift_ideas/gift_ideas_sheet.dart';

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

  Future<void> _editRelationshipViaPicker({
    required BuildContext context,
    required String contactId,
    required String currentRelationship,
    required SetRelationship onSetRelationship,
  }) async {
    // We'll keep the currently selected set opaque (no RelTag here),
    // and a custom label string if the user types one.
    Set<dynamic> selected = <dynamic>{};
    String? customLabel;

    // If you already had a stored free-text relationship, seed it as custom.
    if (currentRelationship.trim().isNotEmpty) {
      customLabel = currentRelationship.trim();
    }

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Set relationship',
                style: Theme.of(sheetCtx).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),

              // Use the wrapper widget; no direct RelTag/RelationPicker usage here.
              EditContactRelationSection(
                // We won't pass initialTags from here (keeps types opaque).
                initialCustomLabel: customLabel,
                onTagsChanged: (tags) {
                  // tags is a Set<RelTag> inside that file; we keep it dynamic here.
                  selected = {...tags};
                },
                onCustomLabelChanged: (label) {
                  customLabel = (label == null || label.trim().isEmpty)
                      ? null
                      : label.trim();
                },
              ),

              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(sheetCtx),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Save'),
                    onPressed: () {
                      // Collapse to a single string for your existing map:
                      // 1) Prefer custom label if provided
                      // 2) Else, first selected tag's name via toString() -> "RelTag.mother" -> "Mother"
                      // 3) Else, empty string
                      String collapsed = '';
                      if (customLabel != null && customLabel!.isNotEmpty) {
                        collapsed = customLabel!;
                      } else if (selected.isNotEmpty) {
                        final first = selected.first
                            .toString(); // e.g. "RelTag.mother"
                        final raw = first.contains('.')
                            ? first.split('.').last
                            : first;
                        collapsed = raw.isEmpty
                            ? ''
                            : raw[0].toUpperCase() + raw.substring(1);
                      }
                      Navigator.pop(sheetCtx, collapsed);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (result != null) {
      await onSetRelationship(contactId, result);
    }
  }

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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      c.photo != null && c.photo!.isNotEmpty
                          ? CircleAvatar(
                              radius: 24,
                              backgroundImage: MemoryImage(c.photo!),
                            )
                          : CircleAvatar(
                              radius: 24,
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
                          ],
                        ),
                      ),
                      // Trailing compact icon row: chevron + relation-edit
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Icon(Icons.chevron_right_rounded),
                          IconButton(
                            tooltip: 'Set relation',
                            icon: Icon(
                              relationship.isNotEmpty
                                  ? Icons.favorite
                                  : Icons.favorite_outline,
                            ),
                            onPressed: () => _editRelationshipViaPicker(
                              context: context,
                              contactId: c.id,
                              currentRelationship: relationship,
                              onSetRelationship: onSetRelationship,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Events (block line BEFORE the action buttons)
                  ...events.map((e) {
                    final eventDate = DateTime(
                      DateTime.now().year,
                      e.event.month,
                      e.event.day,
                    );
                    final formatted = DateFormat.MMMd(
                      Localizations.localeOf(context).toString(),
                    ).format(eventDate);

                    final label = capitalize(e.event.label.name);
                    final firstName = e.contact.displayName.split(' ').first;

                    final eventKey =
                        'reminder_${e.contact.id}_${e.event.label.name}_${e.event.month}_${e.event.day}';
                    final isReminderSet = reminderDaysMap.containsKey(eventKey);

                    final message =
                        'Hey $firstName, just wanted to wish you a happy ${label.toLowerCase()}! Hope you and yours are doing well. Have a great one!';

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 2, 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              '$label  •  $formatted',
                              style: Theme.of(context).textTheme.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _ActionIconRow(
                            isReminderSet: isReminderSet,
                            onRemind: () async {
                              final selected = await showModalBottomSheet<int>(
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
                            onGift: () {
                              showGiftIdeasSheet(
                                context: context,
                                recipientName: c.displayName,
                                occasion: label, // e.g., "Birthday"
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
          );
        },
      ),
    );
  }
}

/// Row of compact action icons (Remind • Message • Gift)
class _ActionIconRow extends StatelessWidget {
  const _ActionIconRow({
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: isReminderSet ? 'Reminder set' : 'Set reminder',
          icon: Icon(
            isReminderSet
                ? Icons.notifications_active
                : Icons.notifications_none,
            color: cs.onSurface,
          ),
          onPressed: onRemind,
        ),
        IconButton(
          tooltip: 'Send message',
          icon: Icon(Icons.send_rounded, color: cs.onSurface),
          onPressed: onShare,
        ),
        IconButton(
          tooltip: 'Gift ideas',
          icon: Icon(Icons.card_giftcard_rounded, color: cs.primary),
          onPressed: onGift,
        ),
      ],
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
