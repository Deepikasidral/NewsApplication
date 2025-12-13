// lib/screens/news_feed_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:html/parser.dart' show parse;

import '../models/article.dart';
import 'company_screen.dart';

class NewsFeedScreen extends StatefulWidget {
  const NewsFeedScreen({super.key});

  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends State<NewsFeedScreen> {
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

    // Load MongoDB news
    _fetchNewsFromMongo();
  }

  @override
  void dispose() {
    _searchController.removeListener(_applySearch);
    _searchController.dispose();
    super.dispose();
  }

  // ------------------------- SEARCH -------------------------
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

  // ------------------------- HTML CLEANER -------------------------
  String parseHtmlString(String htmlString) {
    final document = parse(htmlString);
    return document.body?.text ?? '';
  }

  // ------------------------- FETCH FROM MONGODB -------------------------
  Future<void> _fetchNewsFromMongo() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final resp =
          // await http.get(Uri.parse("http://10.69.144.93:5000/api/news"));
          await http.get(Uri.parse("http://192.168.1.7:5000/api/news"));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);

        _articles = (data as List).map((e) {
          return Article.fromJson(e);
        }).toList();

        _articles.sort((a, b) => b.date.compareTo(a.date));
        _filtered = List.from(_articles);
      } else {
        _error = "Failed to fetch news from DB";
      }
    } catch (e) {
      _error = "DB fetch failed: $e";
    }

    setState(() => _isLoading = false);
  }

  // ------------------------- OLD API (COMMENTED) -------------------------
  /*
  Future<void> _fetchNews() async {
     // your original PTI API logic (kept safe)
  }
  */

  // ------------------------- SHOW FULL STORY (NO API CALL) -------------------------
  Future<void> _showFullStory(Article a) async {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: Text(a.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (a.summary.isNotEmpty) ...[
                const Text("📝 Summary",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(a.summary),
                const SizedBox(height: 16),
              ],
              // if (a.rationale.isNotEmpty) ...[
              //   const Text("📌 Rationale",
              //       style: TextStyle(fontWeight: FontWeight.bold)),
              //   Text(a.rationale),
              //   const SizedBox(height: 16),
              // ],
              if (a.tone.isNotEmpty)
                Text("🎭 Tone: ${a.tone}", style: const TextStyle(fontSize: 13)),
              if (a.sentiment.isNotEmpty)
                Text("💬 Sentiment: ${a.sentiment}",
                    style: const TextStyle(fontSize: 13)),
              if (a.impact.isNotEmpty)
                Text("🔥 Impact: ${a.impact}",
                    style: const TextStyle(fontSize: 13)),
              if (a.sector.isNotEmpty)
                Text("🏦 Sector: ${a.sector}",
                    style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          )
        ],
      ),
    );
  }

  // ------------------------- UI WIDGETS -------------------------
  Widget _buildTopSearchRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      child: Row(
        children: [
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
                      ),
                    ),
                  ),
                  const Icon(Icons.search, color: Colors.black54),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          const CircleAvatar(
            radius: 22,
            backgroundImage: NetworkImage('https://i.pravatar.cc/300'),
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
            final selected = idx == _tabIndex;
            return GestureDetector(
              onTap: () => setState(() => _tabIndex = idx),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFEDECF0) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tabs[idx],
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? Colors.black : Colors.black54,
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.06), blurRadius: 8)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a.title,
                style: const TextStyle(
                    fontSize: 16.5, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(dateFormatted,
                style:
                    TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text(
              a.excerpt,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                GestureDetector(
                  onTap: () => _showFullStory(a),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF05151).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "READ MORE",
                      style: TextStyle(
                        color: Color(0xFFF05151),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    children: a.tags
                        .map((t) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                t,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ))
                        .toList(),
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeed() {
    if (_isLoading) {
      return const Expanded(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error.isNotEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            children: [
              Text(_error),
              ElevatedButton(
                onPressed: _fetchNewsFromMongo,
                child: const Text("Retry"),
              )
            ],
          ),
        ),
      );
    }

    if (_filtered.isEmpty) {
      return const Expanded(
        child: Center(child: Text("No articles found")),
      );
    }

    return Expanded(
      child: RefreshIndicator(
        onRefresh: _fetchNewsFromMongo,
        child: ListView.builder(
          itemCount: _filtered.length,
          padding: const EdgeInsets.only(bottom: 80),
          itemBuilder: (context, i) => _buildArticleCard(_filtered[i]),
        ),
      ),
    );
  }

  // ------------------------- MAIN BUILD -------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopSearchRow(),
            _buildTabsRow(),
            const SizedBox(height: 10),
            _buildFeed(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomIndex,
        onTap: (i) {
          if (i == 2) {
            // Navigate to Company screen when Company tab is tapped
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CompanyScreen()),
            );
          } else {
            setState(() => _bottomIndex = i);
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFEA6B6B),
        unselectedItemColor: Colors.black54,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.feed), label: "Feed"),
          BottomNavigationBarItem(
              icon: Icon(Icons.local_fire_department), label: "Trending"),
          BottomNavigationBarItem(
              icon: Icon(Icons.business), label: "Company"),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: "Saved"),
        ],
      ),
    );
  }
}

