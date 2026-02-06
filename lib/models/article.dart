import 'package:html/parser.dart' as html;
import 'package:intl/intl.dart';

class Article {
  final String id;
  final String title;
  final String excerpt;
  final String story;
  final List<String> tags;
  final String url;
  final DateTime date;

  // ---- AI / PROCESSED FIELDS ----
  final String summary;
  final String rationale;
  final String tone;
  final String impact;
  final String sentiment;

  final String sector;          // Rupee Letter sector
  final String sector_market;    // TradingView sector
  final bool commodities;   // True/False
  final List<String> commodities_market;

  final List<String> companies;

  Article({
    required this.id,
    required this.title,
    required this.excerpt,
    required this.story,
    required this.tags,
    required this.url,
    required this.date,
    this.summary = "",
    this.rationale = "",
    this.tone = "",
    this.impact = "",
    this.sentiment = "",
    this.sector = "",
    this.sector_market = "",
    this.commodities = false,
    this.commodities_market = const [],
    this.companies = const [],
  });

  // ---------------- HTML CLEANER ----------------
  static String cleanHtml(String? data) {
    if (data == null || data.isEmpty) return "";
    final doc = html.parse(data);
    return doc.body?.text.trim() ?? "";
  }

  // ---------------- JSON PARSER ----------------
  factory Article.fromJson(Map<String, dynamic> json) {
    final rawStory = (json['story'] ?? '').toString();
    final storyText = cleanHtml(rawStory);

    final excerptText = storyText.length > 200
        ? '${storyText.substring(0, 200)}...'
        : storyText;

    final List<String> companiesList =
        (json['companies'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

    final List<String> commoditiesList =
        (json['commodities_market'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

    return Article(
      id: json['_id'].toString(),
      title: cleanHtml(json['Headline'] ?? 'Untitled'),
      excerpt: excerptText,
      story: storyText,

      tags: [
        if (json['category'] != null) '#${json['category']}',
        if (json['subcategory'] != null)
          '#${json['subcategory'].toString().trim()}',
      ],

      url: json['link'] ?? '',
      date: parsePublishedAt(json['PublishedAt']),

      summary: cleanHtml(json['summary']),
      rationale: cleanHtml(json['impact_rationale']),
      tone: json['tone'] ?? "",
      impact: json['impact'] ?? "",
      sentiment: json['sentiment'] ?? "",

      sector: json['sector'] ?? "",
      sector_market: json['sector_market'] ?? "",

      commodities: json['commodities'] ?? false,
      commodities_market: commoditiesList,

      companies: companiesList,
    );
  }
}

// ---------------- DATE PARSER ----------------
DateTime parsePublishedAt(String? input) {
  if (input == null || input.isEmpty) return DateTime.now();

  try {
    return DateFormat("EEEE, MMM d, yyyy HH:mm:ss").parse(input);
  } catch (e) {
    return DateTime.now();
  }
}
