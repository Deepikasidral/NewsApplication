class Article {
  final String title;      // Headline
  final String excerpt;    // Can keep first 200 chars of story for preview
  final String story;      // Full story HTML/text
  final List<String> tags; // Category + Subcategory
  final String sentiment;  // Optional
  final String url;        // link
  final DateTime date;     // PublishedAt
  String? summary;         // nullable, filled after LLM

  Article({
    required this.title,
    required this.excerpt,
    required this.story,
    required this.tags,
    required this.sentiment,
    required this.url,
    required this.date,
    this.summary,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    final storyText = (json['story'] ?? '').toString();
    final excerptText = storyText.length > 200
        ? storyText.substring(0, 200) + '...'
        : storyText;

    return Article(
      title: json['Headline'] ?? 'Untitled',
      excerpt: excerptText,
      story: storyText,
      tags: [
        if (json['category'] != null) '#${json['category']}',
        if (json['subcategory'] != null) '#${json['subcategory'].toString().trim()}'
      ],
      sentiment: '', // leave empty for now
      url: json['link'] ?? '',
      date: DateTime.tryParse(json['PublishedAt']) ??
          DateTime.now(), // fallback to now if parsing fails
    );
  }
}
