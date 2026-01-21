import 'dart:convert';
import 'package:http/http.dart' as http;

class StockPriceService {
  static Future<Map<String, dynamic>?> getStockPrice(String symbol) async {
    try {
      // Yahoo Finance API endpoint
      final url = Uri.parse(
        'https://query1.finance.yahoo.com/v8/finance/chart/$symbol.NS?interval=1d&range=1d'
      );
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final quote = data['chart']['result'][0]['meta'];
        
        final currentPrice = quote['regularMarketPrice'];
        final previousClose = quote['chartPreviousClose'];
        final change = currentPrice - previousClose;
        final changePercent = (change / previousClose) * 100;
        
        return {
          'price': currentPrice.toStringAsFixed(2),
          'change': change.toStringAsFixed(2),
          'changePercent': changePercent.toStringAsFixed(2),
        };
      }
    } catch (e) {
      print('Error fetching stock price: $e');
    }
    return null;
  }
}
