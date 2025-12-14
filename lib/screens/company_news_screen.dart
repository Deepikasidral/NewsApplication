

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

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
      final companySymbol = widget.companySymbol.toUpperCase();
      final response = await http.get(
        Uri.parse(
            "https://eodhd.com/api/eod/$companySymbol.NSE?api_token=693c20d12c22f5.65029013&fmt=json&limit=1"),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          setState(() {
            _stockData = data.last;
          });
        } else {
          setState(() {
            _stockError = "No stock data available";
          });
        }
      } else {
        setState(() {
          _stockError = "Failed to fetch stock data (${response.statusCode})";
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
          "http://192.168.1.7:5000/api/filtered-news/company/$encodedName"));

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
          "http://192.168.1.7:5000/api/filtered-news/company/$encodedName"));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data is List && data.isNotEmpty) {
          // Get the first article to extract AI overview data
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

  String _formatStockDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "N/A";
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
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
                            _formatStockDate(_stockData!['date']),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Stock Prices Grid - FIXED VERSION
                      Table(
                        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                        columnWidths: const {
                          0: FlexColumnWidth(1),
                          1: FlexColumnWidth(1),
                        },
                        children: [
                          TableRow(
                            children: [
                              _buildStockInfo("Open", _stockData!['open']),
                              _buildStockInfo("High", _stockData!['high']),
                            ],
                          ),
                          TableRow(
                            children: [
                              const SizedBox(height: 16), // Spacing between rows
                              const SizedBox(height: 16),
                            ],
                          ),
                          TableRow(
                            children: [
                              _buildStockInfo("Low", _stockData!['low']),
                              _buildStockInfo("Close", _stockData!['close']),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Volume Row
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Volume",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              _stockData!['volume'] != null
                                  ? '${(_stockData!['volume'] / 1000).toStringAsFixed(1)}K'
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

  Widget _buildStockInfo(String label, dynamic value) {
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
          (value ?? 0).toStringAsFixed(2),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
          ),
        ),
      ],
    );
  }

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
                                    valueColor:Colors.black
                                        
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

// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';
// import 'package:yahoo_finance_data_reader/yahoo_finance_data_reader.dart';

// class CompanyNewsScreen extends StatefulWidget {
//   final String companyName;
//   final String companySymbol;

//   const CompanyNewsScreen({
//     super.key, 
//     required this.companyName,
//     required this.companySymbol,
//   });

//   @override
//   State<CompanyNewsScreen> createState() => _CompanyNewsScreenState();
// }

// class _CompanyNewsScreenState extends State<CompanyNewsScreen> {
//   List<Map<String, dynamic>> _news = [];
//   Map<String, dynamic>? _stockData;
//   bool _isLoading = false;
//   bool _isLoadingStock = false;
//   String _error = '';
//   String _stockError = '';

//   @override
//   void initState() {
//     super.initState();
//     _fetchStockData();
//     _fetchCompanyNews();
//   }

//   Future<void> _fetchStockData() async {
//     setState(() {
//       _isLoadingStock = true;
//       _stockError = '';
//     });

//     try {
//       // Format symbol for Yahoo Finance (Indian stocks)
//       final yahooSymbol = '${widget.companySymbol}.NS';
      
//       // Make parallel API calls for better performance
//       final futures = await Future.wait([
//         _fetchYahooQuote(yahooSymbol),
//         _fetchYahooFundamentals(yahooSymbol),
//       ]);
      
//       final quoteData = futures[0] as Map<String, dynamic>;
//       final fundamentals = futures[1] as Map<String, dynamic>;
      
//       // Combine both datasets
//       setState(() {
//         _stockData = {
//           // Price data from quote
//           ...quoteData,
//           // Fundamentals
//           ...fundamentals,
//           'symbol': widget.companySymbol,
//           'companyName': fundamentals['companyName'] ?? widget.companyName,
//           'lastUpdated': DateTime.now().toIso8601String(),
//         };
//       });
      
//     } catch (e) {
//       setState(() {
//         _stockError = "Failed to fetch stock data: $e";
//       });
//     }

//     setState(() => _isLoadingStock = false);
//   }

//   // Method 1: Get quote/price data
//   Future<Map<String, dynamic>> _fetchYahooQuote(String symbol) async {
//     try {
//       final response = await http.get(
//         Uri.parse('https://query1.finance.yahoo.com/v8/finance/chart/$symbol?interval=1d&range=1d'),
//       );
      
//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         final chart = data['chart'];
        
//         if (chart['error'] != null) {
//           throw Exception(chart['error']['description']);
//         }
        
//         final result = chart['result'][0];
//         final meta = result['meta'];
        
//         // Calculate change values
//         final currentPrice = meta['regularMarketPrice'] ?? 0.0;
//         final previousClose = meta['previousClose'] ?? 0.0;
//         final change = currentPrice - previousClose;
//         final changePercent = previousClose != 0 ? (change / previousClose * 100) : 0.0;
        
//         return {
//           'currentPrice': currentPrice,
//           'previousClose': previousClose,
//           'open': meta['regularMarketOpen'],
//           'high': meta['regularMarketDayHigh'],
//           'low': meta['regularMarketDayLow'],
//           'close': currentPrice,
//           'volume': meta['regularMarketVolume'],
//           'change': change,
//           'change_pct': changePercent,
//           'currency': meta['currency'],
//           'timestamp': DateTime.now().toIso8601String(),
//         };
//       }
//       throw Exception('HTTP ${response.statusCode}');
//     } catch (e) {
//       rethrow;
//     }
//   }

//   // Method 2: Get fundamental data
//   Future<Map<String, dynamic>> _fetchYahooFundamentals(String symbol) async {
//     try {
//       final response = await http.get(
//         Uri.parse('https://query2.finance.yahoo.com/v10/finance/quoteSummary/$symbol?modules=financialData,defaultKeyStatistics,summaryProfile'),
//       );
      
//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         final quoteSummary = data['quoteSummary'];
        
//         if (quoteSummary['error'] != null || quoteSummary['result'] == null) {
//           return {};
//         }
        
//         final result = quoteSummary['result'][0];
//         final financialData = result['financialData'] ?? {};
//         final defaultKeyStats = result['defaultKeyStatistics'] ?? {};
//         final summaryProfile = result['summaryProfile'] ?? {};
//         final price = result['price'] ?? {};
        
//         return {
//           // Financial metrics
//           'marketCap': financialData['marketCap']?['raw']?.toDouble(),
//           'peRatio': financialData['trailingPE']?['raw']?.toDouble(),
//           'forwardPE': defaultKeyStats['forwardPE']?['raw']?.toDouble(),
//           'roe': financialData['returnOnEquity']?['raw']?.toDouble(),
//           'debtToEquity': financialData['debtToEquity']?['raw']?.toDouble(),
//           'dividendYield': financialData['dividendYield']?['raw']?.toDouble(),
//           'beta': defaultKeyStats['beta']?['raw']?.toDouble(),
//           'eps': defaultKeyStats['trailingEps']?['raw']?.toDouble(),
//           'bookValue': defaultKeyStats['bookValue']?['raw']?.toDouble(),
//           'priceToBook': defaultKeyStats['priceToBook']?['raw']?.toDouble(),
//           'profitMargins': financialData['profitMargins']?['raw']?.toDouble(),
//           'operatingMargins': financialData['operatingMargins']?['raw']?.toDouble(),
//           'revenueGrowth': financialData['revenueGrowth']?['raw']?.toDouble(),
//           'currentRatio': financialData['currentRatio']?['raw']?.toDouble(),
//           'quickRatio': financialData['quickRatio']?['raw']?.toDouble(),
//           'totalCash': financialData['totalCash']?['raw']?.toDouble(),
//           'totalDebt': financialData['totalDebt']?['raw']?.toDouble(),
//           'totalRevenue': financialData['totalRevenue']?['raw']?.toDouble(),
//           'grossProfits': financialData['grossProfits']?['raw']?.toDouble(),
//           'freeCashflow': financialData['freeCashflow']?['raw']?.toDouble(),
//           'operatingCashflow': financialData['operatingCashflow']?['raw']?.toDouble(),
//           'earningsGrowth': financialData['earningsGrowth']?['raw']?.toDouble(),
//           'grossMargins': financialData['grossMargins']?['raw']?.toDouble(),
//           'ebitdaMargins': financialData['ebitdaMargins']?['raw']?.toDouble(),
          
//           // Company info
//           'companyName': price['longName'] ?? summaryProfile['longName'],
//           'sector': summaryProfile['sector'],
//           'industry': summaryProfile['industry'],
//           'website': summaryProfile['website'],
//           'fullTimeEmployees': summaryProfile['fullTimeEmployees'],
//           'address': summaryProfile['address1'],
//           'city': summaryProfile['city'],
//           'state': summaryProfile['state'],
//           'zip': summaryProfile['zip'],
//           'country': summaryProfile['country'],
//           'phone': summaryProfile['phone'],
//           'longBusinessSummary': summaryProfile['longBusinessSummary'],
//         };
//       }
//       return {};
//     } catch (e) {
//       return {};
//     }
//   }

//   Future<void> _fetchCompanyNews() async {
//     setState(() {
//       _isLoading = true;
//       _error = '';
//     });

//     try {
//       final encodedName = Uri.encodeComponent(widget.companyName);
//       final resp = await http.get(Uri.parse(
//           "http://192.168.1.7:5000/api/filtered-news/company/$encodedName"));

//       if (resp.statusCode == 200) {
//         final data = json.decode(resp.body);
//         setState(() {
//           _news = (data as List).cast<Map<String, dynamic>>();
//         });
//       } else {
//         final errorBody = resp.body;
//         setState(() {
//           _error =
//               "Failed to fetch news\nStatus: ${resp.statusCode}\nError: $errorBody";
//         });
//       }
//     } catch (e) {
//       setState(() {
//         _error = "DB fetch failed: $e";
//       });
//     }

//     setState(() => _isLoading = false);
//   }

//   String _formatDate(String? dateString) {
//     if (dateString == null || dateString.isEmpty) return "Date not available";
//     try {
//       final date = DateFormat("EEEE, MMM dd, yyyy HH:mm:ss").parse(dateString);
//       return DateFormat.yMMMd().add_jm().format(date);
//     } catch (e) {
//       return dateString;
//     }
//   }

//   String _formatStockDate(String? dateString) {
//     if (dateString == null || dateString.isEmpty) return "N/A";
//     try {
//       final date = DateTime.parse(dateString);
//       return DateFormat('MMM dd, yyyy').format(date);
//     } catch (e) {
//       return dateString;
//     }
//   }

//   Color _getPriceChangeColor(double? change, double? changePercent) {
//     if (change == null || changePercent == null) return Colors.grey;
//     if (change > 0) return Colors.green;
//     if (change < 0) return Colors.red;
//     return Colors.grey;
//   }

//   IconData _getPriceChangeIcon(double? change) {
//     if (change == null) return Icons.horizontal_rule;
//     if (change > 0) return Icons.arrow_upward;
//     if (change < 0) return Icons.arrow_downward;
//     return Icons.horizontal_rule;
//   }

//   String _formatMarketCap(double? marketCap) {
//     if (marketCap == null) return 'N/A';
//     if (marketCap >= 1e12) return '₹${(marketCap / 1e12).toStringAsFixed(2)}T';
//     if (marketCap >= 1e9) return '₹${(marketCap / 1e9).toStringAsFixed(2)}B';
//     if (marketCap >= 1e6) return '₹${(marketCap / 1e6).toStringAsFixed(2)}M';
//     return '₹${marketCap.toStringAsFixed(2)}';
//   }

//   // Helper method for price metrics
//   Widget _buildPriceMetric(String label, dynamic value, {bool isVolume = false}) {
//     return Column(
//       children: [
//         Text(
//           label,
//           style: TextStyle(
//             fontSize: 12,
//             color: Colors.grey.shade600,
//           ),
//         ),
//         const SizedBox(height: 4),
//         Text(
//           isVolume && value != null 
//               ? '${(value / 1000).toStringAsFixed(1)}K'
//               : value != null ? "₹${value.toStringAsFixed(2)}" : "N/A",
//           style: const TextStyle(
//             fontSize: 14,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//       ],
//     );
//   }

//   // Helper method for info rows
//   Widget _buildInfoRow(String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 8),
//       child: Row(
//         children: [
//           Text(
//             "$label: ",
//             style: TextStyle(
//               fontSize: 12,
//               color: Colors.grey.shade600,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//           Expanded(
//             child: Text(
//               value,
//               style: const TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w600,
//               ),
//               overflow: TextOverflow.ellipsis,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // Helper method for fundamental cards
//   Widget _buildFundamentalCard(String label, String value) {
//     return Expanded(
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//         margin: const EdgeInsets.symmetric(horizontal: 2),
//         decoration: BoxDecoration(
//           color: Colors.grey.shade50,
//           borderRadius: BorderRadius.circular(8),
//           border: Border.all(color: Colors.grey.shade200),
//         ),
//         child: Column(
//           children: [
//             Text(
//               label,
//               style: TextStyle(
//                 fontSize: 11,
//                 color: Colors.grey.shade600,
//                 fontWeight: FontWeight.w500,
//               ),
//               textAlign: TextAlign.center,
//             ),
//             const SizedBox(height: 4),
//             Text(
//               value,
//               style: const TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.bold,
//                 color: Color(0xFF2D3748),
//               ),
//               textAlign: TextAlign.center,
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF6F7FA),
//       appBar: AppBar(
//         title: const Text("Company News"),
//         backgroundColor: const Color(0xFFEA6B6B),
//         foregroundColor: Colors.white,
//       ),
//       body: SafeArea(
//         child: Column(
//           children: [
//             // Company Name Header
//             Container(
//               width: double.infinity,
//               padding: const EdgeInsets.all(20),
//               decoration: BoxDecoration(
//                 color: const Color(0xFFEA6B6B),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.grey.withOpacity(0.2),
//                     blurRadius: 4,
//                     offset: const Offset(0, 2),
//                   ),
//                 ],
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text(
//                     "Company:",
//                     style: TextStyle(
//                       color: Colors.white70,
//                       fontSize: 14,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                   const SizedBox(height: 6),
//                   Text(
//                     _stockData?['companyName'] ?? widget.companyName,
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 22,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     "Symbol: ${widget.companySymbol.toUpperCase()}.NSE",
//                     style: const TextStyle(
//                       color: Colors.white70,
//                       fontSize: 14,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
            
//             // Stock Data Card
//             Container(
//               padding: const EdgeInsets.all(16),
//               margin: const EdgeInsets.all(14),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(14),
//                 border: Border.all(color: Colors.grey.shade200),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.grey.withOpacity(0.08),
//                     blurRadius: 12,
//                     offset: const Offset(0, 4),
//                   ),
//                 ],
//               ),
//               child: _isLoadingStock
//                   ? const Center(
//                       child: Padding(
//                         padding: EdgeInsets.symmetric(vertical: 20),
//                         child: CircularProgressIndicator(),
//                       ),
//                     )
//                   : _stockError.isNotEmpty
//                       ? Column(
//                           children: [
//                             Text(
//                               _stockError,
//                               style: const TextStyle(color: Colors.red),
//                               textAlign: TextAlign.center,
//                             ),
//                             const SizedBox(height: 8),
//                             ElevatedButton(
//                               onPressed: _fetchStockData,
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: const Color(0xFFEA6B6B),
//                                 foregroundColor: Colors.white,
//                               ),
//                               child: const Text("Retry Stock Data"),
//                             ),
//                           ],
//                         )
//                       : _stockData == null || _stockData!.isEmpty
//                           ? const Center(child: Text("No stock data available"))
//                           : Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 // Stock Header
//                                 Row(
//                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                   children: [
//                                     Column(
//                                       crossAxisAlignment: CrossAxisAlignment.start,
//                                       children: [
//                                         Text(
//                                           "${widget.companySymbol.toUpperCase()}.NSE",
//                                           style: const TextStyle(
//                                             fontSize: 16,
//                                             fontWeight: FontWeight.bold,
//                                             color: Color(0xFF2D3748),
//                                           ),
//                                         ),
//                                         if (_stockData!['companyName'] != null)
//                                           Text(
//                                             _stockData!['companyName'],
//                                             style: TextStyle(
//                                               fontSize: 12,
//                                               color: Colors.grey.shade600,
//                                             ),
//                                           ),
//                                       ],
//                                     ),
//                                     Column(
//                                       crossAxisAlignment: CrossAxisAlignment.end,
//                                       children: [
//                                         Text(
//                                           "₹${(_stockData!['currentPrice'] ?? 0).toStringAsFixed(2)}",
//                                           style: TextStyle(
//                                             fontSize: 20,
//                                             fontWeight: FontWeight.bold,
//                                             color: _getPriceChangeColor(
//                                               _stockData!['change'],
//                                               _stockData!['change_pct'],
//                                             ),
//                                           ),
//                                         ),
//                                         Row(
//                                           children: [
//                                             Icon(
//                                               _getPriceChangeIcon(_stockData!['change']),
//                                               size: 14,
//                                               color: _getPriceChangeColor(
//                                                 _stockData!['change'],
//                                                 _stockData!['change_pct'],
//                                               ),
//                                             ),
//                                             const SizedBox(width: 4),
//                                             Text(
//                                               "${(_stockData!['change'] ?? 0).toStringAsFixed(2)} (${(_stockData!['change_pct'] ?? 0).toStringAsFixed(2)}%)",
//                                               style: TextStyle(
//                                                 fontSize: 12,
//                                                 fontWeight: FontWeight.w600,
//                                                 color: _getPriceChangeColor(
//                                                   _stockData!['change'],
//                                                   _stockData!['change_pct'],
//                                                 ),
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ],
//                                     ),
//                                   ],
//                                 ),
                                
