// lib/screens/events_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'home_screen.dart';
import 'chatbot_screen.dart';
import 'company_screen.dart';
import 'saved_screen.dart';
import 'profile_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/article_card.dart';
import '../models/article.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:visibility_detector/visibility_detector.dart';




class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}


class _EventsScreenState extends State<EventsScreen> {
  int _selectedTab = 0;
  final List<String> _tabs = ["Today", "Upcoming","Upcoming IPO"];
  
  bool _isLoading = true;
  List<CorporateEvent> _todayEvents = [];
  List<CorporateEvent> _upcomingEvents = [];
  Set<String> _locallySavedEventIds = {};
  late String currentUserId;
  int _bottomIndex = 3;
  List<Article> _ipoNews = [];
  bool _isIpoLoading = false;
  Set<String> _locallySavedIds = {};
  final String baseUrl = "https://13.51.242.86:5000";
  late final PageController _pageController;
  Set<String> _viewedArticles = {};
  DateTime _lastTrackedDate = DateTime.now();


@override
void initState() {
  super.initState();
  _pageController = PageController(viewportFraction: 0.72);

  _loadUserId().then((_) {
    _loadSavedEventIds();
    _loadSavedNewsIds();
    _fetchEvents();
    _fetchIpoNews();
  });
}
@override
void dispose() {
  _pageController.dispose();
  super.dispose();
}

Future<void> _loadUserId() async {
  final prefs = await SharedPreferences.getInstance();
  currentUserId = prefs.getString("userId") ?? "";
}

Future<void> _loadSavedEventIds() async {
  final resp = await http.get(
    Uri.parse("https://13.51.242.86:5000/api/users/$currentUserId/saved-events"),
  );

  if (resp.statusCode == 200) {
    final body = jsonDecode(resp.body);
    setState(() {
      _locallySavedEventIds =
          body["data"].map<String>((e) => e["_id"].toString()).toSet();
    });
  }
}


  Future<void> _fetchEvents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('Fetching events from: http://10.244.218.93:5000/api/events');
      
      final response = await http.get(
        Uri.parse('https://13.51.242.86:5000/api/events'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['events'] == null || (data['events'] as List).isEmpty) {
          debugPrint('No events found in response');
          setState(() {
            _todayEvents = [];
            _upcomingEvents = [];
            _isLoading = false;
          });
          return;
        }
        
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        
        final List<CorporateEvent> allEvents = (data['events'] as List)
            .map((event) => CorporateEvent.fromJson(event))
            .toList();

        debugPrint('Total events fetched: ${allEvents.length}');

        _todayEvents = allEvents.where((event) {
          final eventDate = DateTime(event.date.year, event.date.month, event.date.day);
          return eventDate.isAtSameMomentAs(today);
        }).toList();

        _upcomingEvents = allEvents.where((event) {
          final eventDate = DateTime(event.date.year, event.date.month, event.date.day);
          return eventDate.isAfter(today);
        }).toList();

        debugPrint('Today events: ${_todayEvents.length}');
        debugPrint('Upcoming events: ${_upcomingEvents.length}');

        setState(() {
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load events: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching events: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading events: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _fetchEvents,
            ),
          ),
        );
      }
    }
  }

Future<void> _fetchIpoNews() async {
  setState(() {
    _isIpoLoading = true;
  });

  try {
    final response = await http.get(
      Uri.parse("$baseUrl/api/news/sector/IPO"),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      setState(() {
        _ipoNews = (data["news"] as List)
            .map((e) => Article.fromJson(e))
            .toList();
        _isIpoLoading = false;
      });
    } else {
      throw Exception("Failed to load IPO news");
    }
  } catch (e) {
    setState(() {
      _isIpoLoading = false;
    });
  }
}
Future<void> _trackNewsView() async {
  if (currentUserId.isEmpty) return;

  final now = DateTime.now();
  final date = DateFormat("yyyy-MM-dd").format(now);

  try {
    await http.post(
      Uri.parse("$baseUrl/api/users/profile/news-analytics"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "userId": currentUserId,
        "date": date,
      }),
    );
  } catch (e) {
    debugPrint("News analytics error: $e");
  }

  _lastTrackedDate = now;
}


