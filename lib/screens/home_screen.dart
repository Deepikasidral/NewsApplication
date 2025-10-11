// lib/screens/news_feed_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:html/parser.dart' show parse;


import '../models/article.dart';

class NewsFeedScreen extends StatefulWidget {
  const NewsFeedScreen({super.key});

  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends State<NewsFeedScreen> {
  // read key from .env (set in main.dart with dotenv.load(...))
  final String? _apiKey =
      dotenv.env['MARKETAUX_API_KEY'] ?? dotenv.env['API_KEY'];

  final TextEditingController _searchController = TextEditingController();

  List<Article> _articles = [];
  List<Article> _filtered = [];
  bool _isLoading = false;
  String _error = '';
  int _bottomIndex = 0;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applySearch);
    _fetchNews();
  }

  @override
  void dispose() {
    _searchController.removeListener(_applySearch);
    _searchController.dispose();
    super.dispose();
  }

  void _applySearch() {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filtered = List.from(_articles));
      return;
    }
    setState(() {
      _filtered = _articles.where((a) {
        final hay = '${a.title} ${a.excerpt} ${a.tags.join(' ')}'.toLowerCase();
        return hay.contains(q);
      }).toList();
    });
  }
  Future<String> fetchFullArticleText(String url) async {
  try {
    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode == 200) {
      final document = parse(resp.body);
      // Get all text inside <p> tags (basic extraction)
      final paragraphs = document.getElementsByTagName('p');
      final text = paragraphs.map((e) => e.text.trim()).where((t) => t.isNotEmpty).join('\n\n');
      return text.isNotEmpty ? text : '';
    }
  } catch (e) {
    debugPrint('Error fetching full article from $url: $e');
  }
  return '';
}

  Future<void> _fetchNews() async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      setState(() {
        _error = 'API key not found. Add API_KEY (or MARKETAUX_API_KEY) to .env';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final uri = Uri.https('api.marketaux.com', '/v1/news/all', {
        'api_token': _apiKey!,
        'countries': 'in',
        'language': 'en',
        'filter_entities': 'true',
        'industries': 'Financial Services',
        'limit': '30',
      });

      final resp = await http.get(uri).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final Map<String, dynamic> jsonBody = jsonDecode(resp.body);
        final List<dynamic> data = jsonBody['data'] ?? [];

        final List<Article> parsed = data.map<Article>((item) {
          // Marketaux fields: title, description, source, published_at, url, entities
          final title = item['title'] ?? 'No title';
          final excerpt = item['description'] ?? '';
          final url = item['url'] ?? '';
          DateTime date;
          try {
            date = DateTime.parse(item['published_at']);
          } catch (_) {
            date = DateTime.now();
          }
          final List<String> tags = [];
          try {
            if (item['entities'] is List) {
              for (final ent in item['entities']) {
                if (ent is Map && ent['name'] != null) tags.add('#${ent['name']}');
              }
            }
          } catch (_) {}
          // sentiment left empty for now
          return Article(
            title: title,
            excerpt: excerpt,
            tags: tags,
            sentiment: '',
            url: url,
            date: date,
          );
        }).toList();

        parsed.sort((a, b) => b.date.compareTo(a.date));

        if (!mounted) return;
        setState(() {
          _articles = parsed;
          _filtered = List.from(parsed);
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _error = 'Failed to fetch news (code ${resp.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error fetching news: $e';
        _isLoading = false;
      });
    }
  }
  Future<String?> fetchSummary(String text) async {
  try {
    final uri = Uri.parse('http://10.170.141.198:8000/summarize');
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': text}),
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return data['summary'] as String?;
    }
  } catch (e) {
    debugPrint("Error fetching summary: $e");
  }
  return null;
}


 Future<void> _showSummary(Article article) async {
  if (article.summary != null) {
    _showDialog(article.summary!);
    return;
  }

  // Show loading
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  String content = article.excerpt; // fallback
  if (article.url.isNotEmpty) {
    final fullText = await fetchFullArticleText(article.url);
    if (fullText.isNotEmpty) content = fullText;
  }

  final summary = await fetchSummary(content);
  Navigator.pop(context); // remove loading

  if (summary != null) {
    setState(() => article.summary = summary); // cache locally
    _showDialog(summary);
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to fetch summary')),
    );
  }
}


void _showDialog(String summary) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('News Summary'),
      content: Text(summary),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}


  Widget _buildTopSearchRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      child: Row(
        children: [
          // Search box
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF6B3B3),
                borderRadius: BorderRadius.circular(28),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: "Search here...",
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  const Icon(Icons.search, color: Colors.black54),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // profile avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const CircleAvatar(
              radius: 20,
              backgroundImage: NetworkImage('https://i.pravatar.cc/300'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabsRow() {
    final tabs = ["Home", "Markets", "For you", "Sector Wise", "Trending"];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: SizedBox(
        height: 46,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: tabs.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, idx) {
            final isSelected = idx == _tabIndex;
            return GestureDetector(
              onTap: () => setState(() => _tabIndex = idx),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFEDECF0) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    tabs[idx],
                    style: TextStyle(
                      color: isSelected ? Colors.black87 : Colors.black54,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildArticleCard(Article a) {
    final dateFormatted = DateFormat.yMMMd().add_jm().format(a.date);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.06), blurRadius: 8)],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              a.title,
              style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),

            // Date
            Text(
              dateFormatted,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),

            // Excerpt
            if (a.excerpt.isNotEmpty)
              Text(
                a.excerpt,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade800, height: 1.35),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 10),

            // Read more button + tags row
            Row(
              children: [
                InkWell(
                      onTap: () => _showSummary(a), // use _showSummary instead of _openUrl
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF05151).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "READ MORE",
                          style: TextStyle(color: Color(0xFFF05151), fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ),
                    ),

                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: (a.tags.isEmpty ? <String>['#news'] : a.tags)
                        .map((t) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(t, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Sentiment line (if available)
            if (a.sentiment.isNotEmpty)
              RichText(
                text: TextSpan(
                  text: "Sentiment: ",
                  style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade700, fontSize: 13),
                  children: [
                    TextSpan(
                      text: a.sentiment,
                      style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeed() {
    if (_isLoading) {
      return const Expanded(child: Center(child: CircularProgressIndicator()));
    }

    if (_error.isNotEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _fetchNews,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_filtered.isEmpty) {
      return const Expanded(
        child: Center(child: Text('No articles found')),
      );
    }

    return Expanded(
      child: RefreshIndicator(
        onRefresh: _fetchNews,
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 10, bottom: 90),
          itemCount: _filtered.length,
          itemBuilder: (context, index) => _buildArticleCard(_filtered[index]),
        ),
      ),
    );
  }

  BottomNavigationBarItem _navItem(IconData icon, String label) {
    return BottomNavigationBarItem(icon: Icon(icon), label: label);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopSearchRow(),
            const SizedBox(height: 6),
            _buildTabsRow(),
            const SizedBox(height: 10),
            _buildFeed(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomIndex,
        onTap: (i) => setState(() => _bottomIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFEA6B6B),
        unselectedItemColor: Colors.black54,
        backgroundColor: Colors.white,
        items: [
          _navItem(Icons.feed, "Feed"),
          _navItem(Icons.local_fire_department, "Trending"),
          _navItem(Icons.currency_bitcoin, "Crypto"),
          _navItem(Icons.bookmark, "Saved"),
        ],
      ),
    );
  }
}