//                                 const SizedBox(height: 16),
                                
//                                 // Stock Prices Row
//                                 Row(
//                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                   children: [
//                                     _buildPriceMetric("Open", _stockData!['open']),
//                                     _buildPriceMetric("High", _stockData!['high']),
//                                     _buildPriceMetric("Low", _stockData!['low']),
//                                     _buildPriceMetric("Prev Close", _stockData!['previousClose']),
//                                   ],
//                                 ),
                                
//                                 const SizedBox(height: 12),
                                
//                                 // Volume and Market Cap
//                                 Row(
//                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                   children: [
//                                     _buildPriceMetric("Volume", _stockData!['volume'], isVolume: true),
//                                     if (_stockData!['marketCap'] != null)
//                                       Column(
//                                         crossAxisAlignment: CrossAxisAlignment.end,
//                                         children: [
//                                           Text(
//                                             "Market Cap",
//                                             style: TextStyle(
//                                               fontSize: 12,
//                                               color: Colors.grey.shade600,
//                                             ),
//                                           ),
//                                           const SizedBox(height: 4),
//                                           Text(
//                                             _formatMarketCap(_stockData!['marketCap']),
//                                             style: const TextStyle(
//                                               fontSize: 14,
//                                               fontWeight: FontWeight.w600,
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                   ],
//                                 ),
                                