Future<void> _toggleSaveEvent(CorporateEvent event) async {
  final eventId = event.id;
  final wasSaved = _locallySavedEventIds.contains(eventId);

  // 1️⃣ Optimistic UI
  setState(() {
    wasSaved
        ? _locallySavedEventIds.remove(eventId)
        : _locallySavedEventIds.add(eventId);
  });

  try {
    final resp = await http.post(
      Uri.parse("https://13.51.242.86:5000/api/users/save-event"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "userId": currentUserId,
        "eventId": eventId,
      }),
    );

    if (resp.statusCode != 200) throw Exception();

    // ✅ ONLY WHEN SAVED (NOT UNSAVED)
    if (!wasSaved) {
      // 2️⃣ Success Snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Event saved successfully"),
          duration: Duration(seconds: 2),
        ),
      );

      // 3️⃣ Ask to add to Google Calendar
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Add to Google Calendar"),
          content: const Text(
              "Do you want to add this event to your Google Calendar?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("No"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                addEventToGoogleCalendar(
                  title: event.title,
                  description: event.description,
                  startTime: event.date,
                  endTime: event.date.add(const Duration(hours: 1)),
                );
              },
              child: const Text("Yes"),
            ),
          ],
        ),
      );
    }
  } catch (e) {
    // 🔁 Rollback UI
    setState(() {
      wasSaved
          ? _locallySavedEventIds.add(eventId)
          : _locallySavedEventIds.remove(eventId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Failed to save event"),
        backgroundColor: Colors.red,
      ),
    );
  }
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


Future<void> _openTradingView(String fullSymbol) async {
  final url =
      "https://www.tradingview.com/chart/?symbol=$fullSymbol";

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
    "${c["exchange"]}:${c["symbol"]}",
  );
},

          ),
        ),
      ],
    ),
  );
}

void _showCommoditySelector(List<Map<String, dynamic>> commodities) {
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
        ...commodities.map(
          (c) => ListTile(
            title: Text(c["name"]),
            subtitle: Text(c["symbol"]),
            onTap: () {
              Navigator.pop(context);
              _openTradingView(
                c["symbol"].toString(),
              );
            },
          ),
        ),
      ],
    ),
  );
}


Future<Map<String, dynamic>?> _fetchSectorDetails(String sector) async {
  final url =
      "$baseUrl/api/sector-lookup/by-name?name=$sector";

  final resp = await http.get(Uri.parse(url));

  if (resp.statusCode != 200) return null;

  final body = jsonDecode(resp.body);

  if (!body["success"]) return null;

  return body["data"];
}
Future<Map<String, dynamic>?> _fetchCommodityDetails(String commodity) async {
  final url =
      "$baseUrl/api/commodity-lookup/by-name?name=$commodity";

  final resp = await http.get(Uri.parse(url));

  if (resp.statusCode != 200) return null;

  final body = jsonDecode(resp.body);

  if (!body["success"]) return null;

  return body["data"];
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
          /// ---------------- MARKET INFORMATION ----------------
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
]

