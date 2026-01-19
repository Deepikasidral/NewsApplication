import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AnalyticsService {
  static const String baseUrl = "http://13.51.242.86:5000";
  static DateTime? _sessionStart;

  static Future<void> startSession() async {
    _sessionStart = DateTime.now();
  }

  static Future<void> endSession() async {
    if (_sessionStart == null) return;

    final duration = DateTime.now().difference(_sessionStart!).inSeconds;
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString("userId");

    if (userId == null) return;

    try {
      await http.post(
        Uri.parse("$baseUrl/api/users/analytics"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "userId": userId,
          "sessionDuration": duration,
          "timestamp": DateTime.now().toIso8601String(),
        }),
      );
    } catch (e) {
      print("Analytics error: $e");
    }

    _sessionStart = null;
  }
}
