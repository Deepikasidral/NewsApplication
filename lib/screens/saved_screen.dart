import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:news_application/screens/home_screen.dart';
import 'chatbot_screen.dart';
import '../models/article.dart';
import 'company_screen.dart';
import 'events_screen.dart';
import 'profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class SavedNewsFeedScreen extends StatefulWidget {
  final String? openFileName;

  const SavedNewsFeedScreen({super.key, this.openFileName});


  @override
  State<SavedNewsFeedScreen> createState() => _SavedNewsFeedScreenState();
}

class _SavedNewsFeedScreenState extends State<SavedNewsFeedScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Article> _articles = [];
  List<Article> _filtered = [];
  List<CorporateEvent> _savedEvents = [];
  List<CorporateEvent> _filteredEvents = [];

  bool _isLoading = false;
  String _error = '';
  int _bottomIndex = 5;
  int _tabIndex = 0;
  late String currentUserId;

  Future<List<Map<String, dynamic>>> _fetchCompanyDetails(
    List<String> companyNames) async {
  final names = companyNames.join(",");
  final url = "$baseUrl/api/company-lookup/by-names?names=$names";
  final resp = await http.get(Uri.parse(url));
  if (resp.statusCode != 200) throw Exception("Failed to fetch company details");
  final body = jsonDecode(resp.body);
  return List<Map<String, dynamic>>.from(body["data"]);
}

Future<void> _openTradingView(String symbol) async {
  final url = "https://www.tradingview.com/chart/?symbol=NSE:$symbol";
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
            subtitle: Text("NSE:${c["symbol"]}"),
            onTap: () {
              Navigator.pop(context);
              _openTradingView(c["symbol"]);
            },
          ),
        ),
      ],
    ),
  );
}



   //final String baseUrl = "http://10.244.218.93:5000";
  final String baseUrl = "http://13.51.242.86:5000";

 @override
void initState() {
  super.initState();
  _searchController.addListener(_applySearch);

  _loadUserId().then((_) {
    if (currentUserId.isNotEmpty) {
      _fetchSavedNews();
    }
  });
}



  @override
  void dispose() {
    _searchController.removeListener(_applySearch);
    _searchController.dispose();
    super.dispose();
  }

