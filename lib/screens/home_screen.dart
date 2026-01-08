import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:news_application/screens/saved_screen.dart';
import 'chatbot_screen.dart';
import '../models/article.dart';
import 'company_screen.dart';
import 'events_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';


class NewsFeedScreen extends StatefulWidget {
  final String? openFileName;

  const NewsFeedScreen({super.key, this.openFileName});


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
 Set<String> _locallySavedIds = {};
late String currentUserId;




  final String baseUrl = "http://10.244.218.93:5000";

 @override
void initState() {
  super.initState();
  _searchController.addListener(_applySearch);

  _init();
}

Future<void> _init() async {
  await _loadUserId();
  await _fetchLatestNews();
  await _loadSavedNewsIds();
}


  @override
  void dispose() {
    _searchController.removeListener(_applySearch);
    _searchController.dispose();
    super.dispose();
  }

  // ------------------------- SEARCH -------------------------
  Future<void> _loadUserId() async {
  final prefs = await SharedPreferences.getInstance();
  currentUserId = prefs.getString("userId") ?? "";
}

  void _applySearch() {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filtered = List.from(_articles));
      return;
    }

    setState(() {
      _filtered = _articles.where((a) {
        final hay =
            '${a.title} ${a.excerpt} ${a.tags.join(' ')}'.toLowerCase();
        return hay.contains(q);
      }).toList();
    });
  }

  // ------------------------- FETCH LATEST -------------------------
  Future<void> _fetchLatestNews() async {
    _startLoading();

    try {
      final resp = await http.get(Uri.parse("$baseUrl/api/news"));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        _articles = (data as List).map((e) => Article.fromJson(e)).toList();
        _articles.sort((a, b) => b.date.compareTo(a.date));
        _filtered = List.from(_articles);
      } else {
        _error = "Failed to load latest news";
      }
    } catch (e) {
      _error = "Error: $e";
    }

    _stopLoading();
  }

  // ------------------------- FETCH TRENDING -------------------------
  Future<void> _fetchTrendingNews() async {
    _startLoading();

    try {
      final resp =
          await http.get(Uri.parse("$baseUrl/api/trending-news"));

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body);
        _articles = (body['data'] as List)
            .map((e) => Article.fromJson(e))
            .toList();

        _filtered = List.from(_articles);
      } else {
        _error = "Failed to load trending news";
      }
    } catch (e) {
      _error = "Error: $e";
    }

    _stopLoading();
  }

  void _startLoading() {
    setState(() {
      _isLoading = true;
      _error = '';
      _articles = [];
      _filtered = [];
    });
  }

  void _stopLoading() {
    setState(() => _isLoading = false);
  }
  // ------------------------- FETCH GLOBAL -------------------------
Future<void> _fetchGlobalNews() async {
  _startLoading();

  try {
    final resp =
        await http.get(Uri.parse("$baseUrl/api/global-news"));

    if (resp.statusCode == 200) {
      final body = json.decode(resp.body);
      _articles = (body['data'] as List)
          .map((e) => Article.fromJson(e))
          .toList();

      _filtered = List.from(_articles);
    } else {
      _error = "Failed to load global news";
    }
  } catch (e) {
    _error = "Error: $e";
  }

  _stopLoading();
}

// ------------------------- FETCH COMMODITIES -------------------------
Future<void> _fetchCommoditiesNews() async {
  _startLoading();

  try {
    final resp =
        await http.get(Uri.parse("$baseUrl/api/commodities-news"));

    if (resp.statusCode == 200) {
      final body = json.decode(resp.body);
      _articles = (body['data'] as List)
          .map((e) => Article.fromJson(e))
          .toList();

      _filtered = List.from(_articles);
    } else {
      _error = "Failed to load commodities news";
    }
  } catch (e) {
    _error = "Error: $e";
  }

  _stopLoading();
}

