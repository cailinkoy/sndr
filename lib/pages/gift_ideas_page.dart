// lib/pages/gift_ideas_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// Use your existing service + model
import '../gift_ideas/gift_ideas_service.dart' as svc;

/// Cloud Function URL (duplicate of the one in the sheet to avoid circular imports).
const String _kFunctionUrl = "https://giftideas-gcfew24r6a-uc.a.run.app";
// Give Flowers and E-card links
const _kFlowersUrl = 'https://amzn.to/3IbYoT6';
const _kEcardUrl = 'https://your-ecard-url.example';

/// Lightweight occasion model (passed in when navigating from a contact’s sheet).
class OccasionRef {
  OccasionRef({
    required this.id, // stable key you choose (e.g., "birthday-2025-11-15")
    required this.title, // e.g., "Birthday", "Anniversary"
    this.dateIso, // optional: "2025-11-15"
  });

  final String id;
  final String title;
  final String? dateIso;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'dateIso': dateIso,
  };

  factory OccasionRef.fromJson(Map<String, dynamic> json) => OccasionRef(
    id: (json['id'] ?? '') as String,
    title: (json['title'] ?? '') as String,
    dateIso: json['dateIso'] as String?,
  );
}

/// Per-occasion purchase/budget state stored locally.
class OccasionPurchaseState {
  OccasionPurchaseState({
    this.budget = '',
    this.purchased = false,
    this.notes = '',
  });

  final String budget;
  final bool purchased;
  final String notes;

  OccasionPurchaseState copyWith({
    String? budget,
    bool? purchased,
    String? notes,
  }) => OccasionPurchaseState(
    budget: budget ?? this.budget,
    purchased: purchased ?? this.purchased,
    notes: notes ?? this.notes,
  );

  Map<String, dynamic> toJson() => {
    'budget': budget,
    'purchased': purchased,
    'notes': notes,
  };

  factory OccasionPurchaseState.fromJson(Map<String, dynamic> json) =>
      OccasionPurchaseState(
        budget: (json['budget'] ?? '') as String,
        purchased: (json['purchased'] ?? false) as bool,
        notes: (json['notes'] ?? '') as String,
      );
}

class GiftIdeasPage extends StatefulWidget {
  const GiftIdeasPage({
    super.key,
    this.prefillPerson, // legacy support (kept)
    this.contactId, // new: unique ID of the person (optional but recommended)
    this.contactName, // new: display name for title "Gift Ideas for X"
    this.occasions, // new: list of occasions for this person
  });

  final String? prefillPerson;
  final String? contactId;
  final String? contactName;
  final List<OccasionRef>? occasions;

  @override
  State<GiftIdeasPage> createState() => _GiftIdeasPageState();
}

class _GiftIdeasPageState extends State<GiftIdeasPage> {
  // ===== Storage keys =====
  static const _ideasStoreKey = 'gift_ideas_v1';
  static const _purchasesStoreKey = 'gift_purchases_v1'; // per-contact+occasion
  static const _notesStoreKey =
      'gift_notes_v1'; // NEW: per-contact notes used as AI 'interests'

  // ===== Manual ideas ( existing structure) =====
  final List<SavedGiftIdea> _ideas = [];

  // Notes persistence (per-contact)
  final Map<String, String> _notesMap = {};
  late final TextEditingController _notesCtrl = TextEditingController();

  // ===== Occasion purchase state =====
  // Keyed as "$contactKey|$occasionId"
  final Map<String, OccasionPurchaseState> _purchaseMap = {};

  // ===== AI ideas =====
  final List<svc.GiftIdea> _aiIdeas = [];
  bool _aiLoading = false;

  // service instance
  late final svc.GiftIdeasService _service = svc.GiftIdeasService(
    _kFunctionUrl,
  );

  // When a page is scoped to a contact, use this name for filtering/prefill.
  String? get _scopedName => (widget.contactName?.trim().isNotEmpty ?? false)
      ? widget.contactName!.trim()
      : (widget.prefillPerson?.trim().isNotEmpty ?? false)
      ? widget.prefillPerson!.trim()
      : null;

  String get _contactKey =>
      (widget.contactId != null && widget.contactId!.trim().isNotEmpty)
      ? widget.contactId!.trim()
      : (_scopedName ?? '');

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();

