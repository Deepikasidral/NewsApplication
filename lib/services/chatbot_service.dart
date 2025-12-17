import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatbotService {
  static const String _baseUrl = "http://10.69.144.93:8001/chat";
  // 👉 If testing on real phone, replace with your LAN IP

  static Future<String> askQuestion(String question) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"question": question}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["answer"] ?? "No response";
      } else {
        return "Server error. Please try again.";
      }
    } catch (e) {
      return "Connection failed. Check backend.";
    }
  }
}