Future<void> _loadSavedNewsIds() async {
  if (currentUserId.isEmpty) return;

  try {
    final resp = await http.get(
      Uri.parse("$baseUrl/api/users/$currentUserId/saved-news"),
    );

    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body);
      final List saved = body["data"];

      setState(() {
        _locallySavedIds =
            saved.map((e) => e["_id"].toString()).toSet();
      });
    }
  } catch (e) {
    debugPrint("Failed to load saved ids: $e");
  }
}


Future<void> _toggleSaveNews(String newsId) async {
  final bool wasSaved = _locallySavedIds.contains(newsId);

  // 1️⃣ Optimistic UI update
  setState(() {
    if (wasSaved) {
      _locallySavedIds.remove(newsId);
    } else {
      _locallySavedIds.add(newsId);
    }
  });

  // 2️⃣ Call backend
  try {
    final resp = await http.post(
      Uri.parse("$baseUrl/api/users/save-news"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "userId": currentUserId,
        "newsId": newsId,
      }),
    );

    if (resp.statusCode != 200) {
      throw Exception("API failed");
    }
  } catch (e) {
    // 🔁 ROLLBACK UI if backend fails
    setState(() {
      if (wasSaved) {
        _locallySavedIds.add(newsId);
      } else {
        _locallySavedIds.remove(newsId);
      }
    });

    debugPrint("Save toggle failed: $e");
  }
}



  // ------------------------- TAB HANDLER -------------------------
  void _onTabChange(int idx) {
  setState(() => _tabIndex = idx);

  switch (idx) {
    case 0:
      _fetchLatestNews();
      break;
    case 1:
      _fetchTrendingNews();
      break;
    case 2:
      _fetchGlobalNews();
      break;
    case 3:
      _fetchCommoditiesNews();
      break;
  }
}

  // ------------------------- SHOW FULL STORY -------------------------
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
            if (a.sentiment.isNotEmpty)
              Text("💬 Sentiment: ${a.sentiment}",
                  style: const TextStyle(fontSize: 13)),
            if (a.impact.isNotEmpty)
              Text("🔥 Impact: ${a.impact}",
                  style: const TextStyle(fontSize: 13)),

            // -------- COMPANIES --------
            if (a.companies.isNotEmpty) ...[
              const SizedBox(height: 14),
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


  // ------------------------- UI -------------------------
  Widget _buildTopSearchRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  const Icon(Icons.search),
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
    final tabs = ["LATEST", "TRENDING", "GLOBAL", "COMMODITIES"];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        height: 46,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: tabs.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, idx) {
            final selected = idx == _tabIndex;
            return GestureDetector(
              onTap: () => _onTabChange(idx),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color:
                      selected ? const Color(0xFFEDECF0) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tabs[idx],
                  style: TextStyle(
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          },
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
      return Expanded(child: Center(child: Text(_error)));
    }

    if (_filtered.isEmpty) {
      return const Expanded(child: Center(child: Text("No articles found")));
    }

    return Expanded(
      child: ListView.builder(
        itemCount: _filtered.length,
        padding: const EdgeInsets.only(bottom: 80),
        itemBuilder: (_, i) => _buildArticleCard(_filtered[i]),
      ),
    );
  }

  Widget _buildArticleCard(Article a) {
    final dateFormatted = DateFormat.yMMMd().add_jm().format(a.date);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                        Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    a.title,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _locallySavedIds.contains(a.id)
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                    color: _locallySavedIds.contains(a.id)
                        ? Colors.red
                        : Colors.grey,
                  ),
                  onPressed: () => _toggleSaveNews(a.id),
                ),
              ],
            ),

            const SizedBox(height: 6),
            Text(dateFormatted,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Text(a.excerpt,
                maxLines: 4, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
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
                      fontWeight: FontWeight.bold),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // ------------------------- BUILD -------------------------
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
  if (index == _bottomIndex) return;

  setState(() => _bottomIndex = index);

  switch (index) {
    case 2:
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const ChatbotScreen()));
      break;
    case 3:
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const CompanyScreen()));
      break;
    case 4:
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const EventsScreen()));
      break;
    case 5:
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const SavedNewsFeedScreen()));
      break;
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
