import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:news_application/screens/saved_screen.dart';
import 'package:news_application/screens/profile_screen.dart';

import 'chatbot_screen.dart';
import '../models/article.dart';
import 'company_screen.dart';
import 'events_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';



class NewsFeedScreen extends StatefulWidget {
  final String? openFileName;

  const NewsFeedScreen({super.key, this.openFileName});


  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends State<NewsFeedScreen> 
with WidgetsBindingObserver{
  final TextEditingController _searchController = TextEditingController();

  List<Article> _articles = [];
  List<Article> _filtered = [];
  bool _isLoading = false;
  String _error = '';
  int _bottomIndex = 0;
  int _tabIndex = 0;
 Set<String> _locallySavedIds = {};
late String currentUserId;
bool _hasLoadedOnce = false;


final String baseUrl = "http://13.51.242.86:5000";

 @override
void initState() {
  super.initState();
  WidgetsBinding.instance.addObserver(this);
  _bottomIndex = 0; 
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
  WidgetsBinding.instance.removeObserver(this);
  _searchController.removeListener(_applySearch);
  _searchController.dispose();
  super.dispose();
}
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed && _hasLoadedOnce) {
    switch (_tabIndex) {
      case 0:
        _fetchLatestNews(soft: true);
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
}
List<Article> _removeDuplicates(List<Article> list) {
  final map = <String, Article>{};
  for (var a in list) {
    map[a.id] = a; // _id should be unique
  }
  return map.values.toList();
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
  Future<void> _fetchLatestNews({bool soft = false}) async {
  _startLoading(soft: soft);

    try {
      final resp = await http.get(Uri.parse("$baseUrl/api/news"));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        _articles = _removeDuplicates(
  (data as List).map((e) => Article.fromJson(e)).toList(),
);
        _articles.sort((a, b) => b.date.compareTo(a.date));
        _filtered = List.from(_articles);
        
      } else {
        _error = "Failed to load latest news";
      }
    } catch (e) {
      _error = "Error: $e";
    }
_stopLoading();
_hasLoadedOnce = true;

  }

  Future<List<Map<String, dynamic>>> _fetchCompanyDetails(
    List<String> companyNames) async {

  final names = companyNames.join(",");
  final url =
      "$baseUrl/api/company-lookup/by-names?names=$names";

  debugPrint("TradingView API URL: $url");

  final resp = await http.get(Uri.parse(url));

  debugPrint("TradingView API status: ${resp.statusCode}");
  debugPrint("TradingView API body: ${resp.body}");

  if (resp.statusCode != 200) {
    throw Exception("Failed to fetch company details");
  }

  final body = jsonDecode(resp.body);
  return List<Map<String, dynamic>>.from(body["data"]);
}

Future<void> _openTradingView(String exchange, String symbol) async {
  final url =
      "https://www.tradingview.com/chart/?symbol=$exchange:$symbol";

  final uri = Uri.parse(url);

  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    await launchUrl(uri, mode: LaunchMode.inAppWebView);
  }
}

void _showCompanySelector(List<Map<String, dynamic>> companies) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            "View chart on TradingView",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        ...companies.map(
          (c) => ListTile(
            title: Text(c["name"]),
           subtitle: Text("${c["exchange"]}:${c["symbol"]}"),
          onTap: () {
            Navigator.pop(context);
            _openTradingView(
              c["exchange"],
              c["symbol"],
            );
          },
          ),
        ),
      ],
    ),
  );
}

  // ------------------------- FETCH TRENDING -------------------------
  Future<void> _fetchTrendingNews() async {
    _startLoading();

    try {
      final resp =
          await http.get(Uri.parse("$baseUrl/api/trending-news"));

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body);
       _articles = _removeDuplicates(
            (body['data'] as List).map((e) => Article.fromJson(e)).toList(),
          );

        
        _sortByLatest();
      } else {
        _error = "Failed to load trending news";
      }
    } catch (e) {
      _error = "Error: $e";
    }
    _hasLoadedOnce = true;


    _stopLoading();
  }

  void _startLoading({bool soft = false}) {
  setState(() {
    if (!soft) {
      _isLoading = true;
      _articles = [];
      _filtered = [];
    }
    _error = '';
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
      _articles = _removeDuplicates(
  (body['data'] as List).map((e) => Article.fromJson(e)).toList(),
);
      
      _sortByLatest();
    } else {
      _error = "Failed to load global news";
    }
  } catch (e) {
    _error = "Error: $e";
  }
  _hasLoadedOnce = true;

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
      _articles = _removeDuplicates(
  (body['data'] as List).map((e) => Article.fromJson(e)).toList(),
);

      
      _sortByLatest();
    } else {
      _error = "Failed to load commodities news";
    }
  } catch (e) {
    _error = "Error: $e";
  }
  _hasLoadedOnce = true;

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
void _sortByLatest() {
  _articles.sort((a, b) => b.date.compareTo(a.date));
  _filtered = List.from(_articles);
}


  // ------------------------- SHOW FULL STORY -------------------------
 Future<void> _showFullStory(Article a) async {
  Color sentimentColor(String s) {
    switch (s.toLowerCase()) {
      case "very bullish":
        return const Color(0xFF0F9D58);
      case "bullish":
        return const Color(0xFF5AD079);
      case "neutral":
        return const Color(0xFFA6A49A);
      case "bearish":
        return const Color(0xFFEB6969);
      case "very bearish":
        return const Color(0xFFD93025);
      default:
        return Colors.grey;
    }
  }

  Color impactColor(String i) {
    switch (i.toLowerCase()) {
      case "very high":
        return const Color(0xFFFFB000);
      case "high":
        return const Color(0xFFFF9B5B);
      case "mild":
        return const Color(0xFFFFCD79);
      case "negligible":
        return const Color(0xFFFFCEAF);
      default:
        return Colors.grey;
    }
  }

  showDialog(
  context: context,
  barrierDismissible: true,
  builder: (ctx) => Dialog(
    backgroundColor: Colors.white, // ✅ WHITE BACKGROUND
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// ---------------- TITLE ----------------
          Text(
            a.title,
            style: GoogleFonts.poppins(
              fontSize: 16,           // ✅ SAME AS CARD TITLE
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),

          const SizedBox(height: 12),

          /// ---------------- FULL STORY ----------------
          if (a.story.isNotEmpty) ...[
            Html(
              data: a.story,
              style: {
                "p": Style(
                  fontFamily: GoogleFonts.poppins().fontFamily,
                  fontSize: FontSize(14.5), // ✅ SAME AS CARD SUMMARY
                  lineHeight: LineHeight.number(1.4),
                  color: Colors.black87,
                  margin: Margins.only(bottom: 12),
                ),
              },
            ),
            const SizedBox(height: 8),
          ],

          /// ---------------- SENTIMENT ----------------
          if (a.sentiment.isNotEmpty)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: "Sentiment: ",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  TextSpan(
                    text: a.sentiment,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: sentimentColor(a.sentiment),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 6),

          /// ---------------- IMPACT ----------------
          if (a.impact.isNotEmpty)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: "Impact: ",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  TextSpan(
                    text: a.impact,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: impactColor(a.impact),
                    ),
                  ),
                ],
              ),
            ),

          /// ---------------- COMPANIES ----------------
          if (a.companies.isNotEmpty) ...[
            const SizedBox(height: 14),

            Text(
              "Companies",
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),

            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: a.companies.map(
                (company) => Chip(
                  backgroundColor: const Color(0xFFEA6B6B),
                  label: Text(
                    company,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ).toList(),
            ),
          ],

          const SizedBox(height: 18),

          /// ---------------- CLOSE BUTTON ----------------
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                "Close",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFEA6B6B),
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
         GestureDetector(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  },
  child: CircleAvatar(
  radius: 18,
  backgroundColor: Color(0xFFE0E0E0),
  child: Icon(
    Icons.person,
    size: 18,
    color: Color(0xFF757575),
  ),
),
),

        ],
      ),
    );
  }

