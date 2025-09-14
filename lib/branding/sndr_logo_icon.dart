import 'package:flutter/material.dart';
import 'sndr_logo.dart';

/// Rounded-square app icon lockup for SNDR.
/// Use this for splash, launcher icon source, marketing tiles.
/// - Keeps padding consistent so the bow/wordmark have breathing room.
/// - Set [showWordmark] = false for pure icon, true for banner tile.
class SndrLogoIcon extends StatelessWidget {
  const SndrLogoIcon({
    super.key,
    this.size = 1024, // good master size for launcher generation
    this.bgColor = const Color(0xFF121212),
    this.logoColor,
    this.cornerRadius = 220, // scales nicely down to 48–192
    this.showWordmark = false,
    this.logoHeightFactor = 0.56, // portion of square height used by logo
  });

  final double size;
  final Color bgColor;
  final Color? logoColor;
  final double cornerRadius;
  final bool showWordmark;
  final double logoHeightFactor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(cornerRadius),
      child: Container(
        width: size,
        height: size,
        color: bgColor,
        alignment: Alignment.center,
        child: SndrLogo(
          height: size * logoHeightFactor,
          color: logoColor ?? Theme.of(context).colorScheme.primary,
          showWordmark: showWordmark,
        ),
      ),
    );
  }
}
