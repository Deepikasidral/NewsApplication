import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CompanyNewsScreen extends StatefulWidget {
  final String companyName;
  final String companySymbol;

  const CompanyNewsScreen({
    super.key,
    required this.companyName,
    required this.companySymbol,
  });

  @override
  State<CompanyNewsScreen> createState() => _CompanyNewsScreenState();
}


class _CompanyNewsScreenState extends State<CompanyNewsScreen> {
  List<Map<String, dynamic>> _news = [];
  Map<String, dynamic>? _stockData;
  Map<String, dynamic>? _aiOverview;
  bool _isLoading = false;
  bool _isLoadingStock = false;
  bool _isLoadingAI = false;
  String _error = '';
  String _stockError = '';
  String _aiError = '';
  final String _apiToken = dotenv.env['APIFY_API_TOKEN']!;

  @override
  void initState() {
    super.initState();
    _fetchStockData();
    _fetchCompanyNews();
    _fetchAIOverview();
  }

  Future<void> _fetchStockData() async {
    setState(() {
      _isLoadingStock = true;
      _stockError = '';
    });

    try {
      final response = await http.post(
        Uri.parse("https://api.apify.com/v2/acts/akash9078~indian-stocks-financial-data-scraper/run-sync-get-dataset-items?token=$_apiToken"),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "stockSymbol": widget.companySymbol.toUpperCase(),
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = json.decode(response.body);
        
        // Handle both List and Map responses
        Map<String, dynamic> stockData;
        if (data is List && data.isNotEmpty) {
          stockData = data.first.cast<String, dynamic>();
        } else if (data is Map<String, dynamic>) {
          stockData = data;
        } else {
          throw Exception("Unexpected response format");
        }
        
        setState(() {
          _stockData = stockData;
        });
      } else {
        setState(() {
          _stockError = "HTTP Error (${response.statusCode}): ${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        _stockError = "Stock data fetch failed: $e";
      });
    }

    setState(() => _isLoadingStock = false);
  }

  Future<void> _fetchCompanyNews() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final encodedName = Uri.encodeComponent(widget.companyName);
      final resp = await http.get(Uri.parse(
          "http://192.168.1.4:5000/api/filtered-news/company/$encodedName"));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        setState(() {
          _news = (data as List).cast<Map<String, dynamic>>();
        });
      } else {
        final errorBody = resp.body;
        setState(() {
          _error =
              "Failed to fetch news\nStatus: ${resp.statusCode}\nError: $errorBody";
        });
      }
    } catch (e) {
      setState(() {
        _error = "DB fetch failed: $e";
      });
    }

    setState(() => _isLoading = false);
  }

  Future<void> _fetchAIOverview() async {
    setState(() {
      _isLoadingAI = true;
      _aiError = '';
    });

    try {
      final encodedName = Uri.encodeComponent(widget.companyName);
      final resp = await http.get(Uri.parse(
          "http://192.168.1.4:5000/api/filtered-news/company/$encodedName"));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data is List && data.isNotEmpty) {
          final firstArticle = data.first;
          setState(() {
            _aiOverview = {
              'sector': firstArticle['sector'] ?? 'Not Available',
              'reason': firstArticle['reason'] ?? 'Not Available',
              'sentiment': firstArticle['sentiment'] ?? 'Neutral',
              'impact': firstArticle['impact'] ?? 'Medium',
            };
          });
        } else {
          setState(() {
            _aiOverview = null;
            _aiError = "No AI overview data available";
          });
        }
      } else {
        setState(() {
          _aiError = "Failed to fetch AI overview (${resp.statusCode})";
        });
      }
    } catch (e) {
      setState(() {
        _aiError = "AI overview fetch failed: $e";
      });
    }

    setState(() => _isLoadingAI = false);
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "Date not available";
    try {
      final date = DateFormat("EEEE, MMM dd, yyyy HH:mm:ss").parse(dateString);
      return DateFormat.yMMMd().add_jm().format(date);
    } catch (e) {
      return dateString;
    }
  }

  Color _getImpactColor(String? impact) {
    if (impact == null) return Colors.grey;
    switch (impact.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _parseIndianNumber(String? value) {
    if (value == null || value.isEmpty) return 'N/A';
    return value.replaceAll(',', '');
  }

  Widget _buildStockCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _isLoadingStock
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(),
              ),
            )
          : _stockError.isNotEmpty
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _stockError,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _fetchStockData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEA6B6B),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 36),
                      ),
                      child: const Text("Retry Stock Data"),
                    ),
                  ],
                )
              : _stockData == null
                  ? const Center(
                      child: Text("No stock data available"),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stock Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${widget.companySymbol.toUpperCase()}.NSE",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D3748),
                              ),
                            ),
                            Text(
                              _stockData!['Company Name'] ?? widget.companyName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFEA6B6B),
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Historical Data Section
                        const Text(
                          "Historical Data",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Historical Data Grid - FIXED: Using actual keys from your screenshot
                        Table(
                          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                          columnWidths: const {
                            0: FlexColumnWidth(1),
                            1: FlexColumnWidth(1),
                          },
                          children: [
                            TableRow(
                              children: [
                                _buildStockInfo(
                                  "Current Price",
                                  _stockData!['Current Price']?.toString() ?? 'N/A',
                                  isPrice: true,
                                ),
                                _buildStockInfo(
                                  "High",
                                  _stockData!['High']?.toString() ?? 'N/A',
                                  isPrice: true,
                                ),
                              ],
                            ),
                            TableRow(
                              children: [
                                const SizedBox(height: 16),
                                const SizedBox(height: 16),
                              ],
                            ),
                            TableRow(
                              children: [
                                _buildStockInfo(
                                  "Low",
                                  _stockData!['Low']?.toString() ?? 'N/A',
                                  isPrice: true,
                                ),
                                _buildStockInfo(
                                  "Change",
                                  _calculateChange(),
                                  isPrice: true,
                                  changeColor: true,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Market Cap Row
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Market Cap",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF2D3748),
                                ),
                              ),
                              Text(
                                _formatMarketCap(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2D3748),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Fundamental Data Section
                        const Text(
                          "Fundamental Data",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Fundamental Data Grid - FIXED: Using actual keys
                        Table(
                          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                          columnWidths: const {
                            0: FlexColumnWidth(1),
                            1: FlexColumnWidth(1),
                          },
                          children: [
                            TableRow(
                              children: [
                                _buildFundamentalInfo(
                                  "P/E Ratio",
                                  _stockData!['Stock P/E']?.toString() ?? 'N/A',
                                ),
                                _buildFundamentalInfo(
                                  "Book Value",
                                  _stockData!['Book Value']?.toString() ?? 'N/A',
                                  isPrice: true,
                                ),
                              ],
                            ),
                            TableRow(
                              children: [
                                const SizedBox(height: 16),
                                const SizedBox(height: 16),
                              ],
                            ),
                            TableRow(
                              children: [
                                _buildFundamentalInfo(
                                  "ROE",
                                  _stockData!['ROE']?.toString() ?? 'N/A',
                                  isPercentage: true,
                                ),
                                _buildFundamentalInfo(
                                  "ROCE",
                                  _stockData!['ROCE']?.toString() ?? 'N/A',
                                  isPercentage: true,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        // Additional Data Row
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Dividend Yield",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF2D3748),
                                ),
                              ),
                              Text(
                                _stockData!['Dividend Yield'] != null 
                                  ? '${_stockData!['Dividend Yield']}%'
                                  : 'N/A',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2D3748),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildStockInfo(String label, String value, {bool isPrice = false, bool changeColor = false}) {
    Color textColor = const Color(0xFF2D3748);
    if (changeColor && value != 'N/A') {
      if (value.startsWith('-')) {
        textColor = Colors.red;
      } else if (value.startsWith('+')) {
        textColor = Colors.green;
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isPrice && value != 'N/A' ? '₹$value' : value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildFundamentalInfo(String label, String value, {bool isPercentage = false, bool isPrice = false}) {
    String displayValue = value;
    if (isPercentage && value != 'N/A') {
      displayValue = '$value%';
    } else if (isPrice && value != 'N/A') {
      displayValue = '₹$value';
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            displayValue,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
          ),
        ],
      ),
    );
  }

  String _calculateChange() {
    if (_stockData?['Current Price'] == null ||
        _stockData?['High'] == null ||
        _stockData?['Low'] == null) {
      return 'N/A';
    }
    
    try {
      final currentPrice = double.parse(_parseIndianNumber(_stockData!['Current Price'].toString()));
      final high = double.parse(_parseIndianNumber(_stockData!['High'].toString()));
      final low = double.parse(_parseIndianNumber(_stockData!['Low'].toString()));
      
      // Simple change calculation: from low to current
      final changeFromLow = ((currentPrice - low) / low) * 100;
      
      return '+${changeFromLow.toStringAsFixed(2)}%';
    } catch (e) {
      return 'N/A';
    }
  }

  String _formatMarketCap() {
    final marketCap = _stockData?['Market Cap'];
    if (marketCap == null || marketCap == 'N/A') return 'N/A';
    
    try {
      final value = double.parse(_parseIndianNumber(marketCap.toString()));
      if (value >= 100000) {
        return '₹${(value / 100000).toStringAsFixed(2)}L Cr';
      } else if (value >= 1000) {
        return '₹${(value / 1000).toStringAsFixed(2)}K Cr';
      }
      return '₹${value.toStringAsFixed(2)} Cr';
    } catch (e) {
      return '₹$marketCap Cr';
    }
  }

  // ADDING THE MISSING METHODS:

  Widget _buildAIOverviewSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              const Icon(
                Icons.analytics,
                color: Color(0xFFEA6B6B),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                "AI Overview",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 0, 0, 0),
                ),
              ),
              const Spacer(),
              if (_isLoadingAI)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _isLoadingAI
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _aiError.isNotEmpty
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _aiError,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _fetchAIOverview,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEA6B6B),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 36),
                          ),
                          child: const Text("Retry AI Overview"),
                        ),
                      ],
                    )
                  : _aiOverview == null
                      ? const Center(
                          child: Text("No AI overview available"),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Sector
                            _buildAIOverviewItem(
                              icon: Icons.business,
                              label: "Sector",
                              value: _aiOverview!['sector'].toString(),
                              valueColor: Colors.black,
                            ),
                            const SizedBox(height: 16),
                            // Reason
                            _buildAIOverviewItem(
                              icon: Icons.emoji_objects,
                              label: "Reason",
                              value: _aiOverview!['reason'].toString(),
                              valueColor: Colors.black,
                            ),
                            const SizedBox(height: 16),
                            // Sentiment & Impact in Row
                            Row(
                              children: [
                                Expanded(
                                  child: _buildAIOverviewItem(
                                    icon: Icons.tag_faces,
                                    label: "Sentiment",
                                    value: _aiOverview!['sentiment'].toString(),
                                    valueColor: Colors.black,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildAIOverviewItem(
                                    icon: Icons.trending_up,
                                    label: "Impact",
                                    value: _aiOverview!['impact'].toString(),
                                    valueColor:
                                        _getImpactColor(_aiOverview!['impact']),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
        ],
      ),
    );
  }

  Widget _buildAIOverviewItem({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Icon(
              icon,
              size: 20,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Latest News",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          IconButton(
            onPressed: () {
              _fetchStockData();
              _fetchCompanyNews();
              _fetchAIOverview();
            },
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh",
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsItem(Map<String, dynamic> article) {
    final headline = article["Headline"] ?? "No headline";
    final publishedAt = article["PublishedAt"] ?? "";
    final summary = article["summary"] ?? "";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Published Date
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  _formatDate(publishedAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          // Headline and Summary
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Summary",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFEA6B6B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          summary,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade800,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      appBar: AppBar(
        title: const Text("Company News"),
        backgroundColor: const Color(0xFFEA6B6B),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Company Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFEA6B6B),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Company:",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.companyName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Symbol: ${widget.companySymbol.toUpperCase()}",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Main Content Area
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await _fetchStockData();
                await _fetchCompanyNews();
                await _fetchAIOverview();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildStockCard(),
                    _buildAIOverviewSection(),
                    _buildNewsHeader(),
                    _isLoading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: CircularProgressIndicator(),
                          )
                        : _error.isNotEmpty
                            ? Container(
                                padding: const EdgeInsets.all(20),
                                margin: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: Colors.red,
                                      size: 40,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _error,
                                      style: const TextStyle(color: Colors.red),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: _fetchCompanyNews,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFEA6B6B),
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(0, 36),
                                      ),
                                      child: const Text("Retry News"),
                                    ),
                                  ],
                                ),
                              )
                            : _news.isEmpty
                                ? Container(
                                    padding: const EdgeInsets.all(40),
                                    margin: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.shade200),
                                    ),
                                    child: const Column(
                                      children: [
                                        Icon(
                                          Icons.article_outlined,
                                          color: Colors.grey,
                                          size: 40,
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          "No news found for this company",
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 16,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  )
                                : Column(
                                    children: _news.map(_buildNewsItem).toList(),
                                  ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}



