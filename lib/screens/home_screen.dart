// lib/screens/news_feed_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:html/parser.dart' show parse;
import 'chatbot_screen.dart';
import '../models/article.dart';
import 'company_screen.dart';
import 'events_screen.dart';

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
          await http.get(Uri.parse("http://10.69.144.93:5000/api/news"));

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
            // -------- SUMMARY --------
            if (a.summary.isNotEmpty) ...[
              const Text(
                "📝 Summary",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(a.summary),
              const SizedBox(height: 16),
            ],

            // -------- META INFO --------
            if (a.tone.isNotEmpty)
              Text("🎭 Tone: ${a.tone}",
                  style: const TextStyle(fontSize: 13)),
            if (a.sentiment.isNotEmpty)
              Text("💬 Sentiment: ${a.sentiment}",
                  style: const TextStyle(fontSize: 13)),
            if (a.impact.isNotEmpty)
              Text("🔥 Impact: ${a.impact}",
                  style: const TextStyle(fontSize: 13)),

            // -------- COMPANIES --------
            if (a.companies.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                "🏢 Companies",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: a.companies
                    .map(
                      (company) => Chip(
                        label: Text(
                          company,
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: Colors.blue.shade50,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text("Close"),
        ),
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
    final tabs = ["LATEST", "TRENDING","GLOBAL","EVENTS","COMMODITIES"];

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
  type: BottomNavigationBarType.fixed,
  selectedItemColor: const Color(0xFFEA6B6B),
  unselectedItemColor: Colors.black54,
  onTap: (index) {
    setState(() => _bottomIndex = index);

    // 👉 ASK AI TAB
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ChatbotScreen(),
        ),
      );
    }
    if(index==3)
    {
      Navigator.push(context,
       MaterialPageRoute(
        builder: (_)=> const CompanyScreen(),
        ));
    }
     if(index==4)
    {
      Navigator.push(context,
       MaterialPageRoute(
        builder: (_)=> const EventsScreen(),
        ));
    }
  },
  items: const [
    BottomNavigationBarItem(icon: Icon(Icons.feed), label: "NEWS"),
    BottomNavigationBarItem(icon: Icon(Icons.local_fire_department), label: "INDEX"),
    BottomNavigationBarItem(icon: Icon(Icons.currency_bitcoin), label: "ASK AI"),
    BottomNavigationBarItem(icon: Icon(Icons.event), label: "COMPANIES"),
    BottomNavigationBarItem(icon: Icon(Icons.event), label: "EVENTS"),
    BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: "Saved"),
  ],
),

    );
  }
}
