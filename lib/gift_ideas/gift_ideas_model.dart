// gift_ideas_model.dart
class GiftIdea {
  final String title;
  final String url; // affiliate link
  final String price; // e.g., "$25–$40" or "$39.99"
  final String note; // short why-it-fits blurb (optional)
  GiftIdea({
    required this.title,
    required this.url,
    this.price = '',
    this.note = '',
  });
}

// Very basic Amazon affiliate tag helper.
// Replace `YOUR_AMAZON_TAG` with your tag (e.g., "cailin-20").
String withAmazonTag(String url, {String tag = 'YOUR_AMAZON_TAG'}) {
  final uri = Uri.parse(url);
  final qp = Map<String, String>.from(uri.queryParameters);
  qp['tag'] = tag;
  return uri.replace(queryParameters: qp).toString();
}
