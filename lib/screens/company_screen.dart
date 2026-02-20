import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'company_news_screen.dart';
import 'home_screen.dart';
import 'chatbot_screen.dart';
import 'events_screen.dart';
import 'saved_screen.dart';
import 'profile_screen.dart';
import '../services/stock_price_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

class CompanyScreen extends StatefulWidget {
  const CompanyScreen({super.key});

  @override
  State<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends State<CompanyScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _filteredCompanies = [];
  bool _isLoading = false;
  String _error = '';
  int _bottomIndex = 2;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applySearch);
    _fetchCompanies();
  }

  @override
  void dispose() {
    _searchController.removeListener(_applySearch);
    _searchController.dispose();
    super.dispose();
  }

  void _applySearch() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredCompanies = List.from(_companies));
      return;
    }

    setState(() {
      _filteredCompanies = _companies.where((company) {
        final companyName = (company["Company Name"] ?? "").toLowerCase();
        final symbol = (company["Symbol"] ?? "").toLowerCase();
        return companyName.contains(query) || symbol.contains(query);
      }).toList();
    });
  }

  Future<void> _fetchCompanies() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final resp = await http.get(Uri.parse("https://13.51.242.86:5000/api/companies"));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        setState(() {
          _companies = (data as List).cast<Map<String, dynamic>>();
          _filteredCompanies = List.from(_companies);
        });
      } else {
        final errorBody = resp.body;
        setState(() {
          _error = "Failed to fetch companies from DB\nStatus: ${resp.statusCode}\nError: $errorBody";
        });
      }
    } catch (e) {
      setState(() {
        _error = "DB fetch failed: $e";
      });
    }

    setState(() => _isLoading = false);
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
      backgroundColor: const Color(0xFFF6F7FA),
      appBar: AppBar(
        title: const Text("Companies"),
        backgroundColor: const Color(0xFFEA6B6B),
        foregroundColor: Colors.white,
        actions: [
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
            child: const Padding(
              padding: EdgeInsets.only(right: 16),
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
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
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
                          hintText: "Search companies...",
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const Icon(Icons.search, color: Colors.black54),
                  ],
                ),
              ),
            ),
            // Company List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error.isNotEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _error,
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _fetchCompanies,
                                child: const Text("Retry"),
                              ),
                            ],
                          ),
                        )
                      : _filteredCompanies.isEmpty
                          ? const Center(child: Text("No companies found"))
                          : RefreshIndicator(
                              onRefresh: _fetchCompanies,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                itemCount: _filteredCompanies.length,
                                itemBuilder: (context, index) {
                                  final company = _filteredCompanies[index];
                                  final companyName = company["Company Name"] ?? "Unknown";
                                  final symbol = company["Symbol"] ?? "";

                                  return CompanyListItem(
                                    companyName: companyName,
                                    symbol: symbol,
                                  );
                                },
                              ),
                            ),
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
}


class CompanyListItem extends StatefulWidget {
  final String companyName;
  final String symbol;

  const CompanyListItem({
    super.key,
    required this.companyName,
    required this.symbol,
  });

  @override
  State<CompanyListItem> createState() => _CompanyListItemState();
}

class _CompanyListItemState extends State<CompanyListItem> {
  Map<String, dynamic>? stockData;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchStockPrice();
  }

  Future<void> _fetchStockPrice() async {
    if (widget.symbol.isEmpty) {
      setState(() => loading = false);
      return;
    }

    final data = await StockPriceService.getStockPrice(widget.symbol);
    setState(() {
      stockData = data;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CompanyNewsScreen(
                companyName: widget.companyName,
                companySymbol: widget.symbol,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.companyName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (stockData != null) ...[
                const SizedBox(
                  height: 30,
                  child: VerticalDivider(color: Colors.grey, thickness: 1),
                ),
                const SizedBox(width: 8),
                Text(
                  stockData!['price'],
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  stockData!['changePercent'],
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: double.parse(stockData!['changePercent']) >= 0
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
