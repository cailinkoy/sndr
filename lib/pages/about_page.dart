import 'package:flutter/material.dart';

/// Shared data: sections of the About page
final aboutSections = [
  (
    "Contact",
    """
• Email for support or questions: info@umeko.digital 
• Instagram: @umeko.digital  
• Feedback & bugs: In-app “Contact/Support” form (About → Contact)
""",
  ),
  (
    "Privacy",
    """
We do **not** sell OR share personal data. Device contacts are read to show contact info for your use; we do not upload your contact book to third parties or display your information across other apps. We store only what we need to make reminders and gift idea functions work. 
""",
  ),
  (
    "Affiliate Links",
    """
Some product links contain affiliate links. It doesn't change your price and helps support SNDR.
""",
  ),
  (
    "FAQ",
    """
**Q: Why am I seeing Amazon so often?**  
A: We're diversifying sources (Target, Etsy, REI, Bookshop.org, Lego, Best Buy, Sephora, Steam, etc.). You'll see more variety over time.

**Q: Can I use SNDR without an account?**  
A: Yes for core features. Some premium features will be gated but won't require social logins.

**Q: How accurate are dates?**  
A: We rely on your entries and device contacts. If something looks off, edit the event; SNDR recalculates immediately.

**Q: How do I request a feature?**  
A: Use the in-app Contact form or email us.
""",
  ),
];

/// Page widget that renders the sections
class AboutPage extends StatelessWidget {
  const AboutPage({super.key, required this.sections});

  final List<(String, String)> sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sections.length,
        itemBuilder: (context, index) {
          final (title, body) = sections[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(body, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          );
        },
      ),
    );
  }
}
