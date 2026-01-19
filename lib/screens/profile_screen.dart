import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:news_application/screens/sign_in_screen.dart';



class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool loading = true;

  String name = "";
  String email = "";
  
  bool notificationsEnabled = true;
  


  static const String baseUrl = "http://13.51.242.86:5000";

  @override
  void initState() {
    super.initState();
    fetchProfile();
  }

  /// 🔹 FETCH PROFILE
  Future<void> fetchProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString("userId");

    debugPrint("📍 Fetching profile for userId: $userId");

    if (userId == null) {
      debugPrint("❌ No userId found in SharedPreferences");
      setState(() {
        loading = false;
      });
      return;
    }

    try {
      debugPrint("🌐 Calling API: $baseUrl/api/users/profile");
      final response = await http.post(
        Uri.parse("$baseUrl/api/users/profile"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"userId": userId}),
      );

      debugPrint("📡 Response status: ${response.statusCode}");
      debugPrint("📦 Response body: ${response.body}");

      if (response.statusCode != 200) {
        throw Exception("API returned ${response.statusCode}");
      }

      final data = jsonDecode(response.body);
      final user = data['user'];

      debugPrint("✅ User data received: $user");

      setState(() {
        name = user['name'] ?? "";
        email = user['email'] ?? "";
        notificationsEnabled = user['notifications'] ?? true;
        loading = false;
      });
    } catch (e) {
      debugPrint("❌ Profile fetch error: $e");
      setState(() {
        loading = false;
      });
    }
  }

  /// 🔹 LOGOUT
  Future<void> logout() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();

  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const SignInScreen()),
    (route) => false,
  );
}
Future<void> updateNotification(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString("userId");

  if (userId == null) return;

  try {
    await http.post(
      Uri.parse("$baseUrl/api/users/notifications"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "userId": userId,
        "enabled": value,
      }),
    );
  } catch (e) {
    debugPrint("Notification update failed: $e");
  }
}



@override
Widget build(BuildContext context) {
  if (loading) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

  return Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        "PROFILE",
        style: TextStyle(color: Colors.black),
      ),
      centerTitle: true,
      leading: const BackButton(color: Colors.black),
    ),
    body: SingleChildScrollView( // ✅ FIX OVERFLOW
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const SizedBox(height: 20),

            /// 🔴 PROFILE IMAGE
            Center(
              child: CircleAvatar(
                radius: 55,
                backgroundColor: Colors.red,
                child: const CircleAvatar(
                  radius: 52,
                  backgroundImage: NetworkImage(
                    "https://i.pravatar.cc/300",
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            /// ---------------- NAME ----------------
            Text(
              "Name",
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              name.isEmpty ? "No name" : name,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 20),

            /// ---------------- EMAIL ----------------
            Text(
              "Gmail",
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              email.isEmpty ? "No email" : email,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 30),

            /// ================= DATA & PRIVACY =================
            Text(
              "Data & Privacy",
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            buildLink("Terms & Conditions"),
            buildLink("Disclaimer"),
            buildLink("Privacy Policy"),

            const SizedBox(height: 30),

            /// ================= SUPPORT =================
            Text(
              "Support",
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            buildLink("Send Feedback"),

            const SizedBox(height: 30),

            /// ================= SETTINGS =================
            Text(
              "Settings",
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Notifications",
                  style: GoogleFonts.poppins(fontSize: 15),
                ),
                Switch(
  value: notificationsEnabled,
  onChanged: (val) {
    setState(() => notificationsEnabled = val);
    updateNotification(val);
  },
),

              ],
            ),

            const SizedBox(height: 20),

            /// ---------------- LOGOUT ----------------
            TextButton(
              onPressed: logout,
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: Text(
                "Log Out",
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: Colors.black,
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    ),
  );
}


  /// ================== UI HELPERS ==================

  Widget buildTile(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget buildSection(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget buildLink(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 15,
        color: Colors.black,
      ),
    ),
  );
}

}