/*
// lib/screens/news_feed_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:html/parser.dart' show parse;

import '../models/article.dart';

class NewsFeedScreen extends StatefulWidget {
  const NewsFeedScreen({super.key});

  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends State<NewsFeedScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Article> _articles = [];
  List<Article> _filtered = [];
  bool _isLoading = false;
  String _error = '';
  int _bottomIndex = 0;
  int _tabIndex = 0;
  bool _isSummarizing = false;

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

  String parseHtmlString(String htmlString) {
    final document = parse(htmlString);
    return document.body?.text ?? '';
  }

  Future<String> fetchFullArticleText(String url) async {
    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        final document = parse(resp.body);
        final paragraphs = document.getElementsByTagName('p');
        final text = paragraphs
            .map((e) => e.text.trim())
            .where((t) => t.isNotEmpty)
            .join('\n\n');
        return text.isNotEmpty ? text : '';
      }
    } catch (e) {
      debugPrint('Error fetching full article from $url: $e');
    }
    return '';
  }

 Future<void> _fetchNews() async {
  setState(() {
    _isLoading = true;
    _error = '';
  });

  final centerCode = dotenv.env['CENTER_CODE'];
  if (centerCode == null || centerCode.isEmpty) {
    setState(() {
      _error = "❌ CENTER_CODE not found in .env file.";
      _isLoading = false;
    });
    return;
  }

  final now = DateTime.now();
  final yesterday = now.subtract(const Duration(hours: 24));
  final fromTime = Uri.encodeComponent(
      DateFormat('yyyy/MM/dd HH:mm:ss').format(yesterday));
  final endTime =
      Uri.encodeComponent(DateFormat('yyyy/MM/dd HH:mm:ss').format(now));

  final url = Uri.parse(
      'http://editorial.pti.in/ptiapi/webservice1.asmx/JsonFile1?centercode=$centerCode&FromTime=$fromTime&EndTime=$endTime');

  try {
    final resp = await http.get(url);
    if (resp.statusCode == 200) {
      final bodyString = utf8.decode(resp.bodyBytes);
      final cleaned =
          bodyString.replaceAll('<string>', '').replaceAll('</string>', '').trim();
      final data = json.decode(cleaned);

      _articles = (data as List)
          .map((e) => Article(
                title: e['Headline'] ?? 'Untitled',
                excerpt: e['story'] != null
                    ? parseHtmlString(e['story'])
                    : '',
                story: e['story'] ?? '',
                date: (() {
                  try {
                    return DateFormat('EEEE, MMM dd, yyyy HH:mm:ss')
                        .parse(e['PublishedAt']);
                  } catch (_) {
                    return DateTime.now();
                  }
                })(),
                url: e['link'] ?? '',
                tags: [
                  if (e['category'] != null) '#${e['category']}',
                  if (e['subcategory'] != null) '#${e['subcategory'].trim()}'
                ],
                sentiment: '',
              ))
          .toList();

      _articles.sort((a, b) => b.date.compareTo(a.date));
      _filtered = List.from(_articles);
    } else {
      _error = 'Failed to fetch news';
    }
  } catch (e) {
    _error = 'Error fetching news: $e';
  } finally {
    setState(() => _isLoading = false);
  }
}


// _showFullStory in news_feed_screen.dart
Future<void> _showFullStory(Article article) async {
  String textContent = article.story.isNotEmpty ? article.story : article.excerpt;
  String summary = '';
  bool isError = false;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setStateDialog) {
        Future<void> summarizeNow() async {
          try {
            setStateDialog(() => _isSummarizing = true);
            final backendUrl ="http://10.210.189.93:8000/summarize";

            final resp = await http.post(
              Uri.parse(backendUrl),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({'text': textContent}),
            );

            debugPrint('Response status: ${resp.statusCode}');
            debugPrint('Response body: ${resp.body}');

            if (resp.statusCode == 200) {
              final data = json.decode(resp.body);
              summary = data['summary'] ?? 'No summary generated.';
            } else {
              summary = '❌ Failed to summarize (Status: ${resp.statusCode})';
              isError = true;
            }
          } catch (e) {
            summary = '⚠️ Error: $e';
            debugPrint('Error fetching summary: $e');
            isError = true;
          } finally {
            setStateDialog(() => _isSummarizing = false);
          }
        }

        // Run summarization once dialog is opened
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isSummarizing && summary.isEmpty) summarizeNow();
        });

        return AlertDialog(
          title: Text(article.title),
          content: SingleChildScrollView(
            child: _isSummarizing
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : Text(
                    summary.isNotEmpty
                        ? summary
                        : isError
                            ? 'Failed to summarize.'
                            : 'No content.',
                    style: const TextStyle(fontSize: 14),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    ),
  );
}

  Widget _buildTopSearchRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      child: Row(
        children: [
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color:
                      isSelected ? const Color(0xFFEDECF0) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    tabs[idx],
                    style: TextStyle(
                      color: isSelected ? Colors.black87 : Colors.black54,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
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
            Text(a.title,
                style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(dateFormatted,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            if (a.excerpt.isNotEmpty)
              Text(
                a.excerpt,
                style: TextStyle(
                    fontSize: 14, color: Colors.grey.shade800, height: 1.35),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 10),
            Row(
              children: [
              SizedBox(
  width: 100,
  child: Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () => _showFullStory(a),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF05151).withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            "READ MORE",
            style: TextStyle(
              color: const Color(0xFFF05151),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(t,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.black54)),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeed() {
    if (_isLoading) {
      return const Expanded(
          child: Center(child: CircularProgressIndicator()));
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
          child: Center(child: Text('No articles found')));
    }

    return Expanded(
      child: RefreshIndicator(
        onRefresh: _fetchNews,
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 10, bottom: 90),
          itemCount: _filtered.length,
          itemBuilder: (context, index) =>
              _buildArticleCard(_filtered[index]),
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
*/