//                                 // Sector and Industry
//                                 if (_stockData!['sector'] != null || _stockData!['industry'] != null)
//                                   Column(
//                                     crossAxisAlignment: CrossAxisAlignment.start,
//                                     children: [
//                                       const SizedBox(height: 16),
//                                       if (_stockData!['sector'] != null)
//                                         _buildInfoRow("Sector", _stockData!['sector']),
//                                       if (_stockData!['industry'] != null)
//                                         _buildInfoRow("Industry", _stockData!['industry']),
//                                     ],
//                                   ),
                                
//                                 // Fundamental Metrics Section
//                                 if (_stockData!['peRatio'] != null || 
//                                     _stockData!['roe'] != null || 
//                                     _stockData!['debtToEquity'] != null)
//                                   Column(
//                                     crossAxisAlignment: CrossAxisAlignment.start,
//                                     children: [
//                                       const SizedBox(height: 20),
//                                       const Text(
//                                         "Fundamental Metrics",
//                                         style: TextStyle(
//                                           fontSize: 16,
//                                           fontWeight: FontWeight.bold,
//                                           color: Color(0xFF2D3748),
//                                         ),
//                                       ),
//                                       const SizedBox(height: 12),
                                      
//                                       // First row of metrics
//                                       Row(
//                                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                         children: [
//                                           if (_stockData!['peRatio'] != null)
//                                             _buildFundamentalCard("P/E Ratio", _stockData!['peRatio'].toStringAsFixed(2)),
//                                           if (_stockData!['forwardPE'] != null)
//                                             _buildFundamentalCard("Forward P/E", _stockData!['forwardPE'].toStringAsFixed(2)),
//                                           if (_stockData!['roe'] != null)
//                                             _buildFundamentalCard("ROE", "${(_stockData!['roe'] * 100).toStringAsFixed(1)}%"),
//                                         ],
//                                       ),
                                      
