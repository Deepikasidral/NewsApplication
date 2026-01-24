import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'home_screen.dart';
import 'chatbot_screen.dart';
import 'company_screen.dart';
import 'events_screen.dart';
import 'saved_screen.dart';
import 'profile_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

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

class _CompanyNewsScreenState extends State<CompanyNewsScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _news = [];
  Map<String, dynamic>? _stockData;
  Map<String, dynamic>? _aiOverview;
  Map<String, dynamic>? _aiInsight;
  List<Map<String, dynamic>> _companyEvents = [];
  bool _isLoading = false;
  bool _isLoadingStock = false;
  bool _isLoadingAI = false;
  bool _isLoadingInsight = false;
  bool _isLoadingEvents = false;
  String _error = '';
  String _stockError = '';
  String _aiError = '';
  String _insightError = '';
  String _eventsError = '';
  
  late TabController _tabController;
  int _selectedTabIndex = 0;
  int _bottomIndex = 2;

  List<Map<String, dynamic>> _chartData = [];
  bool _isLoadingChart = false;
  String _chartError = '';
  String _selectedTimeframe = '1M';
  WebViewController? _webViewController;
  bool _chartInitialized = false;

  final String _finedgeApiToken = dotenv.env['FINEDGE_API_TOKEN']!;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    });
    
    // Initialize WebViewController once
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            setState(() {
              _chartInitialized = true;
            });
          },
        ),
      );
    
    _fetchStockData();
    _fetchCompanyNews();
    _fetchAIOverview();
    _fetchAIInsight();
    _fetchChartData('1M');
    _fetchCompanyEvents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchStockData() async {
    setState(() {
      _isLoadingStock = true;
      _stockError = '';
    });

    try {
      var symbol = widget.companySymbol.toUpperCase();
      
      // Remove .NSE or .BSE suffix if present
      if (symbol.endsWith('.NSE') || symbol.endsWith('.BSE')) {
        symbol = symbol.split('.').first;
      }
      
      print('==========================================');
      print('Fetching stock data for symbol: $symbol');
      print('==========================================');
      
      // Add retry logic with exponential backoff
      int retries = 3;
      int delayMs = 1000;
      http.Response? quoteResponse;
      
      for (int i = 0; i < retries; i++) {
        try {
          quoteResponse = await http.get(
            Uri.parse("https://data.finedgeapi.com/api/v1/quote").replace(
              queryParameters: {'symbol': symbol, 'token': _finedgeApiToken}
            ),
            headers: {'Accept': 'application/json'}
          ).timeout(const Duration(seconds: 10));

          print('Quote API Status: ${quoteResponse.statusCode}');
          
          if (quoteResponse.statusCode == 200) {
            break; // Success
          } else if (quoteResponse.statusCode == 503 || quoteResponse.statusCode == 429) {
            print('Rate limited. Retrying in ${delayMs}ms... (Attempt ${i + 1}/$retries)');
            if (i < retries - 1) {
              await Future.delayed(Duration(milliseconds: delayMs));
              delayMs *= 2; // Exponential backoff
            }
          } else {
            break; // Other error
          }
        } catch (e) {
          if (i == retries - 1) rethrow;
          print('Request failed: $e. Retrying...');
          await Future.delayed(Duration(milliseconds: delayMs));
          delayMs *= 2;
        }
      }

      if (quoteResponse == null || quoteResponse.statusCode != 200) {
        setState(() {
          _stockError = quoteResponse?.statusCode == 503 || quoteResponse?.statusCode == 429
              ? "Rate limit exceeded. Please wait and try again."
              : "Failed to fetch quote data (${quoteResponse?.statusCode ?? 'timeout'})";
        });
        return;
      }

      print('Quote API Response: ${quoteResponse.body}');

      final quoteJson = json.decode(quoteResponse.body);
      
      dynamic quoteData;
      if (quoteJson is Map) {
        quoteData = quoteJson[symbol] ?? quoteJson[symbol.toLowerCase()] ?? 
                   quoteJson['data'] ?? quoteJson;
      } else {
        quoteData = quoteJson;
      }
      
      if (quoteData == null || (quoteData is! Map && quoteData is! List)) {
        setState(() {
          _stockError = "Invalid data format for symbol: $symbol";
        });
        return;
      }

      if (quoteData is List && quoteData.isNotEmpty) {
        quoteData = quoteData.first;
      }

      final currentPrice = quoteData['current_price'] ?? 
                          quoteData['last_price'] ?? 
                          quoteData['ltp'] ?? 
                          quoteData['close'] ??
                          quoteData['lastPrice'];
      final high = quoteData['high_price'] ?? 
                  quoteData['high'] ?? 
                  quoteData['dayHigh'];
      final low = quoteData['low_price'] ?? 
                 quoteData['low'] ?? 
                 quoteData['dayLow'];
      final open = quoteData['open_price'] ?? 
                  quoteData['open'] ?? 
                  quoteData['openPrice'];
      final changePercent = quoteData['change'] ?? 
                           quoteData['pChange'] ?? 
                           quoteData['percentChange'] ??
                           quoteData['changePct'];
      final volume = quoteData['volume'] ?? 
                    quoteData['totalTradedVolume'];

      double? changeValue;
      double? changePct;
      if (changePercent != null) {
        try {
          changePct = double.parse(changePercent.toString().replaceAll('%', '').trim());
          if (currentPrice != null && open != null) {
            changeValue = double.parse(currentPrice.toString()) - double.parse(open.toString());
          }
        } catch (e) {
          print('Error parsing change percent: $e');
        }
      }

      // 2. GET /annual-price-ratios - Add retry logic here too
      String? eps;
      String? peRatio;

      try {
        print('\n--- Fetching Price Ratios for EPS and P/E ---');
        
        // Add delay before next API call
        await Future.delayed(const Duration(milliseconds: 500));
        
        final priceRatiosUrl = Uri.parse(
          "https://data.finedgeapi.com/api/v1/annual-price-ratios/$symbol"
        ).replace(queryParameters: {
          'token': _finedgeApiToken,
          'statement_type': 's',
        });

        final priceRatiosResponse = await http.get(
          priceRatiosUrl,
          headers: {'Accept': 'application/json'}
        ).timeout(const Duration(seconds: 10));

        print('Price Ratios Status: ${priceRatiosResponse.statusCode}');
        
        if (priceRatiosResponse.statusCode == 200 && priceRatiosResponse.body.isNotEmpty) {
          final ratiosData = json.decode(priceRatiosResponse.body);
          print('Full Ratios Response: $ratiosData');
          
          // Extract from price_ratios array
          dynamic ratiosList = ratiosData['price_ratios'];
          print('Extracted ratiosList: $ratiosList');
          
          if (ratiosList != null && ratiosList is List && ratiosList.isNotEmpty) {
            final latest = ratiosList.first;
            print('Latest ratio entry keys: ${latest.keys.toList()}');
            print('Latest ratio entry: $latest');
            
            // Extract P/E Ratio
            final peValue = latest['pe'] ?? 
                           latest['priceToEarnings'] ?? 
                           latest['PE'] ??
                           latest['peRatio'] ??
                           latest['priceEarningsRatio'];
            if (peValue != null) {
              peRatio = double.parse(peValue.toString()).toStringAsFixed(2);
              print('✓ Found P/E: $peRatio');
            } else {
              print('✗ P/E not found in: ${latest.keys.toList()}');
            }
          } else {
            print('✗ No ratios list found or empty');
          }
        }
      } catch (e) {
        print('ERROR fetching price ratios: $e');
      }

      // 3. GET /financials - Add retry logic here too
      String? revenue;
      String? ebitda;
      String? ebit;
      String? netProfit;

      try {
        print('\n--- Fetching Financials ---');
        
        // Add delay before next API call
        await Future.delayed(const Duration(milliseconds: 500));
        
        final financialsUrl = Uri.parse(
          "https://data.finedgeapi.com/api/v1/financials/$symbol"
        ).replace(queryParameters: {
          'token': _finedgeApiToken,
          'statement_type': 's',
          'statement_code': 'pl',
          'period': 'annual',
        });

        final financialsResponse = await http.get(
          financialsUrl,
          headers: {'Accept': 'application/json'}
        ).timeout(const Duration(seconds: 10));

        print('Financials Status: ${financialsResponse.statusCode}');

        if (financialsResponse.statusCode == 200 && financialsResponse.body.isNotEmpty) {
          final finData = json.decode(financialsResponse.body);
          print('Financials Data Type: ${finData.runtimeType}');
          
          dynamic financialsList;
          if (finData is Map) {
            financialsList = finData['financials'] ?? finData['data'] ?? finData['results'];
            print('Extracted financialsList: ${financialsList?.runtimeType}');
          } else if (finData is List) {
            financialsList = finData;
          }
          
          if (financialsList != null && financialsList is List && financialsList.isNotEmpty) {
            final latest = financialsList.first;
            print('Latest financial entry keys: ${latest.keys.toList()}');
            print('Latest financial entry values sample: ${latest.entries.take(5).toList()}');
            
            // Improved bank detection: Check for MULTIPLE bank-specific indicators
            // Regular companies may have 'income' field but won't have bank-specific fields
            final isBank = (latest.containsKey('interestEarned') && 
                           latest.containsKey('interestExpended')) ||
                          (latest.containsKey('netInterestIncome')) ||
                          (latest.containsKey('income') && 
                           !latest.containsKey('revenueFromOperations') &&
                           !latest.containsKey('costofGoodsSold'));
            
            if (isBank) {
              print('Detected: BANK/FINANCIAL INSTITUTION');
              
              // For banks: Revenue = Total Income
              final totalIncome = latest['income'] ?? 
                                 latest['totalIncome'] ??
                                 latest['operatingIncome'];
              if (totalIncome != null) {
                final revValue = double.parse(totalIncome.toString()) / 10000000;
                revenue = revValue.toStringAsFixed(2);
                print('✓ Found Total Income (Revenue): $revenue Cr');
              }
              
              // For banks: Net Profit
              final netIncome = latest['profitLossForThePeriod'] ??
                               latest['profitLossForPeriod'] ??
                               latest['netProfit'] ??
                               latest['profitAfterTax'];
              if (netIncome != null) {
                final npValue = double.parse(netIncome.toString()) / 10000000;
                netProfit = npValue.toStringAsFixed(2);
                print('✓ Found Net Profit: $netProfit Cr');
              }
              
              // For banks: Operating Profit can be used as EBIT equivalent
              final operatingProfit = latest['profitLossBeforeTax'] ??
                                     latest['profitBeforeTax'];
              if (operatingProfit != null) {
                final ebitValue = double.parse(operatingProfit.toString()) / 10000000;
                ebit = ebitValue.toStringAsFixed(2);
                print('✓ Found Operating Profit (EBIT): $ebit Cr');
              }
              
              // EBITDA not typically applicable for banks
              ebitda = 'N/A (Bank)';
              
            } else {
              print('Detected: REGULAR COMPANY');
              
              // Extract Revenue (for regular companies)
              final totalRev = latest['revenueFromOperations'] ?? 
                              latest['totalRevenue'] ?? 
                              latest['revenue'] ?? 
                              latest['operatingRevenue'] ??
                              latest['netRevenue'] ??
                              latest['Revenue'] ??
                              latest['totalIncome'];
              if (totalRev != null) {
                final revValue = double.parse(totalRev.toString()) / 10000000;
                revenue = revValue.toStringAsFixed(2);
                print('✓ Found Revenue: $revenue Cr');
              } else {
                print('✗ Revenue not found. Available keys: ${latest.keys.toList()}');
              }
              
              // Extract Net Profit
              final netIncome = latest['profitLossForPeriod'] ??
                               latest['profitLossForThePeriod'] ??
                               latest['netIncome'] ?? 
                               latest['netProfit'] ??
                               latest['profitAfterTax'] ??
                               latest['Net Profit'] ??
                               latest['netIncomeAfterTax'];
              if (netIncome != null) {
                final npValue = double.parse(netIncome.toString()) / 10000000;
                netProfit = npValue.toStringAsFixed(2);
                print('✓ Found Net Profit: $netProfit Cr');
              } else {
                print('✗ Net Profit not found');
              }
              
              // Calculate EBITDA
              try {
                final pbt = latest['profitBeforeTax'];
                final finCosts = latest['financeCosts'];
                final depreciation = latest['depreciationAndAmortisation'];
                
                if (pbt != null && finCosts != null && depreciation != null) {
                  final ebitdaValue = (double.parse(pbt.toString()) + 
                                      double.parse(finCosts.toString()) + 
                                      double.parse(depreciation.toString())) / 10000000;
                  ebitda = ebitdaValue.toStringAsFixed(2);
                  print('✓ Calculated EBITDA: $ebitda Cr');
                }
              } catch (e) {
                print('Could not calculate EBITDA: $e');
              }
              
              // Calculate EBIT
              try {
                final pbt = latest['profitBeforeTax'];
                final finCosts = latest['financeCosts'];
                
                if (pbt != null && finCosts != null) {
                  final ebitValue = (double.parse(pbt.toString()) + 
                                    double.parse(finCosts.toString())) / 10000000;
                  ebit = ebitValue.toStringAsFixed(2);
                  print('✓ Calculated EBIT: $ebit Cr');
                }
              } catch (e) {
                print('Could not calculate EBIT: $e');
              }
            }
            
            // Extract EPS (common for both)
            final epsValue = latest['eps'] ?? 
                            latest['earningsPerShare'] ?? 
                            latest['EPS'] ??
                            latest['basicEPS'];
            if (epsValue != null) {
              eps = double.parse(epsValue.toString()).toStringAsFixed(2);
              print('✓ Found EPS: $eps');
            } else {
              print('✗ EPS not found');
            }
          } else {
            print('✗ No financials list found or empty');
          }
        }
      } catch (e, stack) {
        print('ERROR fetching financials: $e');
        print('Stack: $stack');
      }

      // 4. GET /basic-financials - Balance Sheet
      String? totalAssets;
      String? totalLiabilities;
      String? longTermDebt;
      String? shareholdersEquity;
      String? cashEquivalents;

      try {
        print('\n--- Fetching Balance Sheet ---');
        await Future.delayed(const Duration(milliseconds: 500));
        
        final bsUrl = Uri.parse(
          "https://data.finedgeapi.com/api/v1/basic-financials/$symbol"
        ).replace(queryParameters: {
          'token': _finedgeApiToken,
          'statement_type': 's',
          'statement_code': 'bs',
        });

        final bsResponse = await http.get(
          bsUrl,
          headers: {'Accept': 'application/json'}
        ).timeout(const Duration(seconds: 10));

        print('Balance Sheet Status: ${bsResponse.statusCode}');

        if (bsResponse.statusCode == 200 && bsResponse.body.isNotEmpty) {
          final bsData = json.decode(bsResponse.body);
          
          dynamic bsList = bsData['ratios'];
          
          if (bsList != null && bsList is List && bsList.isNotEmpty) {
            final latest = bsList.first;
            print('Balance Sheet keys: ${latest.keys.toList()}');
            
            // Total Assets
            final assets = latest['totalAssets'];
            if (assets != null) {
              totalAssets = (double.parse(assets.toString()) / 10000000).toStringAsFixed(2);
              print('✓ Found Total Assets: $totalAssets Cr');
            }
            
            // Total Liabilities
            final liabilities = latest['totalLiabilities'];
            if (liabilities != null) {
              totalLiabilities = (double.parse(liabilities.toString()) / 10000000).toStringAsFixed(2);
              print('✓ Found Total Liabilities: $totalLiabilities Cr');
            }
            
            // Long-term Debt
            final debt = latest['longTermBorrowings'] ?? latest['totalDebt'];
            if (debt != null) {
              longTermDebt = (double.parse(debt.toString()) / 10000000).toStringAsFixed(2);
              print('✓ Found Long-Term Debt: $longTermDebt Cr');
            }
            
            // Shareholders' Equity
            final equity = latest['totalEquity'];
            if (equity != null) {
              shareholdersEquity = (double.parse(equity.toString()) / 10000000).toStringAsFixed(2);
              print('✓ Found Shareholders Equity: $shareholdersEquity Cr');
            }
            
            // Cash & Equivalents
            final cash = latest['totalCash'];
            if (cash != null) {
              cashEquivalents = (double.parse(cash.toString()) / 10000000).toStringAsFixed(2);
              print('✓ Found Cash & Equivalents: $cashEquivalents Cr');
            }
          }
        }
      } catch (e) {
        print('ERROR fetching balance sheet: $e');
      }

      // 5. GET /basic-financials - Cash Flow
      String? operatingCashFlow;
      String? investingCashFlow;
      String? financingCashFlow;

      try {
        print('\n--- Fetching Cash Flow ---');
        await Future.delayed(const Duration(milliseconds: 500));
        
        final cfUrl = Uri.parse(
          "https://data.finedgeapi.com/api/v1/basic-financials/$symbol"
        ).replace(queryParameters: {
          'token': _finedgeApiToken,
          'statement_type': 's',
          'statement_code': 'cf',
        });

        final cfResponse = await http.get(
          cfUrl,
          headers: {'Accept': 'application/json'}
        ).timeout(const Duration(seconds: 10));

        print('Cash Flow Status: ${cfResponse.statusCode}');

        if (cfResponse.statusCode == 200 && cfResponse.body.isNotEmpty) {
          final cfData = json.decode(cfResponse.body);
          
          dynamic cfList = cfData['ratios'];
          
          if (cfList != null && cfList is List && cfList.isNotEmpty) {
            final latest = cfList.first;
            print('Cash Flow keys: ${latest.keys.toList()}');
            
            // Operating Cash Flow
            final opCF = latest['operatingCashFlow'];
            if (opCF != null) {
              operatingCashFlow = (double.parse(opCF.toString()) / 10000000).toStringAsFixed(2);
              print('✓ Found Operating Cash Flow: $operatingCashFlow Cr');
            }
            
            // Investing Cash Flow
            final invCF = latest['investingCashFlow'];
            if (invCF != null) {
              investingCashFlow = (double.parse(invCF.toString()) / 10000000).toStringAsFixed(2);
              print('✓ Found Investing Cash Flow: $investingCashFlow Cr');
            }
            
            // Financing Cash Flow
            final finCF = latest['financingCashFlow'];
            if (finCF != null) {
              financingCashFlow = (double.parse(finCF.toString()) / 10000000).toStringAsFixed(2);
              print('✓ Found Financing Cash Flow: $financingCashFlow Cr');
            }
          }
        }
      } catch (e) {
        print('ERROR fetching cash flow: $e');
      }

      // 6. Fetch additional ratios (P/B, P/S, Market Cap)
      String? pbRatio;
      String? psRatio;
      String? marketCap;

      try {
        print('\n--- Fetching Additional Ratios ---');
        await Future.delayed(const Duration(milliseconds: 500));
        
        final ratiosUrl = Uri.parse(
          "https://data.finedgeapi.com/api/v1/annual-price-ratios/$symbol"
        ).replace(queryParameters: {
          'token': _finedgeApiToken,
          'statement_type': 's',
        });

        final ratiosResp = await http.get(
          ratiosUrl,
          headers: {'Accept': 'application/json'}
        ).timeout(const Duration(seconds: 10));

        if (ratiosResp.statusCode == 200 && ratiosResp.body.isNotEmpty) {
          final ratiosData = json.decode(ratiosResp.body);
          dynamic ratiosList = ratiosData['price_ratios'];
          
          if (ratiosList != null && ratiosList is List && ratiosList.isNotEmpty) {
            final latest = ratiosList.first;
            print('Ratios keys: ${latest.keys.toList()}');
            
            // P/B Ratio
            final pb = latest['pb'] ?? latest['priceToBook'] ?? latest['pbRatio'];
            if (pb != null) {
              pbRatio = double.parse(pb.toString()).toStringAsFixed(2);
              print('✓ Found P/B: $pbRatio');
            }
            
            // P/S Ratio
            final ps = latest['ps'] ?? latest['priceToSales'] ?? latest['psRatio'];
            if (ps != null) {
              psRatio = double.parse(ps.toString()).toStringAsFixed(2);
              print('✓ Found P/S: $psRatio');
            }
            
            // Market Cap
            final mktCap = latest['marketCap'] ?? latest['market_cap'];
            if (mktCap != null) {
              marketCap = (double.parse(mktCap.toString()) / 10000000).toStringAsFixed(2);
              print('✓ Found Market Cap: $marketCap Cr');
            }
          }
        }
      } catch (e) {
        print('ERROR fetching additional ratios: $e');
      }

      print('\n=== FINAL EXTRACTED VALUES ===');
      print('Revenue: $revenue');
      print('EBITDA: $ebitda');
      print('EBIT: $ebit');
      print('Net Profit: $netProfit');
      print('EPS: $eps');
      print('P/E Ratio: $peRatio');
      print('Total Assets: $totalAssets');
      print('Total Liabilities: $totalLiabilities');
      print('Long-Term Debt: $longTermDebt');
      print('Shareholders Equity: $shareholdersEquity');
      print('Operating Cash Flow: $operatingCashFlow');
      print('Investing Cash Flow: $investingCashFlow');
      print('Financing Cash Flow: $financingCashFlow');
      print('Cash & Equivalents: $cashEquivalents');
      print('P/B Ratio: $pbRatio');
      print('P/S Ratio: $psRatio');
      print('Market Cap: $marketCap');
      print('================================\n');
      
      setState(() {
        _stockData = {
          'Company Name': widget.companyName,
          'Symbol': symbol,
          'Current Price': currentPrice?.toString() ?? 'N/A',
          'High': high?.toString() ?? 'N/A',
          'Low': low?.toString() ?? 'N/A',
          'Open': open?.toString() ?? 'N/A',
          'Change Value': changeValue?.toStringAsFixed(2) ?? 'N/A',
          'Change Percent': changePct?.toStringAsFixed(2) ?? 'N/A',
          'Volume': volume?.toString() ?? 'N/A',
          // Income Statement
          'Revenue': revenue ?? 'N/A',
          'EBITDA': ebitda ?? 'N/A',
          'EBIT': ebit ?? 'N/A',
          'Net Profit': netProfit ?? 'N/A',
          'EPS': eps ?? 'N/A',
          'Stock P/E': peRatio ?? 'N/A',
          // Balance Sheet
          'Total Assets': totalAssets ?? 'N/A',
          'Total Liabilities': totalLiabilities ?? 'N/A',
          'Long-Term Debt': longTermDebt ?? 'N/A',
          'Shareholders Equity': shareholdersEquity ?? 'N/A',
          // Cash Flow
          'Operating Cash Flow': operatingCashFlow ?? 'N/A',
          'Investing Cash Flow': investingCashFlow ?? 'N/A',
          'Financing Cash Flow': financingCashFlow ?? 'N/A',
          'Cash & Equivalents': cashEquivalents ?? 'N/A',
          // Valuation
          'P/B Ratio': pbRatio ?? 'N/A',
          'P/S Ratio': psRatio ?? 'N/A',
          'Market Cap': marketCap ?? 'N/A',
        };
        _stockError = '';
      });
    } catch (e, stackTrace) {
      print('=== FATAL ERROR ===');
      print('Error: $e');
      print('Stack trace: $stackTrace');
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
      final url = "http://10.244.218.93:5000/api/filtered-news/company/$encodedName";
      
      print('📰📰📰 Fetching news for: ${widget.companyName}');
      print('📰📰📰 URL: $url');
      
      final resp = await http.get(Uri.parse(url));
      
      print('📰📰📰 News Response Status: ${resp.statusCode}');
      print('📰📰📰 News Response Body Length: ${resp.body.length}');

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        print('📰📰📰 News data type: ${data.runtimeType}');
        print('📰📰📰 News count: ${data is List ? data.length : 0}');
        
        setState(() {
          _news = (data as List).cast<Map<String, dynamic>>();
        });
        
        if (_news.isEmpty) {
          print('⚠️ No news found for ${widget.companyName}');
        } else {
          print('✅ Loaded ${_news.length} news articles');
        }
      } else {
        final errorBody = resp.body;
        setState(() {
          _error =
              "Failed to fetch news\nStatus: ${resp.statusCode}\nError: $errorBody";
        });
        print('❌ News fetch failed: ${resp.statusCode}');
      }
    } catch (e, stackTrace) {
      print('❌❌❌ Exception in _fetchCompanyNews: $e');
      print('Stack trace: $stackTrace');
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
      var symbol = widget.companySymbol.toUpperCase();
      if (symbol.endsWith('.NSE') || symbol.endsWith('.BSE')) {
        symbol = symbol.split('.').first;
      }

      final url = Uri.parse(
        'http://10.244.218.93:5001/api/ai-overview/$symbol'
      ).replace(queryParameters: {
        'company_name': widget.companyName,
        'v': '5'
      });

      print('🔥🔥🔥 CALLING AI OVERVIEW: $url');
      
      final resp = await http.get(url).timeout(const Duration(seconds: 150));
      
      print('🔥🔥🔥 RESPONSE STATUS: ${resp.statusCode}');
      print('🔥🔥🔥 RESPONSE BODY: ${resp.body.substring(0, resp.body.length > 200 ? 200 : resp.body.length)}');

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data['success'] == true) {
          setState(() {
            _aiOverview = {
              'overview': data['overview'],
              'generated_at': data['generated_at'],
              'company_name': data['company_name'],
              'symbol': data['symbol'],
            };
          });
          print('✅ AI Overview loaded successfully');
        } else {
          setState(() {
            _aiError = data['error'] ?? "Failed to generate AI overview";
          });
          print('❌ API returned success=false: ${data['error']}');
        }
      } else {
        setState(() {
          _aiError = "Failed to fetch AI overview (${resp.statusCode})";
        });
        print('❌ HTTP Error: ${resp.statusCode}');
      }
    } catch (e, stackTrace) {
      print('❌❌❌ EXCEPTION in _fetchAIOverview: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _aiError = "Connection failed: $e";
        _aiOverview = null;
      });
    }

    setState(() => _isLoadingAI = false);
  }

  Future<void> _fetchAIInsight() async {
    setState(() {
      _isLoadingInsight = true;
      _insightError = '';
    });

    try {
      var symbol = widget.companySymbol.toUpperCase();
      if (symbol.endsWith('.NSE') || symbol.endsWith('.BSE')) {
        symbol = symbol.split('.').first;
      }

      final url = Uri.parse(
        'http://10.244.218.93:5001/api/ai-insight/$symbol'
      ).replace(queryParameters: {
        'company_name': widget.companyName,
        'v': '5'
      });

      print('🔥🔥🔥 CALLING AI INSIGHT: $url');
      
      final resp = await http.get(url).timeout(const Duration(seconds: 150));
      
      print('🔥🔥🔥 INSIGHT RESPONSE STATUS: ${resp.statusCode}');
      print('🔥🔥🔥 INSIGHT RESPONSE BODY: ${resp.body}');

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data['success'] == true) {
          setState(() {
            _aiInsight = {
              'insight': data['insight'],
              'generated_at': data['generated_at'],
            };
          });
          print('✅ AI Insight loaded successfully');
        } else {
          setState(() {
            _insightError = data['error'] ?? "Failed to generate AI insight";
          });
          print('❌ Insight API returned success=false');
        }
      } else {
        setState(() {
          _insightError = "Failed to fetch AI insight (${resp.statusCode})";
        });
        print('❌ Insight HTTP Error: ${resp.statusCode}');
      }
    } catch (e, stackTrace) {
      print('❌❌❌ EXCEPTION in _fetchAIInsight: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _insightError = "Connection failed: $e";
      });
    }

    setState(() => _isLoadingInsight = false);
  }

  Future<void> _fetchCompanyEvents() async {
    setState(() {
      _isLoadingEvents = true;
      _eventsError = '';
    });

    try {
      final encodedName = Uri.encodeComponent(widget.companyName);
      final url = "http://10.244.218.93:5000/api/events/company/$encodedName";
      
      print('🎉🎉🎉 Fetching events for: ${widget.companyName}');
      
      final resp = await http.get(Uri.parse(url));
      
      print('🎉🎉🎉 Events Response Status: ${resp.statusCode}');

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        setState(() {
          _companyEvents = (data as List).cast<Map<String, dynamic>>();
        });
        print('✅ Loaded ${_companyEvents.length} events');
      } else {
        setState(() {
          _eventsError = "Failed to fetch events (${resp.statusCode})";
        });
      }
    } catch (e) {
      print('❌ Exception in _fetchCompanyEvents: $e');
      setState(() {
        _eventsError = "Failed to load events: $e";
      });
    }

    setState(() => _isLoadingEvents = false);
  }

  Future<void> _fetchChartData(String timeframe) async {
    setState(() {
      _isLoadingChart = true;
      _chartError = '';
      _selectedTimeframe = timeframe;
    });

    try {
      var symbol = widget.companySymbol.toUpperCase();
      if (symbol.endsWith('.NSE') || symbol.endsWith('.BSE')) {
        symbol = symbol.split('.').first;
      }

      // Yahoo Finance parameters based on timeframe
      String range, interval;
      switch (timeframe) {
        case '1W':
          range = '7d';
          interval = '1d';
          break;
        case '1Y':
          range = '1y';
          interval = '1wk';
          break;
        case '1M':
        default:
          range = '1mo';
          interval = '1d';
      }

      final url = Uri.parse(
        'https://query1.finance.yahoo.com/v8/finance/chart/$symbol.NS'
      ).replace(queryParameters: {
        'range': range,
        'interval': interval,
      });

      print('Fetching Yahoo Finance chart: $url');

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['chart']?['result'] == null || data['chart']['result'].isEmpty) {
          setState(() {
            _chartError = 'No chart data available';
            _chartData = [];
          });
          return;
        }

        final result = data['chart']['result'][0];
        final timestamps = result['timestamp'] as List?;
        final quote = result['indicators']?['quote']?[0];

        if (timestamps == null || quote == null) {
          setState(() {
            _chartError = 'Invalid chart data format';
            _chartData = [];
          });
          return;
        }

        final opens = quote['open'] as List?;
        final highs = quote['high'] as List?;
        final lows = quote['low'] as List?;
        final closes = quote['close'] as List?;

        if (opens == null || highs == null || lows == null || closes == null) {
          setState(() {
            _chartError = 'Missing OHLC data';
            _chartData = [];
          });
          return;
        }

        List<Map<String, dynamic>> chartData = [];
        for (int i = 0; i < timestamps.length; i++) {
          if (opens[i] != null && highs[i] != null && 
              lows[i] != null && closes[i] != null) {
            chartData.add({
              'time': timestamps[i],
              'open': opens[i].toDouble(),
              'high': highs[i].toDouble(),
              'low': lows[i].toDouble(),
              'close': closes[i].toDouble(),
            });
          }
        }

        setState(() {
          _chartData = chartData;
          _chartError = '';
        });

        // Load or update chart
        if (_chartInitialized) {
          _updateChartData();
        } else {
          _webViewController?.loadHtmlString(_getTradingViewHTML());
        }

      } else {
        setState(() {
          _chartError = 'Failed to fetch chart data (${response.statusCode})';
          _chartData = [];
        });
      }
    } catch (e) {
      print('Chart fetch error: $e');
      setState(() {
        _chartError = 'Chart not available';
        _chartData = [];
      });
    }

    setState(() => _isLoadingChart = false);
  }

  void _updateChartData() {
    if (_chartData.isEmpty || _webViewController == null) return;
    
    final jsonData = json.encode(_chartData);
    _webViewController!.runJavaScript('''
      if (window.candlestickSeries && window.chart) {
        window.candlestickSeries.setData($jsonData);
        window.chart.timeScale().fitContent();
      }
    ''');
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

  String _parseIndianNumber(String? value) {
    if (value == null || value.isEmpty) return 'N/A';
    return value.replaceAll(',', '');
  }

  String _formatMarketCap() {
    final marketCap = _stockData?['Market Cap'];
    if (marketCap == null || marketCap.toString() == 'N/A') return 'N/A';

    try {
      final value = double.parse(_parseIndianNumber(marketCap.toString()));
      if (value >= 100000) {
        return '₹${(value / 100000).toStringAsFixed(2)}L Cr';
      } else if (value >= 1000) {
        return '₹${(value / 1000).toStringAsFixed(2)}K Cr';
      }
      return '₹${value.toStringAsFixed(2)} Cr';
    } catch (e) {
      return '₹${marketCap.toString()} Cr';
    }
  }

  String _getTradingViewHTML() {
    final jsonData = json.encode(_chartData);
    
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <script src="https://unpkg.com/lightweight-charts@4.1.0/dist/lightweight-charts.standalone.production.js"></script>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { 
      margin: 0; 
      padding: 0; 
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      overflow: hidden;
    }
    #chart { width: 100%; height: 100vh; }
    #loading {
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      font-size: 14px;
      color: #666;
    }
  </style>
</head>
<body>
  <div id="loading">Loading chart...</div>
  <div id="chart"></div>
  <script>
    try {
      // Wait for library to load
      if (typeof LightweightCharts === 'undefined') {
        document.getElementById('loading').textContent = 'Chart library loading...';
        setTimeout(() => location.reload(), 2000);
        throw new Error('LightweightCharts not loaded');
      }

      document.getElementById('loading').style.display = 'none';

      const chartContainer = document.getElementById('chart');
      const chart = LightweightCharts.createChart(chartContainer, {
        width: chartContainer.clientWidth,
        height: chartContainer.clientHeight,
        layout: {
          background: { color: '#ffffff' },
          textColor: '#333',
        },
        grid: {
          vertLines: { color: '#f0f0f0' },
          horzLines: { color: '#f0f0f0' },
        },
        crosshair: {
          mode: LightweightCharts.CrosshairMode.Normal,
        },
        rightPriceScale: {
          borderColor: '#e0e0e0',
        },
        timeScale: {
          borderColor: '#e0e0e0',
          timeVisible: true,
          secondsVisible: false,
        },
      });

      const candlestickSeries = chart.addCandlestickSeries({
        upColor: '#26a69a',
        downColor: '#ef5350',
        borderVisible: false,
        wickUpColor: '#26a69a',
        wickDownColor: '#ef5350',
      });

      // Expose to global scope for updates
      window.chart = chart;
      window.candlestickSeries = candlestickSeries;

      const data = $jsonData;
      
      if (data && data.length > 0) {
        candlestickSeries.setData(data);
        chart.timeScale().fitContent();
      } else {
        document.getElementById('loading').style.display = 'block';
        document.getElementById('loading').textContent = 'No data available';
      }

      // Handle resize
      window.addEventListener('resize', () => {
        chart.applyOptions({ 
          width: chartContainer.clientWidth,
          height: chartContainer.clientHeight 
        });
      });

    } catch (error) {
      console.error('Chart error:', error);
      document.getElementById('loading').textContent = 'Chart error: ' + error.message;
    }
  </script>
</body>
</html>
    ''';
  }

  Widget _buildChartWidget() {
    return Container(
      height: 200,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          // Timeframe buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildTimeframeButton('1W'),
                const SizedBox(width: 8),
                _buildTimeframeButton('1M'),
                const SizedBox(width: 8),
                _buildTimeframeButton('1Y'),
              ],
            ),
          ),
          // Chart area
          Expanded(
            child: _isLoadingChart
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Text('Loading chart...', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  )
                : _chartError.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, color: Colors.grey.shade400, size: 32),
                            const SizedBox(height: 8),
                            Text(
                              _chartError,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : _chartData.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.show_chart, color: Colors.grey.shade400, size: 32),
                                const SizedBox(height: 8),
                                Text(
                                  'No chart data available',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ClipRRect(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                            child: _webViewController != null
                                ? WebViewWidget(controller: _webViewController!)
                                : const Center(
                                    child: Text(
                                      'Initializing chart...',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeframeButton(String timeframe) {
    final isSelected = _selectedTimeframe == timeframe;
    return GestureDetector(
      onTap: () => _fetchChartData(timeframe),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEA6B6B) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? const Color(0xFFEA6B6B) : Colors.grey.shade400,
          ),
        ),
        child: Text(
          timeframe,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chart Widget
          _buildChartWidget(),

          // AI Overview Section
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.psychology, size: 18, color: Color(0xFFEA6B6B)),
                    const SizedBox(width: 8),
                    const Text(
                      'AI OVERVIEW',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    if (_aiOverview?['generated_at'] != null)
                      Text(
                        'Generated',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _isLoadingAI
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : _aiError.isNotEmpty && _aiOverview == null
                        ? Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red.shade300, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _aiError,
                                    style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Text(
                            _aiOverview?['overview'] ?? 
                            'Unable to generate overview. Please try again later.',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.6,
                              color: Colors.grey.shade800,
                            ),
                          ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFinancialsTab() {
    if (_isLoadingStock) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_stockError.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _stockError,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Income Statement
          _buildFinancialSection(
            title: 'INCOME STATEMENT (ANNUAL)',
            subtitle: 'Scale, profitability, and earnings strength',
            rows: [
              _buildFundamentalRow('Revenue', _stockData?['Revenue'] ?? 'N/A', 'EBITDA', _stockData?['EBITDA'] ?? 'N/A'),
              _buildFundamentalRow('EBIT', _stockData?['EBIT'] ?? 'N/A', 'Net Profit', _stockData?['Net Profit'] ?? 'N/A'),
              _buildFundamentalRow('EPS', _stockData?['EPS'] ?? 'N/A', 'P/E Ratio', _stockData?['Stock P/E'] ?? 'N/A'),
            ],
          ),

          // 2. Balance Sheet
          _buildFinancialSection(
            title: 'BALANCE SHEET (LATEST ANNUAL)',
            subtitle: 'Snapshot of financial position',
            rows: [
              _buildFundamentalRow('Total Assets', _stockData?['Total Assets'] ?? 'N/A', 'Total Liabilities', _stockData?['Total Liabilities'] ?? 'N/A'),
              _buildFundamentalRow('Long-Term Debt', _stockData?['Long-Term Debt'] ?? 'N/A', 'Cash & Equivalents', _stockData?['Cash & Equivalents'] ?? 'N/A'),
              _buildFundamentalRow('Shareholders\' Equity', _stockData?['Shareholders Equity'] ?? 'N/A', '', ''),
            ],
          ),

          // 3. Cash Flow Statement
          _buildFinancialSection(
            title: 'CASH FLOW STATEMENT (ANNUAL)',
            subtitle: 'Cash generation and sustainability',
            rows: [
              _buildFundamentalRow('Operating Cash Flow', _stockData?['Operating Cash Flow'] ?? 'N/A', 'Investing Cash Flow', _stockData?['Investing Cash Flow'] ?? 'N/A'),
              _buildFundamentalRow('Financing Cash Flow', _stockData?['Financing Cash Flow'] ?? 'N/A', 'Free Cash Flow', 'N/A'),
            ],
          ),

          // 4. Valuation & Returns
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'VALUATION & RETURNS',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Is the stock reasonably valued?',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildValuationChip('P/E', _stockData?['Stock P/E'] ?? 'N/A'),
                    _buildValuationChip('P/B', _stockData?['P/B Ratio'] ?? 'N/A'),
                    _buildValuationChip('P/S', _stockData?['P/S Ratio'] ?? 'N/A'),
                    _buildValuationChip('Market Cap', _formatMarketCap()),
                  ],
                ),
              ],
            ),
          ),

          // 5. AI Insight Section (at the bottom)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 18, color: Color(0xFFEA6B6B)),
                    const SizedBox(width: 8),
                    const Text(
                      'AI INSIGHT',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _isLoadingInsight
                    ? const Center(child: CircularProgressIndicator())
                    : _insightError.isNotEmpty && _aiInsight == null
                        ? Text(_insightError, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))
                        : Text(
                            _aiInsight?['insight'] ?? 
                            'AI insight is limited due to incomplete financial data availability.',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.6,
                              color: Colors.grey.shade800,
                            ),
                          ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFinancialSection({
    required String title,
    required String subtitle,
    required List<Widget> rows,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          ...rows.map((row) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: row,
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildValuationChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
        ],
      ),
    );
  }

  String formatValue(String val) {
    if (val == 'N/A' || val == 'N/A (Bank)') return val;
    
    try {
      final numVal = double.parse(val);
      
      // Values are already in Crores from the API
      // Format based on magnitude
      if (numVal >= 100000) {
        // Convert to Lakh Crores
        return '₹${(numVal / 100000).toStringAsFixed(2)}L Cr';
      } else if (numVal >= 10000) {
        // Keep in Crores with thousand separator
        return '₹${numVal.toStringAsFixed(0)} Cr';
      } else if (numVal >= 1000) {
        return '₹${(numVal / 1000).toStringAsFixed(2)}K Cr';
      } else if (numVal < 100) {
        // For EPS and P/E ratios (small values)
        return numVal.toStringAsFixed(2);
      }
      return '₹${numVal.toStringAsFixed(2)} Cr';
    } catch (e) {
      return val;
    }
  }

  Widget _buildFundamentalRow(String label1, String value1, String label2, String value2) {
    // Format value1
    String formattedValue1;
    if (label1 == 'EPS' || label1 == 'P/E Ratio') {
      formattedValue1 = value1 == 'N/A' ? value1 : '₹$value1';
    } else {
      formattedValue1 = formatValue(value1);
    }

    // Format value2
    String formattedValue2;
    if (label2 == 'EPS' || label2 == 'P/E Ratio') {
      formattedValue2 = value2 == 'N/A' ? value2 : value2.endsWith('x') ? value2 : '${value2}x';
    } else {
      formattedValue2 = formatValue(value2);
    }

    // If label2 is empty, show only one column
    if (label2.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label1,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formattedValue1,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label1,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formattedValue1,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label2,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formattedValue2,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNewsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty) {
      return Center(child: Text(_error, style: const TextStyle(color: Colors.red)));
    }
    if (_news.isEmpty) {
      return const Center(child: Text('No news available'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _news.length,
      itemBuilder: (context, index) => _buildNewsItem(_news[index]),
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
    final currentPrice = _stockData?['Current Price']?.toString() ?? '0.00';
    final changeValue = _stockData?['Change Value']?.toString() ?? '0';
    final changePct = _stockData?['Change Percent']?.toString() ?? '0';
    
    bool isPositive = !changeValue.startsWith('-');

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text(
              '< ${widget.companySymbol.toUpperCase()}',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Container(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.companyName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Rs. ₹$currentPrice',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isPositive ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${isPositive ? '+' : ''}₹$changeValue ($changePct%)',
                              style: TextStyle(
                                fontSize: 12,
                                color: isPositive ? Colors.green : Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFFEA6B6B),
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: const Color(0xFFEA6B6B),
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: const [
                    Tab(text: 'OVERVIEW'),
                    Tab(text: 'FINANCIALS'),
                    Tab(text: 'NEWS'),
                    Tab(text: 'EVENTS'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildFinancialsTab(),
          _buildNewsTab(),
          _buildEventsTab(),
        ],
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

  Widget _buildEventsTab() {
    if (_isLoadingEvents) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_eventsError.isNotEmpty) {
      return Center(child: Text(_eventsError, style: const TextStyle(color: Colors.red)));
    }
    if (_companyEvents.isEmpty) {
      return const Center(child: Text('No events available for this company'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _companyEvents.length,
      itemBuilder: (context, index) => _buildEventItem(_companyEvents[index]),
    );
  }

  Widget _buildEventItem(Map<String, dynamic> event) {
    final title = event["title"] ?? "No title";
    final date = event["date"] ?? "";
    final description = event["description"] ?? "";
    final type = event["type"] ?? "Event";

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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF05151).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    type,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFF05151),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  _formatDate(date),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    description,
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
        ],
      ),
    );
  }
}



