// lib/models/article.dart

import 'package:html/parser.dart' as html;
import 'package:intl/intl.dart';


class Article {
  final String title;       // Headline
  final String excerpt;     // Preview text
  final String story;       // Full story
  final List<String> tags;  // Category + subcategory
  final String url;         // link
  final DateTime date;      // PublishedAt

  // ---- NEW FIELDS FROM DB ----
  final String summary;
  final String rationale;
  final String tone;
  final String impact;
  final String sector;
  final String sentiment;

  Article({
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
  });

  // -------------------------------------------------------
  //                HTML CLEANER UTILITY
  // -------------------------------------------------------
  static String cleanHtml(String? data) {
    if (data == null || data.isEmpty) return "";
    final doc = html.parse(data);
    return doc.body?.text ?? "";
  }

  // -------------------------------------------------------
  //                JSON PARSER
  // -------------------------------------------------------
  factory Article.fromJson(Map<String, dynamic> json) {
    // Clean full story from HTML
    final rawStory = (json['story'] ?? '').toString();
    final storyText = cleanHtml(rawStory);

    // Generate excerpt from cleaned story
    final excerptText = storyText.length > 200
        ? storyText.substring(0, 200) + '...'
        : storyText;

    return Article(
      title: cleanHtml(json['Headline'] ?? 'Untitled'),
      excerpt: excerptText,
      story: storyText,

      tags: [
        if (json['category'] != null) '#${json['category']}',
        if (json['subcategory'] != null)
          '#${json['subcategory'].toString().trim()}'
      ],

      url: json['link'] ?? '',
      date: parsePublishedAt(json['PublishedAt']),


      // --- Clean AI fields too ---
      summary: cleanHtml(json['summary'] ?? ""),
      rationale: cleanHtml(json['rationale'] ?? ""),
      tone: json['tone'] ?? "",
      impact: json['impact'] ?? "",
      sector: json['sector'] ?? "",
      sentiment: json['sentiment'] ?? "",
    );
  }
}
DateTime parsePublishedAt(String? input) {
  if (input == null || input.isEmpty) return DateTime.now();

  try {
    // Matches: Friday, Oct 17, 2025 16:10:52
    return DateFormat("EEEE, MMM d, yyyy HH:mm:ss").parse(input);
  } catch (e) {
    print("Date parse error: $e");
    return DateTime.now();
  }
}