//                                       const SizedBox(height: 12),
                                      
//                                       // Second row of metrics
//                                       Row(
//                                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                         children: [
//                                           if (_stockData!['debtToEquity'] != null)
//                                             _buildFundamentalCard("Debt/Equity", _stockData!['debtToEquity'].toStringAsFixed(2)),
//                                           if (_stockData!['dividendYield'] != null)
//                                             _buildFundamentalCard("Div Yield", "${(_stockData!['dividendYield'] * 100).toStringAsFixed(2)}%"),
//                                           if (_stockData!['beta'] != null)
//                                             _buildFundamentalCard("Beta", _stockData!['beta'].toStringAsFixed(2)),
//                                         ],
//                                       ),
                                      
//                                       const SizedBox(height: 12),
                                      
//                                       // Third row of metrics
//                                       Row(
//                                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                         children: [
//                                           if (_stockData!['eps'] != null)
//                                             _buildFundamentalCard("EPS", "₹${_stockData!['eps'].toStringAsFixed(2)}"),
//                                           if (_stockData!['priceToBook'] != null)
//                                             _buildFundamentalCard("Price/Book", _stockData!['priceToBook'].toStringAsFixed(2)),
//                                           if (_stockData!['profitMargins'] != null)
//                                             _buildFundamentalCard("Profit Margin", "${(_stockData!['profitMargins'] * 100).toStringAsFixed(1)}%"),
//                                         ],
//                                       ),
//                                     ],
//                                   ),
//                               ],
//                             ),
//             ),
            
