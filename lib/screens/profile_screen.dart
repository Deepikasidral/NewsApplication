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
  

  final String disclaimerText = '''
RupeeLetter is a financial news and information platform.

All content is provided for educational and informational purposes only and should not be considered investment advice.

RupeeLetter is not a SEBI-registered advisor and does not recommend buying, selling, or holding any securities.

Users should conduct their own research or consult a qualified professional before making investment decisions.
''';
final String termsText = '''
By using the RupeeLetter app, you agree to the following:

• RupeeLetter provides financial news and information for informational purposes only.

• Content is sourced from third parties and public information; accuracy or completeness is not guaranteed.

• RupeeLetter does not provide investment, legal, or financial advice.

• Users are responsible for how they use the information provided.

• We may update, modify, or discontinue features without prior notice.

• Misuse of the app or attempts to disrupt services may result in account suspension.

• Continued use of the app constitutes acceptance of these Terms.
''';
final String privacyPolicyText = '''


RupeeLetter respects your privacy and is committed to protecting your personal information.

1. Information We Collect
• Name
• Email address or mobile number
• User preferences (notifications, followed stocks)

2. Automatically Collected Information
• App usage activity
• Device information
• Crash logs and performance data

3. Information We Do Not Collect
• Bank details
• Trading or brokerage data
• PAN, Aadhaar, or KYC information

4. How We Use Your Information
• Deliver relevant financial news
• Personalize content
• Improve app performance
• Respond to support requests

We do not sell your personal data.

5. Notifications
You can enable or disable notifications at any time from the App.

6. Your Rights
You may update preferences, opt out of notifications, or request account deletion.

7. Contact Us
Email: contact@rupeeletter.com
Website: https://rupeeletter.com
''';

final String feedbackText = '''
Have a question, spotted an issue, or want to share feedback?
We’re here to help.

RupeeLetter is built to deliver fast, clear, and reliable financial news.
Your feedback helps us improve.

Get in Touch
Email: contact@rupeeletter.com
Response time: Within 24–48 hours (business days)

For faster resolution, please mention:
• Your registered email (if applicable)
• App version
• Short description of the issue or feedback

App Support
You can contact us for:
• Incorrect or delayed news
• App bugs or crashes
• Notification issues
• Feature suggestions
• Account-related queries

Privacy & Data Requests
For privacy-related concerns, data usage questions, or account deletion requests, contact:
Email: contact@rupeeletter.com

Disclaimer
RupeeLetter provides financial news and information for educational and informational purposes only.
We do not provide investment advice or recommendations.

About RupeeLetter
RupeeLetter is a financial news and insights platform focused on simplifying market updates, corporate news, and key events for investors and market participants.
''';


  


  static const String baseUrl = "http://51.20.72.236:5000";

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

        loading = false;
      });
    } catch (e) {
      debugPrint("❌ Profile fetch error: $e");
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> deleteAccount() async {
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString("userId");

  if (userId == null) return;

  try {
    final response = await http.post(
      Uri.parse("$baseUrl/api/users/delete-account"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"userId": userId}),
    );

    if (response.statusCode == 200) {
      await prefs.clear();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SignInScreen()),
        (route) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account deleted successfully")),
      );
    } else {
      throw Exception("Delete failed");
    }
  } catch (e) {
    debugPrint("❌ Delete account error: $e");

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Failed to delete account")),
    );
  }
}
void showDeleteDialog() {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Delete Account"),
      content: const Text(
        "Are you sure? This action cannot be undone.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            deleteAccount();
          },
          child: const Text(
            "Delete",
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    ),
  );
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

void _showInfoDialog(String title, String content) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  content,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Close",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
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
              backgroundColor: Colors.grey.shade300,
              child: Icon(
                Icons.person,
                size: 50,
                color: Colors.grey.shade600,
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

            buildLink(
              "Disclaimer",
              () => _showInfoDialog("Disclaimer", disclaimerText),
            ),

            buildLink(
              "Terms & Conditions",
              () => _showInfoDialog("Terms & Conditions", termsText),
            ),

            buildLink(
              "Privacy Policy",
              () => _showInfoDialog("Privacy Policy", privacyPolicyText),
            ),

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

            buildLink(
  "Send Feedback",
  () => _showInfoDialog("Send Feedback", feedbackText),
),


            const SizedBox(height: 30),

            /// ================= SETTINGS =================
            
           

            
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

            TextButton(
                onPressed: showDeleteDialog,
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: Text(
                  "Delete Account",
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: Colors.red,
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

  Widget buildLink(String text, VoidCallback onTap) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      onTap: onTap,
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 15,
          color: Colors.black,
          decoration: TextDecoration.underline,
        ),
      ),
    ),
  );
}


}