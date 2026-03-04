import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:news_application/screens/saved_screen.dart';
import 'chatbot_screen.dart';
import 'company_screen.dart';
import 'events_screen.dart';
import 'home_screen.dart';
import '../models/article.dart';
import 'package:intl/intl.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';



class IndexScreen extends StatefulWidget {
  const IndexScreen({super.key});

  @override
  State<IndexScreen> createState() => _IndexScreenState();
}

class _IndexScreenState extends State<IndexScreen> {


  String selectedIndex = "^NSEI";
  int _bottomIndex = 1;

  double price = 0;
  List chartData = [];
List gainers = [];
List losers = [];
  List news = [];
  List globalData = [];
  bool isGlobal = false;
Set<String> _locallySavedIds = {};
late String currentUserId;

  final String baseUrl = "http://51.20.72.236:5000";

  @override
  void initState() {
    super.initState();
    _init();
  }
  Future<void> _init() async {
  await _loadUserId();
  await _loadSavedNewsIds();
  fetchIndexData();
}

  Future<void> fetchIndexData() async {
    if (!mounted) return;
    final res = await http.post(
      Uri.parse("$baseUrl/api/index/data"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"symbol": selectedIndex}),
    );

print(res.body);
print("STATUS CODE: ${res.statusCode}");
print("RAW RESPONSE: ${res.body}");

if (res.statusCode != 200) {
  print("Backend error");
} 
    final data = jsonDecode(res.body);

    setState(() {
      price = (data["price"] ?? 0).toDouble();
      chartData = data["chart"] ?? [];
      gainers = data["gainers"] ?? [];
      losers = data["losers"] ?? [];
      news = data["news"] ?? [];
    });
  }

  Future<void> fetchGlobalData() async {

  final res = await http.post(
    Uri.parse("$baseUrl/api/index/global"),
    headers: {"Content-Type": "application/json"},
  );

  if (!mounted) return;

  final data = jsonDecode(res.body);

  setState(() {
    globalData = data;
  });
}

Future<void> fetchGlobalNews() async {
  final res = await http.get(
    Uri.parse("$baseUrl/api/global-news"),
  );

  if (res.statusCode != 200) {
    print("Failed to fetch global news");
    return;
  }

  final data = jsonDecode(res.body);

  setState(() {
    news = data["data"] ?? [];
  });
}
Article _convertToArticle(Map<String, dynamic> n) {
  return Article(
    id: n["_id"] ?? "",
    fileName: n["FileName"] ?? "",     // ✅ FIX
    title: n["Headline"] ?? "",
    excerpt: n["summary"] ?? "",      // ✅ FIX
    summary: n["summary"] ?? "",
    story: n["story"] ?? "",
    sentiment: n["sentiment"] ?? "",
    impact: n["impact"] ?? "",
    tags: List<String>.from(n["tags"] ?? []),   // ✅ FIX
    url: n["link"] ?? "",                        // ✅ FIX
    companies: List<String>.from(n["companies"] ?? []),
    sector_market: n["sector_market"] ?? "",
    commodities_market:
        List<String>.from(n["commodities_market"] ?? []),
    date: DateTime.tryParse(n["PublishedAt"] ?? "") ?? DateTime.now(),
  );
}
Widget _buildArticleCard(Article a) {
  final dateFormatted =
      DateFormat.yMMMd().add_jm().format(a.date);

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

  return InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: () => _showFullStory(a), // SAME AS HOME PAGE
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// TITLE
          Text(
            a.title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 12),

          /// SUMMARY
          Text(
            a.summary,
            style: GoogleFonts.poppins(
              fontSize: 15,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 12),

          /// MARKET TAG
          if (a.companies.isNotEmpty)
            Text(
              "Companies: ${a.companies.join(', ')}",
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            )
          else if (a.sector_market.isNotEmpty)
            Text(
              "Sector: ${a.sector_market}",
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            )
          else if (a.commodities_market.isNotEmpty)
            Text(
              "Commodity: ${a.commodities_market.join(', ')}",
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),

          const SizedBox(height: 8),

          /// SENTIMENT
          if (a.sentiment.isNotEmpty)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: "Sentiment: ",
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: a.sentiment,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: sentimentColor(a.sentiment),
                    ),
                  ),
                ],
              ),
            ),

          /// IMPACT
          if (a.impact.isNotEmpty)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: "Impact: ",
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: a.impact,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: impactColor(a.impact),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 14),

          /// FOOTER
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

    /// TRADINGVIEW
    if (a.companies.isNotEmpty)
      IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: Image.asset(
          "assets/tradingview.png",
          height: 32,
          width: 32,
        ),
        onPressed: () {
          _openTradingView("NSE:${a.companies.first}");
        },
      ),

    /// SAVE
    IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      icon: Icon(
        _locallySavedIds.contains(a.id)
            ? Icons.bookmark
            : Icons.bookmark_border,
        size: 32,
        color: _locallySavedIds.contains(a.id)
            ? Colors.red
            : Colors.grey,
      ),
      onPressed: () => _toggleSaveNews(a.id),
    ),
  ],
)
            ],
          ),
        ],
      ),
    ),
  );
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