else if (a.sector_market.isNotEmpty) ...[
  const SizedBox(height: 14),

  Text(
    "Sector",
    style: GoogleFonts.poppins(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: Colors.black,
    ),
  ),

  const SizedBox(height: 8),

  Chip(
    backgroundColor: const Color(0xFFEA6B6B),
    label: Text(
      a.sector_market,
      style: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
  ),
]

else if (a.commodities_market.isNotEmpty) ...[
  const SizedBox(height: 14),

  Text(
    "Commodity",
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
    children: a.commodities_market.map(
      (commodity) => Chip(
        backgroundColor: const Color(0xFFEA6B6B),
        label: Text(
          commodity,
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



Widget _buildIpoTab() {
  if (_isIpoLoading) {
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFFF05151)),
    );
  }

  if (_ipoNews.isEmpty) {
    return const Center(
      child: Text(
        "No IPO News Available",
        style: TextStyle(fontSize: 16, color: Colors.grey),
      ),
    );
  }

  return PageView.builder(
    scrollDirection: Axis.vertical,
    controller: _pageController,
    padEnds: false,
    physics: const BouncingScrollPhysics(),
    itemCount: _ipoNews.length,
    itemBuilder: (context, index) {
      final article = _ipoNews[index];

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: VisibilityDetector(
          key: Key(article.id),
          onVisibilityChanged: (info) {
            if (info.visibleFraction > 0.6 &&
                !_viewedArticles.contains(article.id)) {

              _viewedArticles.add(article.id);
              _trackNewsView();   // 🔥 analytics call
            }
          },
          child: ArticleCard(
            article: article,
            savedIds: _locallySavedIds,
            onToggleSave: _toggleSaveNews,
            onFetchCompanies: (companies) async {
              if (companies.isEmpty) return;

              final companyData =
                  await _fetchCompanyDetails(companies);

              if (companyData.isEmpty) return;

              if (companyData.length == 1) {
                _openTradingView(
                  "${companyData.first["exchange"]}:${companyData.first["symbol"]}",
                );
              } else {
                _showCompanySelector(companyData);
              }
            },
            onOpenTradingView: _openTradingView,
            onFetchSector: (sector) async {
              final sectorData =
                  await _fetchSectorDetails(sector);

              if (sectorData != null) {
                _openTradingView(
                  "NSE:${sectorData["symbol"]}",
                );
              }
            },
            onFetchCommodities: (commodities) async {
              final List<Map<String, dynamic>> commodityList = [];

              for (String name in commodities) {
                final data =
                    await _fetchCommodityDetails(name);
                if (data != null) {
                  commodityList.add(data);
                }
              }

              if (commodityList.isEmpty) return;

              if (commodityList.length == 1) {
                _openTradingView(
                  commodityList.first["symbol"].toString(),
                );
              } else {
                _showCommoditySelector(commodityList);
              }
            },
            onOpenFullStory: _showFullStory,
          ),
        ),
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Back Button and Title
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F7FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 18,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    "Events Calendar",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _fetchEvents,
                    icon: const Icon(Icons.refresh, color: Color(0xFFF05151)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
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
            ),

            // Tabs
            Container(
              height: 60,
              color: Colors.white,
              child: Row(
                children: _tabs.asMap().entries.map((entry) {
                  final index = entry.key;
                  final tab = entry.value;
                  final selected = _selectedTab == index;
                  
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = index),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: selected ? const Color(0xFFF05151) : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            tab,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                              color: selected ? const Color(0xFFF05151) : Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Content based on selected tab
            Expanded(
              child: _selectedTab == 0
                  ? _buildTodayEventsTab()
                  : _selectedTab == 1
                      ? _buildUpcomingEventsTab()
                      : _buildIpoTab(),
            ),

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
      destination=const NewsFeedScreen();
      break;

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

  Widget _buildTodayEventsTab() {
    if (_todayEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_note, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              "No events for today",
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _fetchEvents,
              child: const Text(
                "Refresh",
                style: TextStyle(color: Color(0xFFF05151)),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Today's Events Section
            const Text(
              "Today's Events",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "${_todayEvents.length} event${_todayEvents.length > 1 ? 's' : ''} scheduled for today",
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 16),

            // Today's Events List
            ..._todayEvents.map((event) => _buildEventCard(event, isToday: true)),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingEventsTab() {
    if (_upcomingEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              "No upcoming events",
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _fetchEvents,
              child: const Text(
                "Refresh",
                style: TextStyle(color: Color(0xFFF05151)),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Upcoming Events",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "${_upcomingEvents.length} event${_upcomingEvents.length > 1 ? 's' : ''} scheduled",
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 16),

            ..._upcomingEvents.map((event) => _buildEventCard(event, isToday: false)),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(CorporateEvent event, {required bool isToday}) {
    final dateFormatted = DateFormat('MMM dd, yyyy').format(event.date);
    final timeFormatted = DateFormat('hh:mm a').format(event.date);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isToday ? const Color(0xFFF05151).withOpacity(0.3) : Colors.grey.shade200,
          width: isToday ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isToday 
                      ? const Color(0xFFF05151).withOpacity(0.1)
                      : const Color(0xFFF6F7FA),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  event.type,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isToday ? const Color(0xFFF05151) : Colors.black54,
                  ),
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE8E8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    "TODAY",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF05151),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              IconButton(
                  icon: Icon(
                    _locallySavedEventIds.contains(event.id)
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                    color: _locallySavedEventIds.contains(event.id)
                        ? Colors.red
                        : Colors.grey,
                  ),
                  onPressed: () => _toggleSaveEvent(event),

                ),

            ],
          ),
          const SizedBox(height: 2),
          Text(
            event.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            event.description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 16,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                dateFormatted,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.access_time,
                size: 16,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                timeFormatted,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              
            ],
          ),
        ],
      ),
    );
  }
}
Future<void> addEventToGoogleCalendar({
  required String title,
  required String description,
  required DateTime startTime,
  required DateTime endTime,
}) async {
  String formatDate(DateTime dt) {
    return DateFormat("yyyyMMdd'T'HHmmss").format(dt);
  }

  final start = formatDate(startTime);
  final end = formatDate(endTime);

  final url =
      "https://www.google.com/calendar/render?action=TEMPLATE"
      "&text=${Uri.encodeComponent(title)}"
      "&details=${Uri.encodeComponent(description)}"
      "&dates=$start/$end";

  final uri = Uri.parse(url);

  if (!await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  )) {
    throw 'Could not launch Google Calendar';
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

