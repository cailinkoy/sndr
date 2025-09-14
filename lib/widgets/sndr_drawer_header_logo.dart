import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'sndr_logo.dart';

class SndrDrawerHeaderLogo extends StatelessWidget {
  const SndrDrawerHeaderLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // The main logo (bow + [sndr])
        const SndrLogoNew(),
        const SizedBox(height: 6),
        // Tagline
        Text(
          'Celebrate your people, right on time',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.white70,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}
