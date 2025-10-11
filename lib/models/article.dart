class Article {
  final String title;
  final String excerpt;
  final List<String> tags;
  final String sentiment;
  final String url;
  final DateTime date;
  String? summary; // nullable, filled after calling LLM

  Article({
    required this.title,
    required this.excerpt,
    required this.tags,
    required this.sentiment,
    required this.url,
    required this.date,
    this.summary,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      title: json['headline'] ?? 'No title',
      excerpt: json['summary'] ?? '',
      tags: [], // You can parse categories if you want
      sentiment: '', // Optional: leave empty or generate
      url: json['url'] ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(
        (json['datetime'] ?? 0) * 1000, // Finnhub returns seconds
      ),
    );
  }
}