//             // News List Header
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16.0),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   const Text(
//                     "Latest News",
//                     style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                       color: Color(0xFF2D3748),
//                     ),
//                   ),
//                   IconButton(
//                     onPressed: () {
//                       _fetchStockData();
//                       _fetchCompanyNews();
//                     },
//                     icon: const Icon(Icons.refresh),
//                     tooltip: "Refresh",
//                   ),
//                 ],
//               ),
//             ),
            
//             // News List
//             Expanded(
//               child: _isLoading
//                   ? const Center(child: CircularProgressIndicator())
//                   : _error.isNotEmpty
//                       ? Center(
//                           child: Column(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: [
//                               Text(
//                                 _error,
//                                 style: const TextStyle(color: Colors.red),
//                                 textAlign: TextAlign.center,
//                               ),
//                               const SizedBox(height: 16),
//                               ElevatedButton(
//                                 onPressed: _fetchCompanyNews,
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: const Color(0xFFEA6B6B),
//                                   foregroundColor: Colors.white,
//                                 ),
//                                 child: const Text("Retry News"),
//                               ),
//                             ],
//                           ),
//                         )
//                       : _news.isEmpty
//                           ? const Center(
//                               child: Text("No news found for this company"))
//                           : RefreshIndicator(
//                               onRefresh: () async {
//                                 await _fetchStockData();
//                                 await _fetchCompanyNews();
//                               },
//                               child: ListView.builder(
//                                 padding: const EdgeInsets.symmetric(
//                                     vertical: 10, horizontal: 14),
//                                 itemCount: _news.length,
//                                 itemBuilder: (context, index) {
//                                   final article = _news[index];
//                                   final headline =
//                                       article["Headline"] ?? "No headline";
//                                   final publishedAt =
//                                       article["PublishedAt"] ?? "";
//                                   final summary = article["summary"] ?? "";

//                                   return Padding(
//                                     padding: const EdgeInsets.only(bottom: 10),
//                                     child: Container(
//                                       padding: const EdgeInsets.all(16),
//                                       decoration: BoxDecoration(
//                                         color: Colors.white,
//                                         borderRadius: BorderRadius.circular(14),
//                                         border: Border.all(
//                                             color: Colors.grey.shade200),
//                                         boxShadow: [
//                                           BoxShadow(
//                                             color: Colors.grey.withOpacity(0.06),
//                                             blurRadius: 8,
//                                           ),
//                                         ],
//                                       ),
//                                       child: Column(
//                                         crossAxisAlignment:
//                                             CrossAxisAlignment.start,
//                                         children: [
//                                           // Headline
//                                           Text(
//                                             headline,
//                                             style: const TextStyle(
//                                               fontSize: 17,
//                                               fontWeight: FontWeight.bold,
//                                             ),
//                                           ),
//                                           const SizedBox(height: 10),
//                                           // Published Date
//                                           Row(
//                                             children: [
//                                               Icon(Icons.calendar_today,
//                                                   size: 14,
//                                                   color: Colors.grey.shade600),
//                                               const SizedBox(width: 6),
//                                               Text(
//                                                 _formatDate(publishedAt),
//                                                 style: TextStyle(
//                                                   fontSize: 12,
//                                                   color: Colors.grey.shade600,
//                                                 ),
//                                               ),
//                                             ],
//                                           ),
//                                           const SizedBox(height: 12),
//                                           // Summary
//                                           if (summary.isNotEmpty) ...[
//                                             const Text(
//                                               "Summary:",
//                                               style: TextStyle(
//                                                 fontSize: 14,
//                                                 fontWeight: FontWeight.w600,
//                                                 color: Color(0xFFEA6B6B),
//                                               ),
//                                             ),
//                                             const SizedBox(height: 6),
//                                             Text(
//                                               summary,
//                                               style: TextStyle(
//                                                 fontSize: 14,
//                                                 color: Colors.grey.shade800,
//                                                 height: 1.5,
//                                               ),
//                                             ),
//                                           ],
//                                         ],
//                                       ),
//                                     ),
//                                   );
//                                 },
//                               ),
//                             ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';

// class CompanyNewsScreen extends StatefulWidget {
//   final String companyName;
//   final String companySymbol; // ADD THIS FIELD

//   const CompanyNewsScreen({
//     super.key, 
//     required this.companyName,
//     required this.companySymbol, // ADD THIS PARAMETER
//   });

//   @override
//   State<CompanyNewsScreen> createState() => _CompanyNewsScreenState();
// }

// class _CompanyNewsScreenState extends State<CompanyNewsScreen> {
//   List<Map<String, dynamic>> _news = [];
//   Map<String, dynamic>? _stockData;
//   bool _isLoading = false;
//   bool _isLoadingStock = false;
//   String _error = '';
//   String _stockError = '';

//   @override
//   void initState() {
//     super.initState();
//     _fetchStockData();
//     _fetchCompanyNews();
//   }

//   Future<void> _fetchStockData() async {
//     setState(() {
//       _isLoadingStock = true;
//       _stockError = '';
//     });

//     try {
//       // Use the companySymbol passed from previous screen
//       final companySymbol = widget.companySymbol.toUpperCase(); // CHANGE THIS LINE
//       final response = await http.get(
//         Uri.parse(
//             "https://eodhd.com/api/eod/$companySymbol.NSE?api_token=693c20d12c22f5.65029013&fmt=json&limit=1"),
//       );

//       if (response.statusCode == 200) {
//         final List<dynamic> data = json.decode(response.body);
//         if (data.isNotEmpty) {
//           setState(() {
//             _stockData = data.last;
//           });
//         } else {
//           setState(() {
//             _stockError = "No stock data available";
//           });
//         }
//       } else {
//         setState(() {
//           _stockError = "Failed to fetch stock data (${response.statusCode})";
//         });
//       }
//     } catch (e) {
//       setState(() {
//         _stockError = "Stock data fetch failed: $e";
//       });
//     }

//     setState(() => _isLoadingStock = false);
//   }

//   Future<void> _fetchCompanyNews() async {
//     setState(() {
//       _isLoading = true;
//       _error = '';
//     });

//     try {
//       // URL encode the company name (you can change to symbol if backend expects it)
//       final encodedName = Uri.encodeComponent(widget.companyName);
//       final resp = await http.get(Uri.parse(
//           "http://192.168.1.7:5000/api/filtered-news/company/$encodedName"));

//       if (resp.statusCode == 200) {
//         final data = json.decode(resp.body);
//         setState(() {
//           _news = (data as List).cast<Map<String, dynamic>>();
//         });
//       } else {
//         final errorBody = resp.body;
//         setState(() {
//           _error =
//               "Failed to fetch news\nStatus: ${resp.statusCode}\nError: $errorBody";
//         });
//       }
//     } catch (e) {
//       setState(() {
//         _error = "DB fetch failed: $e";
//       });
//     }

//     setState(() => _isLoading = false);
//   }

//   String _formatDate(String? dateString) {
//     if (dateString == null || dateString.isEmpty) return "Date not available";
//     try {
//       // Try parsing the date format: "Friday, Oct 17, 2025 18:08:38"
//       final date = DateFormat("EEEE, MMM dd, yyyy HH:mm:ss").parse(dateString);
//       return DateFormat.yMMMd().add_jm().format(date);
//     } catch (e) {
//       // If parsing fails, return the original string
//       return dateString;
//     }
//   }

//   String _formatStockDate(String? dateString) {
//     if (dateString == null || dateString.isEmpty) return "N/A";
//     try {
//       final date = DateTime.parse(dateString);
//       return DateFormat('MMM dd, yyyy').format(date);
//     } catch (e) {
//       return dateString;
//     }
//   }

//   Color _getPriceChangeColor(double? change, double? changePercent) {
//     if (change == null || changePercent == null) return Colors.grey;
//     if (change > 0) return Colors.green;
//     if (change < 0) return Colors.red;
//     return Colors.grey;
//   }

//   IconData _getPriceChangeIcon(double? change) {
//     if (change == null) return Icons.horizontal_rule;
//     if (change > 0) return Icons.arrow_upward;
//     if (change < 0) return Icons.arrow_downward;
//     return Icons.horizontal_rule;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF6F7FA),
//       appBar: AppBar(
//         title: const Text("Company News"),
//         backgroundColor: const Color(0xFFEA6B6B),
//         foregroundColor: Colors.white,
//       ),
//       body: SafeArea(
//         child: Column(
//           children: [
//             // Company Name Header
//             Container(
//               width: double.infinity,
//               padding: const EdgeInsets.all(20),
//               decoration: BoxDecoration(
//                 color: const Color(0xFFEA6B6B),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.grey.withOpacity(0.2),
//                     blurRadius: 4,
//                     offset: const Offset(0, 2),
//                   ),
//                 ],
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text(
//                     "Company:",
//                     style: TextStyle(
//                       color: Colors.white70,
//                       fontSize: 14,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                   const SizedBox(height: 6),
//                   Text(
//                     widget.companyName,
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 22,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     "Symbol: ${widget.companySymbol.toUpperCase()}",
//                     style: const TextStyle(
//                       color: Colors.white70,
//                       fontSize: 14,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             // Stock Data Card
//             Container(
//               padding: const EdgeInsets.all(16),
//               margin: const EdgeInsets.all(14),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(14),
//                 border: Border.all(color: Colors.grey.shade200),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.grey.withOpacity(0.08),
//                     blurRadius: 12,
//                     offset: const Offset(0, 4),
//                   ),
//                 ],
//               ),
//               child: _isLoadingStock
//                   ? const Center(
//                       child: Padding(
//                         padding: EdgeInsets.symmetric(vertical: 20),
//                         child: CircularProgressIndicator(),
//                       ),
//                     )
//                   : _stockError.isNotEmpty
//                       ? Column(
//                           children: [
//                             Text(
//                               _stockError,
//                               style: const TextStyle(color: Colors.red),
//                               textAlign: TextAlign.center,
//                             ),
//                             const SizedBox(height: 8),
//                             ElevatedButton(
//                               onPressed: _fetchStockData,
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: const Color(0xFFEA6B6B),
//                                 foregroundColor: Colors.white,
//                               ),
//                               child: const Text("Retry Stock Data"),
//                             ),
//                           ],
//                         )
//                       : _stockData == null
//                           ? const Center(
//                               child: Text("No stock data available"),
//                             )
//                           : Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 // Stock Header
//                                 Row(
//                                   mainAxisAlignment:
//                                       MainAxisAlignment.spaceBetween,
//                                   children: [
//                                     Text(
//                                       "${widget.companySymbol.toUpperCase()}.NSE", // CHANGED THIS LINE
//                                       style: const TextStyle(
//                                         fontSize: 16,
//                                         fontWeight: FontWeight.bold,
//                                         color: Color(0xFF2D3748),
//                                       ),
//                                     ),
//                                     Text(
//                                       _formatStockDate(_stockData!['date']),
//                                       style: TextStyle(
//                                         fontSize: 12,
//                                         color: Colors.grey.shade600,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                                 const SizedBox(height: 16),
//                                 // Stock Prices
//                                 Row(
//                                   mainAxisAlignment:
//                                       MainAxisAlignment.spaceBetween,
//                                   children: [
//                                     Column(
//                                       crossAxisAlignment:
//                                           CrossAxisAlignment.start,
//                                       children: [
//                                         Text(
//                                           "Open",
//                                           style: TextStyle(
//                                             fontSize: 12,
//                                             color: Colors.grey.shade600,
//                                           ),
//                                         ),
//                                         const SizedBox(height: 4),
//                                         Text(
//                                           "₹${_stockData!['open']?.toStringAsFixed(2) ?? 'N/A'}",
//                                           style: const TextStyle(
//                                             fontSize: 16,
//                                             fontWeight: FontWeight.w600,
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                     Column(
//                                       crossAxisAlignment:
//                                           CrossAxisAlignment.start,
//                                       children: [
//                                         Text(
//                                           "High",
//                                           style: TextStyle(
//                                             fontSize: 12,
//                                             color: Colors.grey.shade600,
//                                           ),
//                                         ),
//                                         const SizedBox(height: 4),
//                                         Text(
//                                           "₹${_stockData!['high']?.toStringAsFixed(2) ?? 'N/A'}",
//                                           style: const TextStyle(
//                                             fontSize: 16,
//                                             fontWeight: FontWeight.w600,
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                     Column(
//                                       crossAxisAlignment:
//                                           CrossAxisAlignment.start,
//                                       children: [
//                                         Text(
//                                           "Low",
//                                           style: TextStyle(
//                                             fontSize: 12,
//                                             color: Colors.grey.shade600,
//                                           ),
//                                         ),
//                                         const SizedBox(height: 4),
//                                         Text(
//                                           "₹${_stockData!['low']?.toStringAsFixed(2) ?? 'N/A'}",
//                                           style: const TextStyle(
//                                             fontSize: 16,
//                                             fontWeight: FontWeight.w600,
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                     Column(
//                                       crossAxisAlignment:
//                                           CrossAxisAlignment.start,
//                                       children: [
//                                         Text(
//                                           "Close",
//                                           style: TextStyle(
//                                             fontSize: 12,
//                                             color: Colors.grey.shade600,
//                                           ),
//                                         ),
//                                         const SizedBox(height: 4),
//                                         Text(
//                                           "₹${_stockData!['close']?.toStringAsFixed(2) ?? 'N/A'}",
//                                           style: const TextStyle(
//                                             fontSize: 16,
//                                             fontWeight: FontWeight.w600,
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ],
//                                 ),
//                                 const SizedBox(height: 16),
//                                 // Price Change and Volume
//                                 Row(
//                                   mainAxisAlignment:
//                                       MainAxisAlignment.spaceBetween,
//                                   children: [
//                                     // Price Change
//                                     Column(
//                                       crossAxisAlignment:
//                                           CrossAxisAlignment.start,
//                                       children: [
//                                         Text(
//                                           "Change",
//                                           style: TextStyle(
//                                             fontSize: 12,
//                                             color: Colors.grey.shade600,
//                                           ),
//                                         ),
//                                         const SizedBox(height: 4),
//                                         Row(
//                                           children: [
//                                             Icon(
//                                               _getPriceChangeIcon(
//                                                   _stockData!['change']),
//                                               size: 16,
//                                               color: _getPriceChangeColor(
//                                                 _stockData!['change'],
//                                                 _stockData!['change_pct'],
//                                               ),
//                                             ),
//                                             const SizedBox(width: 4),
//                                             Text(
//                                               "${_stockData!['change']?.toStringAsFixed(2) ?? '0.00'} (${_stockData!['change_pct']?.toStringAsFixed(2) ?? '0.00'}%)",
//                                               style: TextStyle(
//                                                 fontSize: 16,
//                                                 fontWeight: FontWeight.w600,
//                                                 color: _getPriceChangeColor(
//                                                   _stockData!['change'],
//                                                   _stockData!['change_pct'],
//                                                 ),
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ],
//                                     ),
//                                     // Volume
//                                     Column(
//                                       crossAxisAlignment:
//                                           CrossAxisAlignment.end,
//                                       children: [
//                                         Text(
//                                           "Volume",
//                                           style: TextStyle(
//                                             fontSize: 12,
//                                             color: Colors.grey.shade600,
//                                           ),
//                                         ),
//                                         const SizedBox(height: 4),
//                                         Text(
//                                           _stockData!['volume'] != null
//                                               ? '${(_stockData!['volume'] / 1000).toStringAsFixed(1)}K'
//                                               : 'N/A',
//                                           style: const TextStyle(
//                                             fontSize: 16,
//                                             fontWeight: FontWeight.w600,
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ],
//                                 ),
//                               ],
//                             ),
//             ),
//             // News List Header
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16.0),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   const Text(
//                     "Latest News",
//                     style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                       color: Color(0xFF2D3748),
//                     ),
//                   ),
//                   IconButton(
//                     onPressed: () {
//                       _fetchStockData();
//                       _fetchCompanyNews();
//                     },
//                     icon: const Icon(Icons.refresh),
//                     tooltip: "Refresh",
//                   ),
//                 ],
//               ),
//             ),
//             // News List
//             Expanded(
//               child: _isLoading
//                   ? const Center(child: CircularProgressIndicator())
//                   : _error.isNotEmpty
//                       ? Center(
//                           child: Column(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: [
//                               Text(
//                                 _error,
//                                 style: const TextStyle(color: Colors.red),
//                                 textAlign: TextAlign.center,
//                               ),
//                               const SizedBox(height: 16),
//                               ElevatedButton(
//                                 onPressed: _fetchCompanyNews,
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: const Color(0xFFEA6B6B),
//                                   foregroundColor: Colors.white,
//                                 ),
//                                 child: const Text("Retry News"),
//                               ),
//                             ],
//                           ),
//                         )
//                       : _news.isEmpty
//                           ? const Center(
//                               child: Text("No news found for this company"))
//                           : RefreshIndicator(
//                               onRefresh: () async {
//                                 await _fetchStockData();
//                                 await _fetchCompanyNews();
//                               },
//                               child: ListView.builder(
//                                 padding: const EdgeInsets.symmetric(
//                                     vertical: 10, horizontal: 14),
//                                 itemCount: _news.length,
//                                 itemBuilder: (context, index) {
//                                   final article = _news[index];
//                                   final headline =
//                                       article["Headline"] ?? "No headline";
//                                   final publishedAt =
//                                       article["PublishedAt"] ?? "";
//                                   final summary = article["summary"] ?? "";

//                                   return Padding(
//                                     padding: const EdgeInsets.only(bottom: 10),
//                                     child: Container(
//                                       padding: const EdgeInsets.all(16),
//                                       decoration: BoxDecoration(
//                                         color: Colors.white,
//                                         borderRadius: BorderRadius.circular(14),
//                                         border: Border.all(
//                                             color: Colors.grey.shade200),
//                                         boxShadow: [
//                                           BoxShadow(
//                                             color: Colors.grey.withOpacity(0.06),
//                                             blurRadius: 8,
//                                           ),
//                                         ],
//                                       ),
//                                       child: Column(
//                                         crossAxisAlignment:
//                                             CrossAxisAlignment.start,
//                                         children: [
//                                           // Headline
//                                           Text(
//                                             headline,
//                                             style: const TextStyle(
//                                               fontSize: 17,
//                                               fontWeight: FontWeight.bold,
//                                             ),
//                                           ),
//                                           const SizedBox(height: 10),
//                                           // Published Date
//                                           Row(
//                                             children: [
//                                               Icon(Icons.calendar_today,
//                                                   size: 14,
//                                                   color: Colors.grey.shade600),
//                                               const SizedBox(width: 6),
//                                               Text(
//                                                 _formatDate(publishedAt),
//                                                 style: TextStyle(
//                                                   fontSize: 12,
//                                                   color: Colors.grey.shade600,
//                                                 ),
//                                               ),
//                                             ],
//                                           ),
//                                           const SizedBox(height: 12),
//                                           // Summary
//                                           if (summary.isNotEmpty) ...[
//                                             const Text(
//                                               "Summary:",
//                                               style: TextStyle(
//                                                 fontSize: 14,
//                                                 fontWeight: FontWeight.w600,
//                                                 color: Color(0xFFEA6B6B),
//                                               ),
//                                             ),
//                                             const SizedBox(height: 6),
//                                             Text(
//                                               summary,
//                                               style: TextStyle(
//                                                 fontSize: 14,
//                                                 color: Colors.grey.shade800,
//                                                 height: 1.5,
//                                               ),
//                                             ),
//                                           ],
//                                         ],
//                                       ),
//                                     ),
//                                   );
//                                 },
//                               ),
//                             ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
