// lib/gift_ideas/gift_ideas_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Unified model that matches your Cloud Function's JSON
/// and leaves room for affiliate links you add later.
class GiftIdea {
  final String title;
  final String rationale;
  final double? approxPriceUSD;
  final List<String> categories;
  final String urlHint; // keywords to search (e.g., "artisan coffee sampler")
  final int wowFactor;

  /// Optional: where you store a resolved/affiliate URL you compute client- or server-side.
  final String? affiliateUrl;

  /// Optional: allow backend to send an ASIN; we’ll build a canonical /dp/ URL if present.
  final String? asin;

  /// Optional: example image to show alongside the idea (server-provided).
  final String? imageUrl;

  /// Optional: alt text/caption for accessibility.
  final String? imageAlt;

  GiftIdea({
    required this.title,
    required this.rationale,
    this.approxPriceUSD,
    this.categories = const [],
    this.urlHint = "",
    this.wowFactor = 3,
    this.affiliateUrl,
    this.asin,
    this.imageUrl,
    this.imageAlt,
  });

  factory GiftIdea.fromJson(Map<String, dynamic> j) {
    // Defensive parsing / alias support
    final title = (j['title'] ?? j['name'] ?? '').toString();
    final rationale = (j['rationale'] ?? j['description'] ?? j['why'] ?? '')
        .toString();

    double? approxPriceUSD;
    final p = j['approxPriceUSD'] ?? j['price'] ?? j['priceUSD'];
    if (p is num) {
      approxPriceUSD = p.toDouble();
    } else if (p is Map) {
      final v = p['value'] ?? p['usd'];
      if (v is num) approxPriceUSD = v.toDouble();
    }

    final categories = (j['categories'] as List?)?.cast<String>() ?? const [];
    final urlHint =
        (j['urlHint'] ?? j['hint'] ?? j['query'] ?? j['search'] ?? '')
            .toString();
    final wowFactor = (j['wowFactor'] is num)
        ? (j['wowFactor'] as num).toInt()
        : 3;

    // Prefer an explicit product URL if the backend provides one.
    final explicitUrl =
        (j['affiliateUrl'] ?? j['productUrl'] ?? j['amazonUrl']);
    final affiliateUrl =
        (explicitUrl is String && explicitUrl.trim().isNotEmpty)
        ? explicitUrl.trim()
        : null;

    final asin = (j['asin'] as String?)?.trim();

    // Image support: accept several common field names.
    final imageUrlRaw =
        (j['imageUrl'] ?? j['image_url'] ?? j['image'] ?? j['thumbnail']);
    final imageUrl = (imageUrlRaw is String && imageUrlRaw.trim().isNotEmpty)
        ? imageUrlRaw.trim()
        : null;
    final imageAlt = (j['imageAlt'] ?? j['image_alt'] ?? j['caption'] ?? '')
        .toString();

    return GiftIdea(
      title: title,
      rationale: rationale,
      approxPriceUSD: approxPriceUSD,
      categories: categories,
      urlHint: urlHint,
      wowFactor: wowFactor,
      affiliateUrl: affiliateUrl,
      asin: asin,
      imageUrl: imageUrl,
      imageAlt: imageAlt.isNotEmpty ? imageAlt : null,
    );
  }

  GiftIdea copyWith({
    String? affiliateUrl,
    String? imageUrl,
    String? imageAlt,
  }) => GiftIdea(
    title: title,
    rationale: rationale,
    approxPriceUSD: approxPriceUSD,
    categories: categories,
    urlHint: urlHint,
    wowFactor: wowFactor,
    affiliateUrl: affiliateUrl ?? this.affiliateUrl,
    asin: asin,
    imageUrl: imageUrl ?? this.imageUrl,
    imageAlt: imageAlt ?? this.imageAlt,
  );
}

/// Very basic Amazon affiliate tag helper.
String withAmazonTag(String url, {String tag = 'YOUR_AMAZON_TAG'}) {
  final uri = Uri.parse(url);
  final qp = Map<String, String>.from(uri.queryParameters);
  qp['tag'] = tag;
  return uri.replace(queryParameters: qp).toString();
}

/// Convenience: build an Amazon search URL from the model's urlHint.
String amazonSearchUrlFromHint(String urlHint) {
  final q = Uri.encodeQueryComponent(urlHint.isEmpty ? 'gift ideas' : urlHint);
  return 'https://www.amazon.com/s?k=$q';
}

/// Convenience: build a canonical Amazon product URL from an ASIN.
String amazonProductUrlFromAsin(String asin) =>
    'https://www.amazon.com/dp/$asin';

class GiftIdeasService {
  final String functionUrl;

  GiftIdeasService(this.functionUrl);

