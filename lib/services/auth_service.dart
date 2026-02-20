import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String baseUrl = "https://13.51.242.86:5000/api/auth";

  // Get stored token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("authToken");
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool("isLoggedIn") ?? false;
  }

  // Verify token validity
  static Future<bool> verifyToken() async {
    try {
      final token = await getToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse("$baseUrl/verify-token"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"token": token}),
      ).timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);
      return response.statusCode == 200 && data["valid"] == true;
    } catch (e) {
      print("Token verification failed: $e");
      return false;
    }
  }

  // Refresh token (call this periodically or before expiry)
  static Future<bool> refreshToken() async {
    try {
      final token = await getToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse("$baseUrl/refresh-token"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"token": token}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newToken = data["token"];

        // Save new token
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("authToken", newToken);
        return true;
      }
      return false;
    } catch (e) {
      print("Token refresh failed: $e");
      return false;
    }
  }

  // Logout
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Get user data from storage
  static Future<Map<String, String?>> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      "userId": prefs.getString("userId"),
      "userName": prefs.getString("userName"),
      "userEmail": prefs.getString("userEmail"),
      "loginType": prefs.getString("loginType"),
    };
  }

  // Make authenticated API request
  static Future<http.Response> authenticatedRequest(
    String url, {
    String method = "GET",
    Map<String, dynamic>? body,
  }) async {
    final token = await getToken();

    final headers = {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };

    if (method == "POST") {
      return await http.post(
        Uri.parse(url),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
    } else {
      return await http.get(Uri.parse(url), headers: headers);
    }
  }
}
