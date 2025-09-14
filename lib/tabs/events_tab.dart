import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/event_info.dart';
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

/// ---------- Row model & helpers for month headers ----------
sealed class _RowItem {}

class _MonthHeaderItem implements _RowItem {
  final int year;
  final int month; // 1..12
  _MonthHeaderItem(this.year, this.month);
}

class _EventRowItem implements _RowItem {
  final EventInfo event;
  _EventRowItem(this.event);
}

String _monthLabel(int year, int month) =>
    DateFormat.yMMMM().format(DateTime(year, month, 1));

/// Next upcoming date from month/day, rolling to next year if needed.
DateTime _eventDateFrom(EventInfo item) {
  final e = item.event;
  final now = DateTime.now();
  var dt = DateTime(now.year, e.month, e.day);
  final today = DateTime(now.year, now.month, now.day);
  if (dt.isBefore(today)) dt = DateTime(now.year + 1, e.month, e.day);
  return dt;
}

/// Build a flattened list with headers injected before each month section.
List<_RowItem> _buildUpcomingRows(List<EventInfo> events) {
  final sorted = [...events]
    ..sort((a, b) => _eventDateFrom(a).compareTo(_eventDateFrom(b)));

  final rows = <_RowItem>[];
  int? currentYear, currentMonth;

  for (final ev in sorted) {
    final d = _eventDateFrom(ev);
    if (currentYear != d.year || currentMonth != d.month) {
      currentYear = d.year;
      currentMonth = d.month;
      rows.add(_MonthHeaderItem(currentYear, currentMonth));
    }
    rows.add(_EventRowItem(ev));
  }
  return rows;
}

/// Polished month header that matches your aesthetic.
class _MonthHeader extends StatelessWidget {
  const _MonthHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      // reducing spacing a little
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: cs.primary.withValues(alpha: 0.18),
            width: 1,
          ),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [cs.surface, cs.surface.withValues(alpha: 0.92)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.calendar_today_rounded,
                size: 18,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              // match event title size/weight
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.1,
                color: cs.onSurface.withValues(alpha: 0.95),
              ),
            ),
            const Spacer(),
            Container(
              height: 1.4,
              width: 52,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EventsTab extends StatelessWidget {
  const EventsTab({
    super.key,
    required this.allEvents,
    required this.reminderDaysMap,
    required this.onPickReminderDays,
    required this.onSelectReminder,
    required this.onSetRelationship,
  });

  final List<EventInfo> allEvents;
  final Map<String, int> reminderDaysMap;
  final PickDays onPickReminderDays;
  final SelectReminder onSelectReminder;
  final SetRelationship onSetRelationship;

  String capitalize(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

  // "Joe Napolez" -> "Joe Napolez's", "James" -> "James'"
  String _possessive(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    final last = trimmed.characters.last;
    return (last == 's' || last == 'S') ? "$trimmed'" : "$trimmed's";
  }

  @override
  Widget build(BuildContext context) {
    // Keep your “show top 10 upcoming” behavior.
    final visibleEvents = allEvents.take(10).toList();
    final rows = _buildUpcomingRows(visibleEvents);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: ListView.builder(
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];

          // ----- Month header row -----
          if (row is _MonthHeaderItem) {
            return _MonthHeader(_monthLabel(row.year, row.month));
          }

          // ----- Event card row -----
          final item = (row as _EventRowItem).event;
          final c = item.contact;
          final e = item.event;

          final eventDate = _eventDateFrom(item);
          final formattedDate = DateFormat('EEE, MMM d').format(eventDate);
          final eventLabel = capitalize(e.label.name); // e.g., Birthday

          final firstName = c.displayName.split(' ').first;
          final message =
              'Hey $firstName, just wanted to wish you a happy ${eventLabel.toLowerCase()}! Hope you and yours are doing well. Have a great one!';

          final eventKey =
              'reminder_${c.id}_${e.label.name}_${e.month}_${e.day}';
          final isReminderSet = reminderDaysMap.containsKey(eventKey);

          // New first line: "Joe Napolez's birthday"
          final titleLine =
              "${_possessive(c.displayName)} ${eventLabel.toLowerCase()}";

          // New second line: date + countdown (no event type here)
          final subtitleLine =
              '${item.daysLeft} days from now  •  $formattedDate';

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 0, 10), // hanging indent
            child: _EventCard(
              avatar: c.photo != null && c.photo!.isNotEmpty
                  ? CircleAvatar(
                      radius: 22,
                      backgroundImage: MemoryImage(c.photo!),
                    )
                  : CircleAvatar(
                      radius: 22,
                      child: Text(
                        c.displayName.isNotEmpty
                            ? c.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
              title: titleLine,
              subtitle: subtitleLine,
              onTapTitle: () => onSetRelationship(c.id, ''), // hook if desired
              actionPills: _ActionPillRow(
                isReminderSet: isReminderSet,
                onRemind: () async {
                  final selected = await showModalBottomSheet<int>(
                    context: context,
                    builder: (sheetCtx) =>
                        _ReminderSheet(isReminderSet: isReminderSet),
                  );
                  if (!context.mounted) return;
                  await onSelectReminder(context, item, selected);
                },
                onShare: () async {
                  await SharePlus.instance.share(ShareParams(text: message));
                },
                onGift: () {
                  showGiftIdeasSheet(
                    context: context,
                    recipientName: c.displayName,
                    occasion: eventLabel, // e.g., "Birthday"
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Generic card used for each Upcoming item (avatar + title/subtitle + action pills)
class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.avatar,
    required this.title,
    required this.subtitle,
    required this.actionPills,
    this.onTapTitle,
  });

  final Widget avatar;
  final String title;
  final String subtitle;
  final Widget actionPills;
  final VoidCallback? onTapTitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                avatar,
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: onTapTitle,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Slightly heavier than before, to read as the event title
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            actionPills,
          ],
        ),
      ),
    );
  }
}

/// Row of compact, modern action "pills" (Remind • Share • Gift)
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
