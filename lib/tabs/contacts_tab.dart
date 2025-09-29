import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/event_info.dart';
import '../widgets/relation_picker_section.dart';
import '../gift_ideas/gift_ideas_sheet.dart';
import 'dart:typed_data';

// ✅ Memoize per-contact ImageProviders to prevent flicker on rebuilds
final Map<String, ImageProvider> _avatarProviderCache = {};

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
    this.avatarCache,
  });

  final List<EventInfo> allEvents;
  final Map<String, int> reminderDaysMap;
  final Map<String, String> contactRelationships;
  final PickDays onPickReminderDays;
  final SelectReminder onSelectReminder;
  final SetRelationship onSetRelationship;
  final Map<String, Uint8List>? avatarCache;

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

          // ✅ Memoize provider per contact id (uses cached bytes if available)
          final Uint8List? photoBytes = avatarCache?[c.id] ?? c.photo;
          final ImageProvider? provider =
              (photoBytes == null || photoBytes.isEmpty)
              ? null
              : (_avatarProviderCache[c.id] ??= MemoryImage(photoBytes));

          return Card(
            key: ValueKey(c.id), // ✅ stable key prevents remount on rebuild
            elevation: 1,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              // slightly tighter spacing
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LEFT: larger rounded-rectangle avatar
                  _RoundedRectAvatar(
                    name: c.displayName,
                    photoBytes: photoBytes, // kept for compatibility
                    provider: provider, // ✅ use memoized provider when present
                    size: 64, // bump to 72 if you want bigger
                    radius: 18, // match your mock
                  ),
                  const SizedBox(width: 12),

                  // RIGHT: name header + stacked events as "sub-bullets"
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                c.displayName,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
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
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                ),

                                // Compact heart—won't raise the row height
                                IconButton(
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
                                  iconSize: 20,
                                  style: IconButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(
                                      24,
                                      24,
                                    ), // keep it small
                                    tapTargetSize: MaterialTapTargetSize
                                        .shrinkWrap, // no 48px min
                                    visualDensity: const VisualDensity(
                                      horizontal: -4,
                                      vertical: -4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Events stacked (label • date) with actions on the right
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
                          final firstName = e.contact.displayName
                              .split(' ')
                              .first;

                          final eventKey =
                              'reminder_${e.contact.id}_${e.event.label.name}_${e.event.month}_${e.event.day}';
                          final isReminderSet = reminderDaysMap.containsKey(
                            eventKey,
                          );

                          final message =
                              'Hey $firstName, just wanted to wish you a happy ${label.toLowerCase()}! Hope you and yours are doing well. Have a great one!';

                          return Padding(
                            padding: const EdgeInsets.fromLTRB(0, 2, 0, 0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    '$label  •  $formatted',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _ActionIconRow(
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
                                    await onSelectReminder(
                                      context,
                                      e,
                                      selected,
                                    );
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
                                      occasionDate: formatted,
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

    IconButton mini(
      IconData icon,
      String tip,
      VoidCallback onTap, {
      Color? color,
    }) {
      return IconButton(
        tooltip: tip,
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: color ?? cs.onSurface),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          minimumSize: const Size(36, 36),
          padding: EdgeInsets.zero,
          visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mini(
          isReminderSet ? Icons.notifications_active : Icons.notifications_none,
          isReminderSet ? 'Reminder set' : 'Set reminder',
          onRemind,
        ),
        mini(Icons.send_rounded, 'Send message', onShare),
        mini(
          Icons.card_giftcard_rounded,
          'Gift ideas',
          onGift,
          color: cs.primary,
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

/// Reusable rounded-rectangle avatar used by the card
class _RoundedRectAvatar extends StatelessWidget {
  const _RoundedRectAvatar({
    required this.name,
    required this.photoBytes, // compatible with Uint8List?
    this.provider, // ✅ optional memoized provider
    this.size = 64,
    this.radius = 16,
    super.key,
  });

  final String name;
  final Uint8List? photoBytes;
  final ImageProvider? provider; // ✅ new
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );

    // ✅ Use memoized provider when available (no re-resolution)
    if (provider != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image(
          image: provider!,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    if (photoBytes == null || photoBytes!.isEmpty) return fallback;

    // Fallback: render from bytes (kept for compatibility)
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.memory(
        photoBytes!,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}