  /// Calls function and returns both:
  /// - pretty-printed raw JSON (for debugging)
  /// - parsed ideas (optionally enriched with affiliate URLs)
  Future<({String rawJson, List<GiftIdea> ideas})> generateIdeas({
    required String occasion,
    required String budget,
    List<String> interests = const [],
    Map<String, dynamic> recipient = const {},
    String locale = 'en-US',
    bool attachAmazonAffiliateLinks = false,
    String amazonAffiliateTag = 'YOUR_AMAZON_TAG',
  }) async {
    // (1) Strict payload first (includes both string budget and numeric min/max)
    final parsedBudget = _parseBudget(budget);
    final strictPayload = <String, dynamic>{
      'occasion': occasion,
      'budget': budget, // keep raw
      if (parsedBudget.$1 != null) 'budgetMin': parsedBudget.$1,
      if (parsedBudget.$2 != null) 'budgetMax': parsedBudget.$2,
      if (interests.isNotEmpty) 'interests': interests,
      'recipient': recipient,
      'locale': locale,
      'attachAmazonAffiliateLinks': attachAmazonAffiliateLinks,
      'amazonAffiliateTag': amazonAffiliateTag,
      'imagePlaceholders': 'unsplash',
    };

    final first = await _postAndParse(functionUrl, strictPayload);
    if (first.ideas.isNotEmpty) {
      return _maybeTag(first, attachAmazonAffiliateLinks, amazonAffiliateTag);
    }

    // (2) Relaxed retry (remove budget constraints; add gentle hints)
    final relaxedPayload = Map<String, dynamic>.from(strictPayload)
      ..remove('budget')
      ..remove('budgetMin')
      ..remove('budgetMax')
      ..putIfAbsent(
        'hints',
        () => [
          'provide at least 5 ideas',
          'include urlHint text for each idea',
          'include approxPriceUSD when possible',
          // Optional hint for images (harmless if backend ignores).
          'include imageUrl if you can for one representative product image',
        ],
      )
      ..putIfAbsent('forceIdeas', () => true);

    final second = await _postAndParse(functionUrl, relaxedPayload);
    if (second.ideas.isNotEmpty) {
      return _maybeTag(second, attachAmazonAffiliateLinks, amazonAffiliateTag);
    }

    // (3) Still empty? Provide graceful client-side fallbacks so the UI isn’t blank
    final fallbackIdeas = _fallbackForOccasion(
      occasion,
      recipient['name']?.toString() ?? '',
    );
    // ignore: avoid_print
    print(
      '[GiftIdeasService] backend returned 0 ideas twice; using ${fallbackIdeas.length} local fallbacks',
    );
    final rawJson = second.rawJson.isNotEmpty ? second.rawJson : first.rawJson;
    final tagged = attachAmazonAffiliateLinks
        ? fallbackIdeas
              .map(
                (g) => g.copyWith(
                  affiliateUrl: withAmazonTag(
                    amazonSearchUrlFromHint(
                      g.urlHint.isNotEmpty ? g.urlHint : g.title,
                    ),
                    tag: amazonAffiliateTag,
                  ),
                ),
              )
              .toList()
        : fallbackIdeas;
    return (rawJson: rawJson, ideas: tagged);
  }

  // ---- Private helpers ----

  // Posts JSON (UTF-8), accepts multiple result shapes, returns parsed ideas + pretty raw
  Future<({String rawJson, List<GiftIdea> ideas})> _postAndParse(
    String url,
    Map<String, dynamic> payload,
  ) async {
    final resp = await http.post(
      Uri.parse(url),
      headers: const {'Content-Type': 'application/json; charset=utf-8'},
      body: utf8.encode(jsonEncode(payload)),
    );

    final raw = utf8.decode(resp.bodyBytes);
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: $raw');
    }

    final decoded = jsonDecode(raw);

    dynamic list;
    if (decoded is Map) {
      list =
          decoded['ideas'] ??
          decoded['items'] ??
          decoded['suggestions'] ??
          (decoded['data'] is Map ? decoded['data']['ideas'] : null) ??
          decoded['text'] ??
          decoded['content'];
    } else if (decoded is List) {
      list = decoded;
    }

    List<GiftIdea> ideas = [];
    if (list is List) {
      ideas = list
          .whereType<Map>()
          .map((j) => GiftIdea.fromJson(Map<String, dynamic>.from(j)))
          .where((g) => g.title.trim().isNotEmpty)
          .toList();
    } else if (list is String) {
      // Very defensive: parse simple bullet/numbered lines "Title - rationale"
      final lines = list.split('\n');
      for (final line in lines) {
        final t = line.trimLeft();
        if (t.startsWith('- ') ||
            t.startsWith('* ') ||
            RegExp(r'^\d+[.)]\s').hasMatch(t)) {
          final cleaned = t
              .replaceFirst(RegExp(r'^(-|\*|\d+[.)])\s+'), '')
              .trim();
          if (cleaned.isEmpty) continue;

          String title = cleaned;
          String rationale = '';
          final sep = cleaned.contains(' - ')
              ? ' - '
              : (cleaned.contains(' — ') ? ' — ' : '');
          if (sep.isNotEmpty) {
            final parts = cleaned.split(sep);
            title = parts.first.trim();
            rationale = parts.skip(1).join(sep).trim();
          }

          ideas.add(
            GiftIdea(
              title: title,
              rationale: rationale,
              approxPriceUSD: null,
              categories: const [],
              urlHint: title, // good default for building search links
              wowFactor: 3,
            ),
          );
        }
      }
    }