    // Load manual ideas (legacy-compatible)
    final rawIdeas = prefs.getString(_ideasStoreKey);
    if (rawIdeas != null && rawIdeas.isNotEmpty) {
      final decoded = jsonDecode(rawIdeas) as List<dynamic>;
      _ideas
        ..clear()
        ..addAll(
          decoded.map((e) => SavedGiftIdea.fromJson(e as Map<String, dynamic>)),
        );
    }

    // Load per-occasion purchase state
    final rawPurchases = prefs.getString(_purchasesStoreKey);
    if (rawPurchases != null && rawPurchases.isNotEmpty) {
      final decoded = jsonDecode(rawPurchases) as Map<String, dynamic>;
      _purchaseMap
        ..clear()
        ..addAll(
          decoded.map(
            (k, v) => MapEntry(
              k,
              OccasionPurchaseState.fromJson(v as Map<String, dynamic>),
            ),
          ),
        );
    }

    // === load notes map ===
    final rawNotes = prefs.getString(_notesStoreKey);
    if (rawNotes != null && rawNotes.isNotEmpty) {
      final decoded = jsonDecode(rawNotes) as Map<String, dynamic>;
      _notesMap
        ..clear()
        ..addAll(decoded.map((k, v) => MapEntry(k, (v ?? '').toString())));
    }
    // Initialize controller with this contact’s current notes
    _notesCtrl.text = _notesMap[_contactKey] ?? '';

    if (!mounted) return;
    setState(() => _loading = false);

