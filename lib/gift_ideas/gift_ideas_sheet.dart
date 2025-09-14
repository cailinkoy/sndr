// lib/gift_ideas/gift_ideas_sheet.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../pages/gift_ideas_page.dart'; // GiftIdeasPage + OccasionRef
import 'gift_ideas_service.dart'; // model + service + affiliate helpers
import 'dart:convert'; // trying to get thumbnails for gift idea products

// deployed Cloud Function URL here
const kFunctionUrl =
    "https://us-central1-skilful-reducer-385816.cloudfunctions.net/giftIdeas";

// Amazon affiliate tag
const kAmazonAffiliateTag = "sassydove00-20";

final giftIdeasService = GiftIdeasService(kFunctionUrl);

Future<void> showGiftIdeasSheet({
  required BuildContext context,
  required String recipientName,
  required String occasion,
  String? contactId, // optional from caller
  String? occasionDate, // optional ISO date "YYYY-MM-DD"
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: false,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _GiftIdeasSheetContent(
      recipientName: recipientName,
      occasion: occasion,
      contactId: contactId,
      occasionDate: occasionDate,
    ),
  );
}

class _GiftIdeasSheetContent extends StatefulWidget {
  const _GiftIdeasSheetContent({
    required this.recipientName,
    required this.occasion,
    this.contactId,
    this.occasionDate,
  });

  final String recipientName;
  final String occasion;
  final String? contactId;
  final String? occasionDate;

  @override
  State<_GiftIdeasSheetContent> createState() => _GiftIdeasSheetContentState();
}

class _GiftIdeasSheetContentState extends State<_GiftIdeasSheetContent> {
  bool _loading = false;
  String? _error;
  List<GiftIdea> _ideas = const [];

  // ---- Pretty, theme-aware styles (cosmetic only) ----
  ButtonStyle get _primaryBtnStyle => FilledButton.styleFrom(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );

  ButtonStyle get _secondaryBtnStyle => OutlinedButton.styleFrom(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );

  ButtonStyle get _tertiaryBtnStyle => TextButton.styleFrom(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );

  Future<void> _getAiIdeas() async {
    setState(() {
      _loading = true;
      _error = null;
      _ideas = const [];
    });

    try {
      final result = await giftIdeasService.generateIdeas(
        occasion: widget.occasion,
        budget: r"$25-$100", // default; no Budget box in the sheet
        interests: const [],
        recipient: {"name": widget.recipientName},
        locale: "en-US",
        attachAmazonAffiliateLinks: true,
        amazonAffiliateTag: kAmazonAffiliateTag,
      );
      if (!mounted) return;
      setState(() {
        _ideas = result.ideas.take(2).toList(); // preview a few
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false); // no return in finally
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ensure non-null contactId when routing to the page to avoid legacy auto-open.
    final fallbackContactId =
        'name:${widget.recipientName.toLowerCase().replaceAll(RegExp(r"\s+"), "-")}';
    final contactKey =
        (widget.contactId != null && widget.contactId!.trim().isNotEmpty)
        ? widget.contactId!
        : fallbackContactId;

    final occasionId =
        '${widget.occasion.toLowerCase().replaceAll(" ", "-")}-$contactKey';

    final fullName = widget.recipientName.trim();
    final shortName = fullName.split(RegExp(r'\s+')).first; // first word

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.card_giftcard),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Gift ideas for ${widget.recipientName}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Three actions (no Budget here) — mirrors the page (cosmetic styles only)
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 370;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      style: _secondaryBtnStyle,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('TODO: hook up “Give flowers” flow'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.local_florist_rounded),
                      label: Text(isCompact ? 'Flowers' : 'Give flowers'),
                    ),
                    OutlinedButton.icon(
                      style: _secondaryBtnStyle,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('TODO: hook up “Give e-card” flow'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.email_rounded),
                      label: Text(isCompact ? 'E-card' : 'Give e-card'),
                    ),
                    FilledButton.icon(
                      style: _primaryBtnStyle,
                      onPressed: _loading ? null : _getAiIdeas,
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: Text('Get tailored AI gift ideas for $shortName'),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 12),

            // Results / states
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_error != null)
              _ErrorBanner(_error!)
            else if (_ideas.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Tap “Get AI ideas” to generate suggestions.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              ..._ideas.map((it) => _IdeaTile(it)),
            // Footer: jump to the full page
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                style: _tertiaryBtnStyle,
                onPressed: () {
                  Navigator.pop(context); // close sheet
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GiftIdeasPage(
                        contactId: contactKey,
                        contactName: widget.recipientName,
                        occasions: [
                          OccasionRef(
                            id: occasionId,
                            title: widget.occasion,
                            dateIso: widget.occasionDate,
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: Text('More gift ideas for $shortName >>>'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdeaTile extends StatelessWidget {
  final GiftIdea idea;
  const _IdeaTile(this.idea);

  @override
  Widget build(BuildContext context) {
    final priceStr = _formatPrice(idea.approxPriceUSD);
    final hasLink =
        (idea.affiliateUrl != null && idea.affiliateUrl!.isNotEmpty) ||
        idea.urlHint.isNotEmpty;

    return ListTile(
      dense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0.0),
      // 👇 Thumbnail if provided; else the original gift icon
      leading: _IdeaThumb(imageUrl: idea.imageUrl),
      title: Text(idea.title),
      subtitle: idea.rationale.isEmpty ? null : Text(idea.rationale),
      trailing: priceStr == null ? null : Text(priceStr),
      onTap: hasLink ? () => _openLink(context, idea) : null,
    );
  }

  Future<void> _openLink(BuildContext context, GiftIdea idea) async {
    // Prefer affiliateUrl; fall back to an Amazon search built from urlHint
    final url =
        idea.affiliateUrl ??
        withAmazonTag(
          amazonSearchUrlFromHint(idea.urlHint),
          tag: kAmazonAffiliateTag,
        );

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Using ScaffoldMessenger without additional mounted checks is fine here.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open link')));
    }
  }

  String? _formatPrice(double? usd) {
    if (usd == null) return null;
    return '\$${usd.toStringAsFixed(0)}';
  }
}

/// Small, resilient thumbnail with rounded corners; falls back to an icon.
class _IdeaThumb extends StatelessWidget {
  final String? imageUrl;
  const _IdeaThumb({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return const Icon(Icons.redeem);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 56,
        height: 56,
        child: Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          // Show fallback icon if image fails to load
          errorBuilder: (_, _, _) => const Center(child: Icon(Icons.redeem)),
          // Gentle fade-in when the frame arrives
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) return child;
            return const SizedBox(
              width: 56,
              height: 56,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          },
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(message, style: TextStyle(color: scheme.onErrorContainer)),
      ),
    );
  }
}