Future<void> _loadUserId() async {
  final prefs = await SharedPreferences.getInstance();
  currentUserId = prefs.getString("userId") ?? "";
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

  setState(() {
    if (wasSaved) {
      _locallySavedIds.remove(newsId);
    } else {
      _locallySavedIds.add(newsId);
    }
  });

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

Future<void> _openTradingView(String fullSymbol) async {
  final url =
      "https://www.tradingview.com/chart/?symbol=$fullSymbol";

  final uri = Uri.parse(url);

  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    await launchUrl(uri, mode: LaunchMode.inAppWebView);
  }
}


List<FlSpot> getMiniSpots(List chart) {
  List<FlSpot> spots = [];

  for (int i = 0; i < chart.length; i++) {
    final close = chart[i]["close"];
    if (close == null) continue;

    spots.add(
      FlSpot(spots.length.toDouble(), close.toDouble()),
    );
  }

  return spots;
}

  List<FlSpot> getSpots() {
  List<FlSpot> spots = [];

  for (int i = 0; i < chartData.length; i++) {
    final close = chartData[i]["close"];

    // ignore null or zero values (prevents vertical line)
    if (close == null || close == 0) continue;

    spots.add(
      FlSpot(
        spots.length.toDouble(),
        close.toDouble(),
      ),
    );
  }

  return spots;
}

  Widget tab(String title, String symbol) {
    bool active = selectedIndex == symbol;

    return GestureDetector(
      onTap: () {
  setState(() {
    selectedIndex = symbol;

    // ⭐ IMPORTANT FIX
    isGlobal = (symbol == "^DJI");
  });

  if (isGlobal) {
  fetchGlobalData();   // for global indices
  fetchGlobalNews();   // for global news
} else {
  fetchIndexData();
}
},
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: active ? Colors.red : Colors.black54,
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

@override
Widget build(BuildContext context) {

  return Scaffold(
    backgroundColor: Colors.grey.shade100,

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
              destination = const NewsFeedScreen();
              break;
            case 1:
              destination = const IndexScreen();
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
          _navItem(label: "NEWS", active: 'assets/icons/News Red.svg', inactive: 'assets/icons/News.svg', index: 0),
          _navItem(label: "INDEX", active: 'assets/icons/Ask AI Red.svg', inactive: 'assets/icons/Ask AI.svg', index: 1),
          _navItem(label: "ASK AI", active: 'assets/icons/Ask AI Red.svg', inactive: 'assets/icons/Ask AI.svg', index: 2),
          _navItem(label: "COMPANIES", active: 'assets/icons/Graph Red.svg', inactive: 'assets/icons/Graph.svg', index: 3),
          _navItem(label: "EVENTS", active: 'assets/icons/Calender Red.svg', inactive: 'assets/icons/Calender.svg', index: 4),
          _navItem(label: "SAVED", active: 'assets/icons/Save red.svg', inactive: 'assets/icons/Save.svg', index: 5),
        ],
),

),
    body: SafeArea(
      child: ListView(
        children: [

          /// SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              height: 45,
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(25),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: "Search here...",
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: Colors.red),
                ),
              ),
            ),
          ),

          /// TABS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
  tab("NIFTY", "^NSEI"),
  tab("BANK NIFTY", "^NSEBANK"),
  tab("SECTORS", "^CNXIT"),
  tab("GLOBAL", "^DJI"),
],
            ),
          ),

          const SizedBox(height: 10),

          /// GLOBAL GRID
          if (isGlobal)
            GridView.builder(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  padding: const EdgeInsets.all(12),
  itemCount: globalData.length,
  gridDelegate:
      const SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    childAspectRatio: 1.1,
    crossAxisSpacing: 10,
    mainAxisSpacing: 10,
  ),
  itemBuilder: (_, i) {

    final g = globalData[i];

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [

          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: getMiniSpots(g["chart"]),
                    isCurved: true,
                    dotData: FlDotData(show: false),
                    color: Colors.pink,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 5),

          Text(
            g["name"] ?? "",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),

          Text(
            "${g["price"]}",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  },
),
          /// NORMAL INDEX UI
          if (!isGlobal) ...[

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.all(10),
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
              ),
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: getSpots(),
                      isCurved: true,
                      barWidth: 3,
                      dotData: FlDotData(show: false),
                      color: Colors.teal,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                "TOP GAINERS / LOSERS",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ),

            Container(
              margin: const EdgeInsets.all(12),
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: gainers.length + losers.length,
                itemBuilder: (_, i) {
                  final isGainer = i < gainers.length;
                  final m = isGainer
                  ? gainers[i]
                  : losers[i - gainers.length];
                  return Container(
                    width: 120,
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          m["symbol"] ?? "",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                       Text(
                      "${m["lastPrice"]}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: (m["pChange"] ?? 0) >= 0
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],

          /// NEWS (ALWAYS)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              "NEWS",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: news.length,
            itemBuilder: (_, i) {
              final article = _convertToArticle(news[i]);
              return _buildArticleCard(article);
            },
          ),

          const SizedBox(height: 20),
        ],
      ),
    ),
  );
}
}