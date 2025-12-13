import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class CompanyNewsScreen extends StatefulWidget {
  final String companyName;
  final String companySymbol; // ADD THIS FIELD

  const CompanyNewsScreen({
    super.key, 
    required this.companyName,
    required this.companySymbol, // ADD THIS PARAMETER
  });

  @override
  State<CompanyNewsScreen> createState() => _CompanyNewsScreenState();
}

class _CompanyNewsScreenState extends State<CompanyNewsScreen> {
  List<Map<String, dynamic>> _news = [];
  Map<String, dynamic>? _stockData;
  bool _isLoading = false;
  bool _isLoadingStock = false;
  String _error = '';
  String _stockError = '';

  @override
  void initState() {
    super.initState();
    _fetchStockData();
    _fetchCompanyNews();
  }

  Future<void> _fetchStockData() async {
    setState(() {
      _isLoadingStock = true;
      _stockError = '';
    });

    try {
      // Use the companySymbol passed from previous screen
      final companySymbol = widget.companySymbol.toUpperCase(); // CHANGE THIS LINE
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
      // URL encode the company name (you can change to symbol if backend expects it)
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

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "Date not available";
    try {
      // Try parsing the date format: "Friday, Oct 17, 2025 18:08:38"
      final date = DateFormat("EEEE, MMM dd, yyyy HH:mm:ss").parse(dateString);
      return DateFormat.yMMMd().add_jm().format(date);
    } catch (e) {
      // If parsing fails, return the original string
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

  Color _getPriceChangeColor(double? change, double? changePercent) {
    if (change == null || changePercent == null) return Colors.grey;
    if (change > 0) return Colors.green;
    if (change < 0) return Colors.red;
    return Colors.grey;
  }

  IconData _getPriceChangeIcon(double? change) {
    if (change == null) return Icons.horizontal_rule;
    if (change > 0) return Icons.arrow_upward;
    if (change < 0) return Icons.arrow_downward;
    return Icons.horizontal_rule;
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
      body: SafeArea(
        child: Column(
          children: [
            // Company Name Header
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
            // Stock Data Card
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(14),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Stock Header
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "${widget.companySymbol.toUpperCase()}.NSE", // CHANGED THIS LINE
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
                                // Stock Prices
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Open",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "₹${_stockData!['open']?.toStringAsFixed(2) ?? 'N/A'}",
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "High",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "₹${_stockData!['high']?.toStringAsFixed(2) ?? 'N/A'}",
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Low",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "₹${_stockData!['low']?.toStringAsFixed(2) ?? 'N/A'}",
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Close",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "₹${_stockData!['close']?.toStringAsFixed(2) ?? 'N/A'}",
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Price Change and Volume
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Price Change
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Change",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              _getPriceChangeIcon(
                                                  _stockData!['change']),
                                              size: 16,
                                              color: _getPriceChangeColor(
                                                _stockData!['change'],
                                                _stockData!['change_pct'],
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              "${_stockData!['change']?.toStringAsFixed(2) ?? '0.00'} (${_stockData!['change_pct']?.toStringAsFixed(2) ?? '0.00'}%)",
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: _getPriceChangeColor(
                                                  _stockData!['change'],
                                                  _stockData!['change_pct'],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    // Volume
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          "Volume",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _stockData!['volume'] != null
                                              ? '${(_stockData!['volume'] / 1000).toStringAsFixed(1)}K'
                                              : 'N/A',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
            ),
            // News List Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                    },
                    icon: const Icon(Icons.refresh),
                    tooltip: "Refresh",
                  ),
                ],
              ),
            ),
            // News List
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
                                onPressed: _fetchCompanyNews,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEA6B6B),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text("Retry News"),
                              ),
                            ],
                          ),
                        )
                      : _news.isEmpty
                          ? const Center(
                              child: Text("No news found for this company"))
                          : RefreshIndicator(
                              onRefresh: () async {
                                await _fetchStockData();
                                await _fetchCompanyNews();
                              },
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 14),
                                itemCount: _news.length,
                                itemBuilder: (context, index) {
                                  final article = _news[index];
                                  final headline =
                                      article["Headline"] ?? "No headline";
                                  final publishedAt =
                                      article["PublishedAt"] ?? "";
                                  final summary = article["summary"] ?? "";

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                            color: Colors.grey.shade200),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.grey.withOpacity(0.06),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Headline
                                          Text(
                                            headline,
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          // Published Date
                                          Row(
                                            children: [
                                              Icon(Icons.calendar_today,
                                                  size: 14,
                                                  color: Colors.grey.shade600),
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
                                          const SizedBox(height: 12),
                                          // Summary
                                          if (summary.isNotEmpty) ...[
                                            const Text(
                                              "Summary:",
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
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';

// class CompanyNewsScreen extends StatefulWidget {
//   final String companyName;

//   const CompanyNewsScreen({super.key, required this.companyName});

//   @override
//   State<CompanyNewsScreen> createState() => _CompanyNewsScreenState();
// }

// class _CompanyNewsScreenState extends State<CompanyNewsScreen> {
//   List<Map<String, dynamic>> _news = [];
//   bool _isLoading = false;
//   String _error = '';

//   @override
//   void initState() {
//     super.initState();
//     _fetchCompanyNews();
//   }

//   Future<void> _fetchCompanyNews() async {
//     setState(() {
//       _isLoading = true;
//       _error = '';
//     });

//     try {
//       // URL encode the company name
//       final encodedName = Uri.encodeComponent(widget.companyName);
//       final resp = await http.get(
//           Uri.parse("http://192.168.1.7:5000/api/filtered-news/company/$encodedName"));

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
//                                 child: const Text("Retry"),
//                               ),
//                             ],
//                           ),
//                         )
//                       : _news.isEmpty
//                           ? const Center(child: Text("No news found for this company"))
//                           : RefreshIndicator(
//                               onRefresh: _fetchCompanyNews,
//                               child: ListView.builder(
//                                 padding: const EdgeInsets.symmetric(vertical: 10),
//                                 itemCount: _news.length,
//                                 itemBuilder: (context, index) {
//                                   final article = _news[index];
//                                   final headline = article["Headline"] ?? "No headline";
//                                   final publishedAt = article["PublishedAt"] ?? "";
//                                   final summary = article["summary"] ?? "";

//                                   return Padding(
//                                     padding: const EdgeInsets.symmetric(
//                                         horizontal: 14.0, vertical: 8),
//                                     child: Container(
//                                       padding: const EdgeInsets.all(16),
//                                       decoration: BoxDecoration(
//                                         color: Colors.white,
//                                         borderRadius: BorderRadius.circular(14),
//                                         border: Border.all(color: Colors.grey.shade200),
//                                         boxShadow: [
//                                           BoxShadow(
//                                             color: Colors.grey.withOpacity(0.06),
//                                             blurRadius: 8,
//                                           ),
//                                         ],
//                                       ),
//                                       child: Column(
//                                         crossAxisAlignment: CrossAxisAlignment.start,
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