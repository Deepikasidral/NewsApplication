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
import 'package:flutter_html/flutter_html.dart';



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




  final String baseUrl = "http://13.51.242.86:5000";

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
  Color sentimentColor(String s) {
    switch (s.toLowerCase()) {
      case "bullish":
        return Colors.green;
      case "bearish":
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Color impactColor(String i) {
    switch (i.toLowerCase()) {
      case "very high":
        return Colors.red;
      case "high":
        return Colors.orange;
      case "medium":
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      backgroundColor:Color.fromARGB(255, 245, 237, 237),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// TITLE
            Text(
              a.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            /// FULL STORY
              if (a.story.isNotEmpty) ...[
                const Text(
                  "Full Story",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),

                Html(
                  data: a.story, // 👈 COMPLETE NEWS CONTENT
                  style: {
                    "p": Style(
                      fontSize: FontSize(14.5),
                      lineHeight: LineHeight.number(1.5),
                      margin: Margins.only(bottom: 12),
                    ),
                  },
                ),

                const SizedBox(height: 16),
              ],


            /// SENTIMENT + IMPACT (same as card)
            
                if (a.sentiment.isNotEmpty)
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: "Sentiment: ",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        TextSpan(
                          text: a.sentiment,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: sentimentColor(a.sentiment),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 12),
                if (a.impact.isNotEmpty)
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: "Impact: ",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        TextSpan(
                          text: a.impact,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: impactColor(a.impact),
                          ),
                        ),
                      ],
                    ),
                  ),
             

            /// COMPANIES
            if (a.companies.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                "Companies",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: a.companies.map(
                  (company) => Chip(
                    label: Text(
                      company,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                    backgroundColor: const Color(0xFFEA6B6B),
                  ),
                ).toList(),
              ),
            ],

            const SizedBox(height: 20),

            /// CLOSE BUTTON
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  "Close",
                  style: TextStyle(
                    color: Color(0xFFEA6B6B),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
 


  Color sentimentColor(String s) {
    switch (s.toLowerCase()) {
      case "bullish":
        return Colors.green;
      case "bearish":
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Color impactColor(String i) {
    switch (i.toLowerCase()) {
      case "very high":
        return Colors.red;
      case "high":
        return Colors.orange;
      case "medium":
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
return Padding(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  child: InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: () => _showFullStory(a), // 👈 TAP OPENS DIALOG
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// TITLE + BOOKMARK
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  a.title,
                  style: const TextStyle(
                    fontSize: 16,
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

          /// SUMMARY (2–3 lines)
          Text(
  a.summary,
  softWrap: true,
  style: const TextStyle(
    fontSize: 14.5,
    height: 1.4,
  ),
),




          const SizedBox(height: 10),

          /// COMPANIES
          if (a.companies.isNotEmpty)
            Text(
              "Companies: ${a.companies.join(', ')}",
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),

          const SizedBox(height: 6),

          /// SENTIMENT + IMPACT
          
            
                 if (a.sentiment.isNotEmpty)
      Text.rich(
        TextSpan(
          children: [
            const TextSpan(
              text: "Sentiment: ",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            TextSpan(
              text: a.sentiment,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: sentimentColor(a.sentiment),
              ),
            ),
          ],
        ),
      ),

    const SizedBox(width: 12),

    if (a.impact.isNotEmpty)
      Text.rich(
        TextSpan(
          children: [
            const TextSpan(
              text: "Impact: ",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            TextSpan(
              text: a.impact,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: impactColor(a.impact),
              ),
            ),
          ],
        ),
      ),
          

          const SizedBox(height: 6),

          /// FOOTER
          Text(
            dateFormatted,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    ),
));
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
    BottomNavigationBarItem(icon: Icon(Icons.newspaper), label: "NEWS"),
    BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: "INDEX"),
    BottomNavigationBarItem(icon: Icon(Icons.smart_toy), label: "ASK AI"),
    BottomNavigationBarItem(icon: Icon(Icons.business), label: "COMPANIES"),
    BottomNavigationBarItem(icon: Icon(Icons.event_available), label: "EVENTS"),
    BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: "Saved"),
  ],
),

    );
  }
}