    final pretty = const JsonEncoder.withIndent('  ').convert(decoded);
    // ignore: avoid_print
    print(
      '[GiftIdeasService] parsed ${ideas.length} ideas (payload keys: ${payload.keys.toList()})',
    );
    return (rawJson: pretty, ideas: ideas);
  }

  // Parses "$25-$100" / "25-100" / "$50" etc. into (min,max)
  (double?, double?) _parseBudget(String budget) {
    final nums = RegExp(r'(\d+(\.\d+)?)')
        .allMatches(budget)
        .map((m) => double.tryParse(m.group(1)!))
        .whereType<double>()
        .toList();
    if (nums.isEmpty) return (null, null);
    if (nums.length == 1) return (nums.first, nums.first);
    nums.sort();
    return (nums.first, nums.last);
  }

  // Lightweight local ideas so the UI shows *something* if backend is empty
  List<GiftIdea> _fallbackForOccasion(String occasion, String name) {
    final o = occasion.toLowerCase();
    final base = <GiftIdea>[];

    if (o.contains('birthday')) {
      base.addAll([
        GiftIdea(
          title: 'Artisan Chocolate Box',
          rationale: 'Small-batch truffles',
          urlHint: 'artisan chocolate truffle box',
          approxPriceUSD: 25,
          wowFactor: 4,
        ),
        GiftIdea(
          title: 'Hinoki Scented Candle',
          rationale: 'Japandi vibes',
          urlHint: 'hinoki candle',
          approxPriceUSD: 22,
          wowFactor: 3,
        ),
        GiftIdea(
          title: 'Engraved Phone Stand',
          rationale: 'Custom name for $name',
          urlHint: 'engraved wooden phone stand',
          approxPriceUSD: 20,
          wowFactor: 3,
        ),
        GiftIdea(
          title: 'Mini AeroPress Go',
          rationale: 'Travel-friendly coffee maker',
          urlHint: 'AeroPress Go coffee press',
          approxPriceUSD: 40,
          wowFactor: 4,
        ),
        GiftIdea(
          title: 'Cozy Throw Blanket',
          rationale: 'Neutral, soft, machine-washable',
          urlHint: 'fleece throw blanket neutral',
          approxPriceUSD: 25,
          wowFactor: 3,
        ),
      ]);
    } else if (o.contains('anniv')) {
      base.addAll([
        GiftIdea(
          title: 'Date-Night Cookbook',
          rationale: 'Cook together, try new recipes',
          urlHint: 'date night cookbook',
          approxPriceUSD: 28,
          wowFactor: 3,
        ),
        GiftIdea(
          title: 'Custom Star Map Print',
          rationale: 'Night sky from your special date',
          urlHint: 'custom star map print',
          approxPriceUSD: 45,
          wowFactor: 4,
        ),
        GiftIdea(
          title: 'Massage Oil Set',
          rationale: 'At-home spa',
          urlHint: 'massage oil gift set',
          approxPriceUSD: 25,
          wowFactor: 3,
        ),
      ]);
    } else {
      base.addAll([
        GiftIdea(
          title: 'A5 Dot-Grid Notebook',
          rationale: 'Lays flat, dotted pages',
          urlHint: 'a5 dot grid notebook',
          approxPriceUSD: 14,
          wowFactor: 3,
        ),
        GiftIdea(
          title: 'Insulated Tumbler 20oz',
          rationale: 'Daily hydration',
          urlHint: 'insulated stainless steel tumbler 20 oz',
          approxPriceUSD: 20,
          wowFactor: 3,
        ),
        GiftIdea(
          title: 'Desk Cable Organizer',
          rationale: 'Keep cords tidy',
          urlHint: 'magnetic cable organizer desk',
          approxPriceUSD: 15,
          wowFactor: 3,
        ),
      ]);
    }

    return base;
  }

  // Adds affiliate tags to the returned list if requested.
  ({String rawJson, List<GiftIdea> ideas}) _maybeTag(
    ({String rawJson, List<GiftIdea> ideas}) res,
    bool attach,
    String tag,
  ) {
    if (!attach || res.ideas.isEmpty) return res;
    final tagged = res.ideas.map((g) {
      // Priority: explicit affiliate/product URL > ASIN > search
      final baseUrl = (g.affiliateUrl != null && g.affiliateUrl!.isNotEmpty)
          ? g.affiliateUrl!
          : (g.asin != null && g.asin!.isNotEmpty)
          ? amazonProductUrlFromAsin(g.asin!)
          : amazonSearchUrlFromHint(g.urlHint.isNotEmpty ? g.urlHint : g.title);
      return g.copyWith(affiliateUrl: withAmazonTag(baseUrl, tag: tag));
    }).toList();
    return (rawJson: res.rawJson, ideas: tagged);
  }
}