Widget _buildTabsRow() {
  final tabs = ["LATEST", "TRENDING", "GLOBAL", "COMMODITIES"];

  return Container(
    color: Colors.white,
    child: Column(
      children: [
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: tabs.length,
            itemBuilder: (context, idx) {
              final selected = idx == _tabIndex;

              return GestureDetector(
                onTap: () => _onTabChange(idx),
                child: Padding(
                  padding: const EdgeInsets.only(right: 22),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tabs[idx],
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
                          color: selected
                              ? const Color(0xFFEA6B6B)
                              : Colors.black54,
                        ),
                      ),

                      const SizedBox(height: 4),

                      /// ✅ underline EXACTLY same width as text
                      Container(
                        height: 2,
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFFEA6B6B)
                              : Colors.transparent,
                        ),
                        width: _textWidth(
                          tabs[idx],
                          GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const Divider(height: 1, thickness: 0.8),
      ],
    ),
  );
}


double _textWidth(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    textDirection: Directionality.of(context), // ✅ FIX
  )..layout();

  return painter.size.width;
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
  child: RefreshIndicator(
    onRefresh: () {
  switch (_tabIndex) {
    case 0:
      return _fetchLatestNews();
    case 1:
      return _fetchTrendingNews();
    case 2:
      return _fetchGlobalNews();
    case 3:
      return _fetchCommoditiesNews();
    default:
      return _fetchLatestNews();
  }
},

    child: ListView.builder(
      itemCount: _filtered.length,
      padding: const EdgeInsets.only(bottom: 80),
      itemBuilder: (_, i) => _buildArticleCard(_filtered[i]),
    ),
  ),
);

  }
