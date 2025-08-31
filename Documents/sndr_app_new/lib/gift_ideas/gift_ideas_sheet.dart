// lib/gift_ideas/gift_ideas_sheet.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../pages/gift_ideas_page.dart';
import 'gift_ideas_service.dart'; // <- model + service + affiliate helpers

// deployed Cloud Function URL here
const kFunctionUrl = "https://giftideas-gcfew24r6a-uc.a.run.app";

// Amazon affiliate tag
const kAmazonAffiliateTag = "sassydove00-20";

final giftIdeasService = GiftIdeasService(kFunctionUrl);

Future<void> showGiftIdeasSheet({
  required BuildContext context,
  required String recipientName,
  required String occasion,
}) async {
  // Show a quick loading dialog while we fetch
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  String? error;
  List<GiftIdea> ideas = const [];

  try {
    final result = await giftIdeasService.generateIdeas(
      occasion: occasion,
      budget: r"$25-$100", // tweak as needed or pass in
      interests: const [], // pass interests if you have them
      recipient: {"name": recipientName},
      locale: "en-US",
      attachAmazonAffiliateLinks: true,
      amazonAffiliateTag: kAmazonAffiliateTag,
    );
    debugPrint('RAW ideas response:\n${result.rawJson}\n');
    // take top 3 for the sheet
    ideas = result.ideas.take(3).toList();
  } catch (e) {
    error = e.toString();
  } finally {
    if (context.mounted) Navigator.of(context).pop(); // close loader
  }

  if (!context.mounted) return;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: false,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) {
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
                      'Gift ideas for $recipientName',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (error != null)
                _ErrorBanner(error)
              else if (ideas.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text("No ideas yet — try again or adjust inputs."),
                )
              else
                ...ideas.map((it) => _IdeaTile(it)),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    // first close the bottom sheet
                    Navigator.pop(context);

                    // then navigate to GiftIdeasPage
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const GiftIdeasPage()),
                    );
                  },
                  child: const Text('More gift ideas >>>'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
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
      leading: const Icon(Icons.redeem),
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
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open link')));
      }
    }
  }

  String? _formatPrice(double? usd) {
    if (usd == null) return null;
    // Simple whole-dollar formatting
    return '\$${usd.toStringAsFixed(0)}';
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