Future<void> _loadUserId() async {
  final prefs = await SharedPreferences.getInstance();
  currentUserId = prefs.getString("userId") ?? "";
}

  // ------------------------- SEARCH -------------------------
 void _applySearch() {
  final q = _searchController.text.trim().toLowerCase();

  if (_tabIndex == 0) {
    if (q.isEmpty) {
      setState(() => _filtered = List.from(_articles));
      return;
    }

    setState(() {
      _filtered = _articles.where((a) {
        return '${a.title} ${a.excerpt}'.toLowerCase().contains(q);
      }).toList();
    });
  } else {
    if (q.isEmpty) {
      setState(() => _filteredEvents = List.from(_savedEvents));
      return;
    }

    setState(() {
      _filteredEvents = _savedEvents.where((e) {
        return '${e.title} ${e.description}'.toLowerCase().contains(q);
      }).toList();
    });
  }
}



  Future<void> _fetchSavedNews() async {
  setState(() {
    _isLoading = true;
    _error = "";
  });

  try {
    final resp = await http.get(
      Uri.parse("$baseUrl/api/users/$currentUserId/saved-news"),
    );

    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body);
      final List data = body['data'];

      _articles = data.map((e) => Article.fromJson(e)).toList();
      _filtered = List.from(_articles);
    } else {
      _error = "Failed to load saved news";
    }
  } catch (e) {
    _error = "Error: $e";
  }

  setState(() => _isLoading = false);
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
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        TextSpan(
                          text: a.sentiment,
                          style: TextStyle(
                            fontSize: 16,
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
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        TextSpan(
                          text: a.impact,
                          style: TextStyle(
                            fontSize: 16,
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


Future<void> _fetchSavedEvents() async {
  setState(() {
    _isLoading = true;
    _error = "";
  });

  try {
    final resp = await http.get(
      Uri.parse("$baseUrl/api/users/$currentUserId/saved-events"),
    );

    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body);
      final List data = body['data'];

      _savedEvents =
          data.map((e) => CorporateEvent.fromJson(e)).toList();

      _filteredEvents = List.from(_savedEvents);
    } else {
      _error = "Failed to load saved events";
    }
  } catch (e) {
    _error = "Error: $e";
  }

  setState(() => _isLoading = false);
}
Future<void> _removeAllSavedNews() async {
  final resp = await http.delete(
    Uri.parse("$baseUrl/api/users/$currentUserId/saved-news"),
  );

  if (resp.statusCode == 200) {
    setState(() {
      _articles.clear();
      _filtered.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("All saved news removed")),
    );
  }
}
Future<void> _removeAllSavedEvents() async {
  final resp = await http.delete(
    Uri.parse("$baseUrl/api/users/$currentUserId/saved-events"),
  );

  if (resp.statusCode == 200) {
    setState(() {
      _savedEvents.clear();
      _filteredEvents.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("All saved events removed")),
    );
  }
}
Future<void> _unsaveNews(String newsId) async {
  await http.post(
    Uri.parse("$baseUrl/api/users/save-news"),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "userId": currentUserId,
      "newsId": newsId,
    }),
  );

  setState(() {
    _articles.removeWhere((n) => n.id == newsId);
    _filtered.removeWhere((n) => n.id == newsId);
  });
}
Future<void> _unsaveEvent(String eventId) async {
  await http.post(
    Uri.parse("$baseUrl/api/users/save-event"),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "userId": currentUserId,
      "eventId": eventId,
    }),
  );

  setState(() {
    _savedEvents.removeWhere((e) => e.id == eventId);
    _filteredEvents.removeWhere((e) => e.id == eventId);
  });
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
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
            child: const CircleAvatar(
              radius: 22,
              backgroundImage: NetworkImage('https://i.pravatar.cc/300'),
            ),
          ),
        ],
      ),
    );
  }

 Widget _buildTabsRow() {
  final tabs = ["NEWS", "EVENTS"];

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
            onTap: () {
              setState(() => _tabIndex = idx);

              if (idx == 0) {
                _fetchSavedNews();
              } else {
                _fetchSavedEvents();
              }
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFEDECF0)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tabs[idx],
                style: TextStyle(
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
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
Widget _buildRemoveAllButton() {
  if (_tabIndex == 0 && _articles.isEmpty) return const SizedBox();
  if (_tabIndex == 1 && _savedEvents.isEmpty) return const SizedBox();

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        label: Text(
          _tabIndex == 0
              ? "Remove all saved news"
              : "Remove all saved events",
          style: const TextStyle(color: Colors.red),
        ),
        onPressed: _tabIndex == 0
            ? _removeAllSavedNews
            : _removeAllSavedEvents,
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

  // 📰 SAVED NEWS
  if (_tabIndex == 0) {
    if (_filtered.isEmpty) {
      return const Expanded(child: Center(child: Text("No saved news")));
    }

    return Expanded(
      child: ListView.builder(
        itemCount: _filtered.length,
        itemBuilder: (_, i) => _buildArticleCard(_filtered[i]),
      ),
    );
  }

  // 📅 SAVED EVENTS
  if (_filteredEvents.isEmpty) {
    return const Expanded(child: Center(child: Text("No saved events")));
  }

  return Expanded(
    child: ListView.builder(
      itemCount: _filteredEvents.length,
      itemBuilder: (_, i) => _buildSavedEventCard(_filteredEvents[i]),
    ),
  );
}
Widget _buildSavedEventCard(CorporateEvent event) {
  final dateFormatted = DateFormat('MMM dd, yyyy').format(event.date);
  final timeFormatted = DateFormat('hh:mm a').format(event.date);

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
  children: [
    Expanded(
      child: Text(
        event.title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    IconButton(
      icon: const Icon(Icons.bookmark, color: Colors.red),
      onPressed: () => _unsaveEvent(event.id),
    ),
  ],
),

          const SizedBox(height: 6),
          Text(
            "$dateFormatted • $timeFormatted",
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            event.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );
}

Widget _buildArticleCard(Article a) {
  final dateFormatted = DateFormat.yMMMd().add_jm().format(a.date);

  Color sentimentColor(String s) {
    switch (s.toLowerCase()) {
      case "very bullish": return const Color(0xFF0F9D58);
      case "bullish": return const Color(0xFF5AD079);
      case "neutral": return const Color(0xFFA6A49A);
      case "bearish": return const Color(0xFFEB6969);
      case "very bearish": return const Color(0xFFD93025);
      default: return Colors.grey;
    }
  }

  Color impactColor(String i) {
    switch (i.toLowerCase()) {
      case "very high": return const Color(0xFFFFB000);
      case "high": return const Color(0xFFFF9B5B);
      case "mild": return const Color(0xFFFFCD79);
      case "negligible": return const Color(0xFFFFCEAF);
      default: return Colors.grey;
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
            Text(
              a.title,
              style: GoogleFonts.playfairDisplay(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
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
            if (a.companies.isNotEmpty)
              Text(
                "Companies: ${a.companies.join(', ')}",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 8),
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
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateFormatted,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
                Row(
                  children: [
                    if (a.companies.isNotEmpty)
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Image.asset(
                          "assets/tradingview.png",
                          height: 36,
                          width: 36,
                        ),
                        tooltip: "View chart on TradingView",
                        onPressed: () async {
                          try {
                            final companies = await _fetchCompanyDetails(a.companies);
                            if (companies.isEmpty) return;
                            if (companies.length == 1) {
                              _openTradingView(companies.first["symbol"]);
                            } else {
                              _showCompanySelector(companies);
                            }
                          } catch (e) {
                            debugPrint("TradingView error: $e");
                          }
                        },
                      ),
                    const SizedBox(width: 0),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(
                        Icons.bookmark,
                        size: 36,
                        color: Colors.red,
                      ),
                      onPressed: () => _unsaveNews(a.id),
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
            _buildRemoveAllButton(), // 👈 ADD HERE
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

  Widget destination;
  switch (index) {
    case 0:
      destination = const NewsFeedScreen();
      break;
    case 2:
      destination = const ChatbotScreen();
      break;
    case 3:
      destination = const CompanyScreen();
      break;
    case 4:
      destination = const EventsScreen();
      break;
    case 5:
      return;
    default:
      return;
  }
  
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => destination),
  );
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

class CorporateEvent {
  final String id;
  final String title;
  final DateTime date;
  final String description;
  final String type;
  final String tags;
  final String headline;

  CorporateEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.description,
    required this.type,
    required this.tags,
    required this.headline,
  });

  factory CorporateEvent.fromJson(Map<String, dynamic> json) {
    return CorporateEvent(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? 'Untitled Event',
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      description: json['description'] ?? '',
      type: json['type'] ?? 'Event',
      tags: json['tags'] ?? '',
      headline: json['headline'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'description': description,
      'type': type,
      'tags': tags,
      'headline': headline,
    };
  }
}