Widget _buildArticleCard(Article a) {
  final dateFormatted = DateFormat.yMMMd().add_jm().format(a.date);

  Color sentimentColor(String s) {
    switch (s.toLowerCase()) {
      case "very bullish":
        return const Color(0xFF0F9D58);
      case "bullish":
        return const Color(0xFF5AD079);
      case "neutral":
        return const Color(0xFFA6A49A);
      case "bearish":
        return const Color(0xFFEB6969);
      case "very bearish":
        return const Color(0xFFD93025);
      default:
        return Colors.grey;
    }
  }

  Color impactColor(String i) {
    switch (i.toLowerCase()) {
      case "very high":
        return const Color(0xFFFFB000);
      case "high":
        return const Color(0xFFFF9B5B);
      case "mild":
        return const Color(0xFFFFCD79);
      case "negligible":
        return const Color(0xFFFFCEAF);
      default:
        return Colors.grey;
    }
  }

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showFullStory(a),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
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

            /// ---------------- TITLE ----------------
            Text(
              a.title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 8),

            /// ---------------- SUMMARY ----------------
            Text(
              a.summary,
              softWrap: true,
              style: GoogleFonts.poppins(
                fontSize: 14.5,
                height: 1.4,
                fontWeight: FontWeight.w400,
              ),
            ),

            const SizedBox(height: 12),

            /// ---------------- COMPANIES ----------------
            if (a.companies.isNotEmpty)
              Text(
                "Companies: ${a.companies.join(', ')}",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),

            const SizedBox(height: 8),

            /// ---------------- SENTIMENT ----------------
            if (a.sentiment.isNotEmpty)
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: "Sentiment: ",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    TextSpan(
                      text: a.sentiment,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: sentimentColor(a.sentiment),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 0),

            /// ---------------- IMPACT ----------------
            if (a.impact.isNotEmpty)
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: "Impact: ",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    TextSpan(
                      text: a.impact,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: impactColor(a.impact),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 0),

            /// ---------------- FOOTER ----------------
           /// ---------------- FOOTER ----------------
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [

    /// DATE
    Text(
      dateFormatted,
      style: GoogleFonts.poppins(
        fontSize: 11,
        color: Colors.grey,
      ),
    ),

    /// ACTIONS
    Row(
      children: [

        /// 📈 TradingView
        if (a.companies.isNotEmpty)
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Image.asset(
              "assets/tradingview.png",
              height: 36, // ⬆ increased
              width: 36,
            ),
            tooltip: "View chart on TradingView",
            onPressed: () async {
              try {
                final companies =
                    await _fetchCompanyDetails(a.companies);

                if (companies.isEmpty) return;

                if (companies.length == 1) {
                _openTradingView(
                  companies.first["exchange"],
                  companies.first["symbol"],
                );
              }
              else {
                  _showCompanySelector(companies);
                }
              } catch (e) {
                debugPrint("TradingView error: $e");
              }
            },
          ),

        const SizedBox(width: 0),

        /// 🔖 SAVE
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(
            _locallySavedIds.contains(a.id)
                ? Icons.bookmark
                : Icons.bookmark_border,
            size: 36, // ⬆ increased
            color: _locallySavedIds.contains(a.id)
                ? Colors.red
                : Colors.grey,
          ),
          onPressed: () => _toggleSaveNews(a.id),
        ),
      ],
    ),
  ],
),

          ],
        ),
      ),
    ),
  );
}

