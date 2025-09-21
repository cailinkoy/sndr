import 'package:flutter/material.dart';

// --- Canonical tags (same enum you’re using) ---
enum RelTag {
  mother,
  father,
  parent,
  spouse,
  partner,
  boyfriend,
  girlfriend,
  child,
  daughter,
  son,
  sibling,
  sister,
  brother,
  friend,
  coworker,
  manager,
  grandparent,
  grandmother,
  grandfather,
  aunt,
  uncle,
  cousin,
  guardian,
  other,
}

// Display names for UI
const Map<RelTag, String> _tagLabel = {
  RelTag.mother: 'Mother',
  RelTag.father: 'Father',
  RelTag.parent: 'Parent',
  RelTag.spouse: 'Spouse',
  RelTag.partner: 'Partner',
  RelTag.boyfriend: 'Boyfriend',
  RelTag.girlfriend: 'Girlfriend',
  RelTag.child: 'Child',
  RelTag.daughter: 'Daughter',
  RelTag.son: 'Son',
  RelTag.sibling: 'Sibling',
  RelTag.sister: 'Sister',
  RelTag.brother: 'Brother',
  RelTag.friend: 'Friend',
  RelTag.coworker: 'Coworker',
  RelTag.manager: 'Manager',
  RelTag.grandparent: 'Grandparent',
  RelTag.grandmother: 'Grandmother',
  RelTag.grandfather: 'Grandfather',
  RelTag.aunt: 'Aunt',
  RelTag.uncle: 'Uncle',
  RelTag.cousin: 'Cousin',
  RelTag.guardian: 'Guardian',
  RelTag.other: 'Other',
};

List<RelTag> get _allTags => RelTag.values;

// Optional: simple alias normalization (you can expand later)
RelTag? aliasToRelTag(String input) {
  final t = input.trim().toLowerCase();
  switch (t) {
    case 'mom':
    case 'mommy':
    case 'mother':
    case 'mama':
    case 'mum':
    case 'mamá':
      return RelTag.mother;
    case 'dad':
    case 'daddy':
    case 'father':
      return RelTag.father;
    case 'parent':
      return RelTag.parent;
    case 'wife':
    case 'husband':
    case 'spouse':
      return RelTag.spouse;
    case 'partner':
    case 'fiancé':
    case 'fiance':
    case 'fiancée':
      return RelTag.partner;
    case 'boyfriend':
      return RelTag.boyfriend;
    case 'girlfriend':
      return RelTag.girlfriend;
    case 'child':
      return RelTag.child;
    case 'daughter':
      return RelTag.daughter;
    case 'son':
      return RelTag.son;
    case 'sibling':
      return RelTag.sibling;
    case 'sister':
      return RelTag.sister;
    case 'brother':
      return RelTag.brother;
    case 'friend':
      return RelTag.friend;
    case 'coworker':
    case 'colleague':
      return RelTag.coworker;
    case 'boss':
    case 'manager':
      return RelTag.manager;
    case 'grandparent':
      return RelTag.grandparent;
    case 'grandmother':
    case 'grandma':
    case 'nana':
      return RelTag.grandmother;
    case 'grandfather':
    case 'grandpa':
      return RelTag.grandfather;
    case 'aunt':
      return RelTag.aunt;
    case 'uncle':
      return RelTag.uncle;
    case 'cousin':
      return RelTag.cousin;
    case 'guardian':
      return RelTag.guardian;
    case 'other':
      return RelTag.other;
  }
  return null;
}

/// A compact, reusable picker for relationship tags + optional custom label.
/// - Multi-select chips (canonical tags)
/// - Search box to filter tags
/// - Free-text custom label preserved
class RelationPicker extends StatefulWidget {
  final Set<RelTag> initialTags;
  final String? initialCustomLabel;
  final ValueChanged<Set<RelTag>>? onTagsChanged;
  final ValueChanged<String?>? onCustomLabelChanged;

  const RelationPicker({
    super.key,
    this.initialTags = const {},
    this.initialCustomLabel,
    this.onTagsChanged,
    this.onCustomLabelChanged,
  });

  @override
  State<RelationPicker> createState() => _RelationPickerState();
}

class _RelationPickerState extends State<RelationPicker> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _customCtrl = TextEditingController();
  late Set<RelTag> _selected;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initialTags};
    _customCtrl.text = widget.initialCustomLabel ?? '';
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _customCtrl.dispose();
    super.dispose();
  }

  void _toggle(RelTag tag) {
    setState(() {
      if (_selected.contains(tag)) {
        _selected.remove(tag);
      } else {
        _selected.add(tag);
      }
    });
    widget.onTagsChanged?.call(_selected);
  }

  List<RelTag> _filtered() {
    if (_query.isEmpty) return _allTags;
    return _allTags.where((t) {
      final lbl = _tagLabel[t]!.toLowerCase();
      return lbl.contains(_query);
    }).toList();
  }

  void _applyAliasToTagIfObvious(String text) {
    final tag = aliasToRelTag(text);
    if (tag != null && !_selected.contains(tag)) {
      setState(() => _selected.add(tag));
      widget.onTagsChanged?.call(_selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Relationship', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _searchCtrl,
          decoration: const InputDecoration(
            hintText: 'Search (e.g., Mother, Partner)…',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),

        // Selected chips preview (keeps choices visible)
        if (_selected.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selected
                .map(
                  (t) => InputChip(
                    label: Text(_tagLabel[t]!),
                    selected: true,
                    onDeleted: () => _toggle(t),
                  ),
                )
                .toList(),
          ),

        const SizedBox(height: 8),
        // Grid-ish chip list (filtered)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in filtered)
              FilterChip(
                label: Text(_tagLabel[t]!),
                selected: _selected.contains(t),
                onSelected: (_) => _toggle(t),
              ),
          ],
        ),

        const SizedBox(height: 16),
        Text(
          'Custom label (optional)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _customCtrl,
          decoration: const InputDecoration(
            hintText: 'e.g., College Roomie, Kiddo, Senpai',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) {
            widget.onCustomLabelChanged?.call(
              v.trim().isEmpty ? null : v.trim(),
            );
          },
          onSubmitted: (v) {
            // If user typed an obvious alias, auto-add matching tag to help them.
            _applyAliasToTagIfObvious(v);
          },
        ),
      ],
    );
  }
}