    // If launched with a prefill (legacy path), offer quick-add
    if (_scopedName != null && (widget.contactId == null)) {
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return; // guard State.context use
      _openEditor(prefillPerson: _scopedName);
    }
  }

  Future<void> _saveIdeas() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_ideas.map((e) => e.toJson()).toList());
    await prefs.setString(_ideasStoreKey, encoded);
  }

  Future<void> _savePurchases() async {
    final prefs = await SharedPreferences.getInstance();
    final map = _purchaseMap.map((k, v) => MapEntry(k, v.toJson()));
    await prefs.setString(_purchasesStoreKey, jsonEncode(map));
  }

  // Save notes map
  Future<void> _saveNotesMap() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_notesStoreKey, jsonEncode(_notesMap));
  }

  // Notes change handler (persist per contact as user types)
  Future<void> _onNotesChanged(String value) async {
    _notesMap[_contactKey] = value;
    await _saveNotesMap();
  }

  // URL helper for flowers and e-cards
  Future<void> _openExternal(String raw) async {
    if (raw.isEmpty) return;
    if (!raw.contains('://')) raw = 'https://$raw';
    final uri = Uri.parse(raw);

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open link.')));
    }
  }

  // ===== Manual ideas editor (unchanged behavior) =====
  Future<void> _openEditor({
    SavedGiftIdea? existing,
    String? prefillPerson,
  }) async {
    final result = await showModalBottomSheet<SavedGiftIdea>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) =>
          _GiftEditorSheet(idea: existing, prefillPerson: prefillPerson),
    );
    if (result == null || !mounted) return;

    setState(() {
      if (existing == null) {
        _ideas.add(result);
      } else {
        final idx = _ideas.indexOf(existing);
        if (idx >= 0) _ideas[idx] = result;
      }
    });

    await _saveIdeas();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          existing == null ? 'Added gift idea' : 'Updated gift idea',
        ),
      ),
    );
  }

  Future<void> _delete(SavedGiftIdea idea) async {
    setState(() => _ideas.remove(idea));
    await _saveIdeas();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Deleted gift idea')));
  }

  // ===== Occasion helpers =====
  String _pkForOccasion(String occasionId) => '$_contactKey|$occasionId';

  OccasionPurchaseState _stateFor(String occasionId) {
    final key = _pkForOccasion(occasionId);
    return _purchaseMap[key] ?? OccasionPurchaseState();
  }

  Future<void> _updateOccasionState(
    String occasionId,
    OccasionPurchaseState newState,
  ) async {
    final key = _pkForOccasion(occasionId);
    setState(() {
      _purchaseMap[key] = newState;
    });
    await _savePurchases();
  }

  // ===== AI gift ideas (uses your GiftIdeasService.generateIdeas) =====
  Future<void> _getAiIdeas({
    required String forName,
    String? budgetDollars,
    String? occasionTitle,
  }) async {
    setState(() {
      _aiLoading = true;
      _aiIdeas.clear();
    });

    try {
      final normalizedBudget = (budgetDollars?.trim().isNotEmpty ?? false)
          ? '\$${budgetDollars!.trim()}'
          : r"$25-$100"; // <-- fallback so we never pass null

      final result = await _service.generateIdeas(
        occasion: (occasionTitle?.trim().isNotEmpty ?? false)
            ? occasionTitle!.trim()
            : 'Gift', // keep this non-null too
        budget: normalizedBudget, // <-- always a String
        interests: _notesCtrl.text.trim().isEmpty
            ? const []
            : [_notesCtrl.text.trim()],
        recipient: {"name": forName},
        locale: "en-US",
        attachAmazonAffiliateLinks: true,
        amazonAffiliateTag: "sassydove00-20",
      );

      if (!mounted) return;
      setState(() {
        _aiIdeas.addAll(result.ideas);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not load AI ideas: $e')));
    } finally {
      if (mounted) {
        setState(() => _aiLoading = false);
      }
    }
  }

  Future<void> _saveAiIdeaToManual(svc.GiftIdea idea) async {
    final who = _scopedName ?? '';
    final title = idea.title.trim().isNotEmpty
        ? idea.title.trim()
        : 'Gift idea';
    final link =
        (idea.affiliateUrl != null && idea.affiliateUrl!.trim().isNotEmpty)
        ? idea.affiliateUrl!.trim()
        : (idea.urlHint.trim().isNotEmpty ? idea.urlHint.trim() : '');
    final price = (idea.approxPriceUSD != null)
        ? '\$${idea.approxPriceUSD}'
        : '';
    final rationale = idea.rationale.trim();
    final notes = [
      if (rationale.isNotEmpty) rationale,
      if (price.isNotEmpty) 'Price: $price',
    ].join('\n');

    final saved = SavedGiftIdea(
      title: title,
      forWho: who,
      link: link,
      notes: notes,
    );

    setState(() {
      _ideas.add(saved);
    });
    await _saveIdeas();

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Saved to your ideas')));
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _openIdeaLink(svc.GiftIdea gi) async {
    // pick affiliate first, else fallback
    String raw = (gi.affiliateUrl != null && gi.affiliateUrl!.trim().isNotEmpty)
        ? gi.affiliateUrl!.trim()
        : gi.urlHint.trim();

    if (raw.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No link available for this idea.')),
      );
      return;
    }

    if (!raw.contains('://')) raw = 'https://$raw';
    final uri = Uri.parse(raw);

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open link.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleText = (_scopedName != null && _scopedName!.isNotEmpty)
        ? 'Gift Ideas for ${_scopedName!}'
        : 'Gift Ideas';

    final occasions = widget.occasions ?? const <OccasionRef>[];
    final cs = Theme.of(context).colorScheme;

    // Scope manual ideas view by person if we know who we're on.
    final manualIdeas = _scopedName == null
        ? _ideas
        : _ideas.where((e) => e.forWho.trim() == _scopedName).toList();

    return Scaffold(
      appBar: AppBar(title: Text(titleText), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(prefillPerson: _scopedName),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add idea'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                // ===== Notes (feeds AI 'interests') =====
                if (_scopedName != null) ...[
                  Text(
                    'Notes (used to tailor AI ideas)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesCtrl,
                    minLines: 3,
                    maxLines: 6,
                    onChanged: (v) {
                      _onNotesChanged(v);
                    }, // persist as you type
                    decoration: const InputDecoration(
                      hintText:
                          'e.g., loves cozy things, hates fragrances, into hiking, clutter-free gifts',
                      helperText:
                          'Saved automatically. Sent as “interests” to the AI ideas API.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ==== Occasions section (only if we have a contact & occasions) ====
                if (_scopedName != null && occasions.isNotEmpty) ...[
                  Text(
                    'Occasions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...occasions.map((o) {
                    final st = _stateFor(o.id);
                    final budgetCtrl = TextEditingController(text: st.budget);
                    final notesCtrl = TextEditingController(text: st.notes);

                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 12),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          14,
                          12,
                          14,
                          12,
                        ), // ← fixed: named arg
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title line
                            Row(
                              children: [
                                Icon(Icons.event_rounded, color: cs.primary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    o.title +
                                        (o.dateIso != null
                                            ? ' • ${o.dateIso}'
                                            : ''),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Budget + actions  no overflow on small screens
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isCompact =
                                    constraints.maxWidth <
                                    370; // tweak if you like
                                return Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 60,
                                      height: 40,
                                      child: TextField(
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                        controller: budgetCtrl,
                                        onChanged: (v) => _updateOccasionState(
                                          o.id,
                                          st.copyWith(budget: v),
                                        ),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: const InputDecoration(
                                          labelText: 'Budget',
                                          prefixText: '\$',
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),

                                    OutlinedButton.icon(
                                      onPressed: () {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: const Text(
                                              'Open flowers page?',
                                            ),
                                            action: SnackBarAction(
                                              label: 'Open',
                                              onPressed: () =>
                                                  _openExternal(_kFlowersUrl),
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.local_florist_rounded,
                                      ),
                                      label: Text(
                                        isCompact ? 'Flowers' : 'Give flowers',
                                      ),
                                    ),

                                    OutlinedButton.icon(
                                      onPressed: () {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: const Text(
                                              'Open e-card page?',
                                            ),
                                            action: SnackBarAction(
                                              label: 'Open',
                                              onPressed: () =>
                                                  _openExternal(_kEcardUrl),
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.email_rounded),
                                      label: Text(
                                        isCompact ? 'E-card' : 'Give e-card',
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),

                            const SizedBox(height: 8),

                            // Get AI ideas
                            Align(
                              alignment: Alignment.centerLeft,
                              child: FilledButton.icon(
                                onPressed: _aiLoading
                                    ? null
                                    : () => _getAiIdeas(
                                        forName: _scopedName!,
                                        budgetDollars:
                                            budgetCtrl.text.trim().isNotEmpty
                                            ? budgetCtrl.text.trim()
                                            : null,
                                        occasionTitle: o.title,
                                      ),
                                icon: const Icon(Icons.auto_awesome_rounded),
                                label: const Text('Get AI ideas'),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Purchased checkbox + notes
                            Row(
                              children: [
                                Checkbox(
                                  value: st.purchased,
                                  onChanged: (v) => _updateOccasionState(
                                    o.id,
                                    st.copyWith(purchased: v ?? false),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text('Mark as purchased'),
                              ],
                            ),
                            if (st.purchased) ...[
                              const SizedBox(height: 8),
                              TextField(
                                controller: notesCtrl,
                                onChanged: (v) => _updateOccasionState(
                                  o.id,
                                  st.copyWith(notes: v),
                                ),
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  labelText:
                                      'Notes about gift purchased (what you bought, price, etc)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                ],

                // ==== AI gift ideas section ====
                if (_scopedName != null) ...[
                  Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: cs.primary),
                      const SizedBox(width: 8),
                      Text(
                        'AI gift ideas',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      if (_aiLoading)
                        const Padding(
                          padding: EdgeInsets.only(right: 8.0),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_aiIdeas.isEmpty && !_aiLoading)
                    Text(
                      'Use “Get AI ideas” on an occasion above to generate ideas.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),

                  ..._aiIdeas.map((gi) {
                    final price = gi.approxPriceUSD != null
                        ? '\$${gi.approxPriceUSD}'
                        : '';
                    return Card(
                      elevation: 0.5,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          14,
                          12,
                          14,
                          12,
                        ), // ← fixed: named arg
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              gi.title,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            if (gi.rationale.trim().isNotEmpty)
                              Text(
                                gi.rationale.trim(),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (price.isNotEmpty) _Chip(text: '≈ $price'),
                                if ((gi.affiliateUrl != null &&
                                        gi.affiliateUrl!.isNotEmpty) ||
                                    gi.urlHint.isNotEmpty)
                                  _Chip(
                                    text: 'Link available',
                                    onTap: () => _openIdeaLink(gi),
                                  ),
                                const SizedBox(height: 8),
                                FilledButton.icon(
                                  onPressed: () => _saveAiIdeaToManual(gi),
                                  icon: const Icon(Icons.bookmark_add_outlined),
                                  label: const Text('Save to My Ideas'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],

                // ==== Manual ideas (your existing UI) ====
                Row(
                  children: [
                    Icon(Icons.card_giftcard_rounded, color: cs.primary),
                    const SizedBox(width: 8),
                    Text(
                      _scopedName == null
                          ? 'All saved ideas'
                          : 'My saved ideas',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (manualIdeas.isEmpty)
                  _EmptyState(
                    onTapAdd: () => _openEditor(prefillPerson: _scopedName),
                  )
                else
                  ...manualIdeas.map((idea) {
                    return Dismissible(
                      key: ValueKey(
                        '${idea.forWho}:${idea.title}:${idea.link}',
                      ),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        color: cs.errorContainer,
                        child: Icon(
                          Icons.delete_outline,
                          color: cs.onErrorContainer,
                        ),
                      ),
                      confirmDismiss: (_) async {
                        final result = await showDialog<bool>(
                          context: context,
                          builder: (dialogCtx) => AlertDialog(
                            title: const Text('Delete gift idea?'),
                            content: const Text('This cannot be undone.'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogCtx, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(dialogCtx, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        return result ?? false;
                      },
                      onDismissed: (_) => _delete(idea),
                      child: Card(
                        elevation: 1,
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _openEditor(existing: idea),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              14,
                              12,
                              14,
                              12,
                            ), // ← fixed: named arg
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.card_giftcard_rounded,
                                      color: cs.primary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        idea.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    if (idea.forWho.isNotEmpty)
                                      _Chip(text: 'For: ${idea.forWho}'),
                                    if (idea.link.isNotEmpty)
                                      _Chip(text: 'Link saved'),
                                  ],
                                ),
                                if (idea.notes.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    idea.notes,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}

/// Local model for *saved* ideas (stored in SharedPreferences).
class SavedGiftIdea {
  SavedGiftIdea({
    required this.title,
    this.forWho = '',
    this.link = '',
    this.notes = '',
  });

  final String title;
  final String forWho;
  final String link;
  final String notes;

  Map<String, dynamic> toJson() => {
    'title': title,
    'forWho': forWho,
    'link': link,
    'notes': notes,
  };

  factory SavedGiftIdea.fromJson(Map<String, dynamic> json) => SavedGiftIdea(
    title: (json['title'] ?? '') as String,
    forWho: (json['forWho'] ?? '') as String,
    link: (json['link'] ?? '') as String,
    notes: (json['notes'] ?? '') as String,
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onTapAdd});
  final VoidCallback onTapAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Column(
        children: [
          const SizedBox(height: 6),
          Text(
            'No saved ideas yet',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          Center(
            child: FilledButton.icon(
              onPressed: onTapAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add idea'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GiftEditorSheet extends StatefulWidget {
  const _GiftEditorSheet({this.idea, this.prefillPerson});
  final SavedGiftIdea? idea;
  final String? prefillPerson;

  @override
  State<_GiftEditorSheet> createState() => _GiftEditorSheetState();
}

class _GiftEditorSheetState extends State<_GiftEditorSheet> {
  late final TextEditingController _title = TextEditingController(
    text: widget.idea?.title ?? '',
  );
  late final TextEditingController _forWho = TextEditingController(
    text: widget.idea?.forWho ?? widget.prefillPerson ?? '',
  );
  late final TextEditingController _link = TextEditingController(
    text: widget.idea?.link ?? '',
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.idea?.notes ?? '',
  );

  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _title.dispose();
    _forWho.dispose();
    _link.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: viewInsets),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.idea == null ? 'Add gift idea' : 'Edit gift idea',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'Idea',
                    hintText: 'e.g., Handmade candle, book, game…',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter an idea'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _forWho,
                  decoration: const InputDecoration(
                    labelText: 'For',
                    hintText: 'Person (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _link,
                  decoration: const InputDecoration(
                    labelText: 'Link',
                    hintText: 'https://… (optional)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _notes,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    hintText: 'Color, size, preferences…',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;
                        final idea = SavedGiftIdea(
                          title: _title.text.trim(),
                          forWho: _forWho.text.trim(),
                          link: _link.text.trim(),
                          notes: _notes.text.trim(),
                        );
                        Navigator.pop(context, idea);
                      },
                      child: Text(widget.idea == null ? 'Add' : 'Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, this.onTap});
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(999);
    final bg = cs.surfaceContainerHigh;
    final label = Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: cs.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );

    if (onTap == null) {
      // non-interactive (exactly your original visuals)
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: radius),
        child: label,
      );
    }

    // interactive, keeps the same visuals + ripple
    return Material(
      color: bg,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: label,
        ),
      ),
    );
  }
}
