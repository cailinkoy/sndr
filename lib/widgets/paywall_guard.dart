// lib/widgets/paywall_guard.dart
import 'package:flutter/material.dart';
import '../core/entitlements.dart';
import '../core/feature_flags.dart';

class PaywallGuard extends StatelessWidget {
  final Widget child;
  final bool featureFlag; // e.g., FeatureFlags.premiumGiftIdeas

  const PaywallGuard({
    super.key,
    required this.child,
    required this.featureFlag,
  });

  @override
  Widget build(BuildContext context) {
    final allowed = Gate.canUsePremiumFeature(featureFlag);

    if (allowed) return child;

    // Dim + lock overlay
    return Stack(
      children: [
        Opacity(opacity: 0.45, child: child),
        Positioned.fill(
          child: Container(
            alignment: Alignment.center,
            color: Colors.black.withOpacity(0.25),
            child: _LockedCard(),
          ),
        ),
      ],
    );
  }
}

class _LockedCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, size: 28, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              'Premium feature',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Unlock more gift ideas and pro features.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            // For first submission: no real purchase button.
            // Show an informational action only (avoids store review issues).
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Premium Coming Soon'),
                    content: const Text(
                      'Thanks for checking this out! Premium is launching shortly. '
                      'In the meantime, you can use the free features.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Learn more'),
            ),
          ],
        ),
      ),
    );
  }
}