BottomNavigationBarItem _navItem({
  required String label,
  required String active,
  required String inactive,
  required int index,
}) {
  final bool selected = _bottomIndex == index;

  return BottomNavigationBarItem(
    icon: SvgPicture.asset(
      selected ? active : inactive,
      height: 22,
    ),
    label: label,
    tooltip: label,
  );
}




  // ------------------------- BUILD -------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
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
     bottomNavigationBar: Container(
  decoration: const BoxDecoration(
    color: Colors.white,
    border: Border(
      top: BorderSide(color: Color(0xFFE0E0E0), width: 0.8),
    ),
  ),
  child: BottomNavigationBar(
  currentIndex: _bottomIndex,
  type: BottomNavigationBarType.fixed,
  backgroundColor: Colors.white,
  elevation: 0,

  // 🔥 THIS FIXES BLUE TEXT
  selectedItemColor: const Color(0xFFEA6B6B),
  unselectedItemColor: Colors.black54,

  showUnselectedLabels: true,

  selectedLabelStyle: GoogleFonts.poppins(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.2,
  ),
  unselectedLabelStyle: GoogleFonts.poppins(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.2,
  ),
 onTap: (index) {
  if (index == _bottomIndex) return;

  Widget? destination;

  switch (index) {
    case 0:
      // NEWS (current screen)
      return;

    case 1:
      destination = const ChatbotScreen();
      break;

    case 2:
      destination = const CompanyScreen();
      break;

    case 3:
      destination = const EventsScreen();
      break;

    case 4:
      destination = const SavedNewsFeedScreen();
      break;

    default:
      return;
  }

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => destination!),
  );
},


  items: [
    _navItem(
      label: "NEWS",
      active: 'assets/icons/News Red.svg',
      inactive: 'assets/icons/News.svg',
      index: 0,
    ),
    _navItem(
      label: "ASK AI",
      active: 'assets/icons/Ask AI Red.svg',
      inactive: 'assets/icons/Ask AI.svg',
      index: 1,
    ),
    _navItem(
      label: "COMPANIES",
      active: 'assets/icons/Graph Red.svg',
      inactive: 'assets/icons/Graph.svg',
      index: 2,
    ),
    _navItem(
      label: "EVENTS",
      active: 'assets/icons/Calender Red.svg',
      inactive: 'assets/icons/Calender.svg',
      index: 3,
    ),
    _navItem(
      label: "SAVED",
      active: 'assets/icons/Save red.svg',
      inactive: 'assets/icons/Save.svg',
      index: 4,
    ),
  ],
),

),


    );
  }
}