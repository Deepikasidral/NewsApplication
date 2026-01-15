// lib/models/article.dart

import 'package:html/parser.dart' as html;
import 'package:intl/intl.dart';

class Article {
  final String id; // MongoDB _id
  final String title;       // Headline
  final String excerpt;     // Preview text
  final String story;       // Full story
  final List<String> tags;  // Category + subcategory
  final String url;         // link
  final DateTime date;      // PublishedAt

  // ---- AI / PROCESSED FIELDS ----
  final String summary;
  final String rationale;
  final String tone;
  final String impact;
  final String sector;      // kept for compatibility
  final String sentiment;
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
    this.sector = "",
    this.sentiment = "",
    this.companies = const [],
  });

  // -------------------------------------------------------
  //                HTML CLEANER UTILITY
  // -------------------------------------------------------
  static String cleanHtml(String? data) {
    if (data == null || data.isEmpty) return "";
    final doc = html.parse(data);
    return doc.body?.text.trim() ?? "";
  }

  // -------------------------------------------------------
  //                JSON PARSER
  // -------------------------------------------------------
  factory Article.fromJson(Map<String, dynamic> json) {
    // Clean full story from HTML
    final rawStory = (json['story'] ?? '').toString();
    final storyText = cleanHtml(rawStory);

    // Generate excerpt
    final excerptText = storyText.length > 200
        ? '${storyText.substring(0, 200)}...'
        : storyText;

    // Parse companies array
    final List<String> companiesList =
        (json['companies'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

    return Article(
      id: json['_id'].toString(), // ✅ REQUIRED
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

      // ---- AI fields ----
      summary: cleanHtml(json['summary']),
      rationale: cleanHtml(json['rationale']),
      tone: json['tone'] ?? "",
      impact: json['impact'] ?? "",
      sector: json['sector'] ?? "",
      sentiment: json['sentiment'] ?? "",
      companies: companiesList,
    );
  }
}

// -------------------------------------------------------
//                DATE PARSER
// -------------------------------------------------------
DateTime parsePublishedAt(String? input) {
  if (input == null || input.isEmpty) return DateTime.now();

  try {
    // Example: Friday, Oct 17, 2025 17:51:17
    return DateFormat("EEEE, MMM d, yyyy HH:mm:ss").parse(input);
  } catch (e) {
    print("Date parse error: $e");
    return DateTime.now();
  }
}