import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'sign_in_screen.dart';
import 'home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:google_mobile_ads/google_mobile_ads.dart';


class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  // InterstitialAd? _interstitialAd;
  // bool _isAdLoaded = false;
  bool _acceptedPrivacyPolicy = false;
  
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

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
  @override
void initState() {
  super.initState();
  // _loadInterstitialAd();
}
@override
void dispose() {
  // _interstitialAd?.dispose();
  super.dispose();
}
// void _loadInterstitialAd() {
//   InterstitialAd.load(
//     adUnitId: 'ca-app-pub-6088749573646337/6577319196', 
//     request: const AdRequest(),
//     adLoadCallback: InterstitialAdLoadCallback(
//       onAdLoaded: (ad) {
//         _interstitialAd = ad;
//         _isAdLoaded = true;
//       },
//       onAdFailedToLoad: (error) {
//         print("Ad failed to load: $error");
//         _isAdLoaded = false;
//       },
//     ),
//   );
// }
// void _showAdThenNavigate() {
//   if (_interstitialAd != null && _isAdLoaded) {
//     _interstitialAd!.fullScreenContentCallback =
//         FullScreenContentCallback(
//       onAdDismissedFullScreenContent: (ad) {
//         ad.dispose();
//         _loadInterstitialAd(); // reload
//         _navigateToHome();
//       },
//       onAdFailedToShowFullScreenContent: (ad, error) {
//         ad.dispose();
//         _navigateToHome();
//       },
//     );

//     _interstitialAd!.show();
//   } else {
//     _navigateToHome();
//   }
// }

void _navigateToHome() {
  if (!mounted) return;

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => const NewsFeedScreen()),
  );
}

  Future<void> _saveUserSession(Map<String, dynamic> user, String token) async {
  final prefs = await SharedPreferences.getInstance();

  await prefs.setString("userId", user["_id"]);
  await prefs.setString("userName", user["name"] ?? "");
  await prefs.setString("userEmail", user["email"] ?? "");
  await prefs.setString("loginType", user["loginType"] ?? "");
  await prefs.setString("authToken", token);
  await prefs.setBool("isLoggedIn", true);
}
Future<void> saveFcmTokenToBackend(String userId) async {
  final token = await FirebaseMessaging.instance.getToken();
  if (token == null) return;

  await http.post(
    Uri.parse("http://51.20.72.236:5000/api/users/save-fcm"),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "userId": userId,
      "fcmToken": token,
    }),
  );
}


  Future<void> _handleSignUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmController.text.trim();

    if (!_acceptedPrivacyPolicy) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text(
            "Privacy Policy Required",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "Please accept the Privacy Policy and Terms & Conditions to continue.",
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "OK",
                style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

    // ------------------ BACKEND SIGNUP CODE (TEMPORARILY DISABLED) ------------------
    
    try {
      final response = await http.post(
        Uri.parse("http://51.20.72.236:5000/api/auth/signup"), // backend unchanged
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": name,
          "email": email,
          "password": password,
          "loginType": "email",
        }),
      );

      final data = jsonDecode(response.body);

       if (response.statusCode == 200) {
  final data = jsonDecode(response.body);
  await _saveUserSession(data["user"], data["token"]);
  await saveFcmTokenToBackend(data["user"]["_id"]);


  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Account Created successfully")),
  );

  // _showAdThenNavigate();
  _navigateToHome();
}
 else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? "Sign up failed")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Sign up failed: $e")),
      );
    }
    

  }

  Future<void> _handleGoogleSignIn() async {
    if (!_acceptedPrivacyPolicy) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text(
            "Privacy Policy Required",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "Please accept the Privacy Policy and Terms & Conditions to continue.",
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "OK",
                style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
      return;
    }

    print("🚀 Starting Google Sign-In...");
    try {
      await _googleSignIn.signOut();
      
      final googleUser = await _googleSignIn.signIn();
      print("📧 Google User: ${googleUser?.email}");
      
      if (googleUser == null) {
        print("❌ Google Sign-In cancelled");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Google Sign-In was cancelled")),
        );
        return;
      }

      final googleAuth = await googleUser.authentication;
      print("🔑 Got authentication tokens");
      
      if (googleAuth.idToken == null || googleAuth.accessToken == null) {
        throw Exception("Failed to get authentication tokens");
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print("🔥 Signing in with Firebase...");
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      if (userCredential.user == null) {
        throw Exception("Firebase authentication failed");
      }

      print("✅ Firebase sign-in successful: ${userCredential.user!.email}");

      final userData = {
        'name': userCredential.user!.displayName ?? googleUser.displayName ?? 'User',
        'email': userCredential.user!.email ?? googleUser.email,
        'loginType': 'google',
        'uid': userCredential.user!.uid,
        'googleId': googleUser.id,
      };

      // Save to MongoDB
      print("💾 Saving to MongoDB...");
      try {
        final response = await http.post(
          Uri.parse("http://51.20.72.236:5000/api/auth/google-login"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(userData),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200 || response.statusCode == 201) {
  final data = jsonDecode(response.body);

  if (data["user"] != null && data["token"] != null) {
    await _saveUserSession(data["user"], data["token"]);
  }

  print("✅ User saved in MongoDB & session stored");
}
      } catch (mongoError) {
        print("⚠️ MongoDB error (continuing): $mongoError");
      }

      // Save to Firestore
      print("📝 Saving to Firestore...");
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set(userData, SetOptions(merge: true))
            .timeout(const Duration(seconds: 10));
        print("✅ Firestore save successful");
      } catch (firestoreError) {
        print("⚠️ Firestore error (continuing): $firestoreError");
        // Continue even if Firestore fails
      }

      if (!mounted) {
        print("⚠️ Widget not mounted, cannot navigate");
        return;
      }

      print("🎉 Showing success message...");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Signed in with Google successfully!"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Small delay to let user see the success message
      await Future.delayed(const Duration(milliseconds: 500));

      print("🚀 Navigating to home screen...");
      if (!mounted) return;
      
     // _showAdThenNavigate();
     _navigateToHome();
      
      print("✅ Navigation complete");

    } catch (e, stackTrace) {
      print("❌ Google Sign-In Error: $e");
      print("📚 Stack trace: $stackTrace");
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Google Sign-In failed: ${e.toString()}"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 30),

                // Top logo
                Column(
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '₹',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const TextSpan(
                            text: 'upee Letter',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Sign up',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 36.0),
                      child: Text(
                        'By continuing, you agree to our Terms of Services and Private Policy.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // White card with inputs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Full Name',
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            hintText: 'Enter full name',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),
                        const Text(
                          'Email',
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'Email',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),
                        const Text(
                          'Password',
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: 'Password',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),
                        const Text(
                          'Confirm Password',
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _confirmController,
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: 'Confirm Password',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // SIGN UP button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _handleSignUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFFFFF0F0).withOpacity(0.95),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            child: const Text(
                              'SIGN UP',
                              style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Privacy Policy Checkbox
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _acceptedPrivacyPolicy,
                        onChanged: (value) {
                          setState(() {
                            _acceptedPrivacyPolicy = value ?? false;
                          });
                        },
                        activeColor: Colors.red.shade700,
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => _buildPrivacyDialog(),
                            );
                          },
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 15, color: Colors.black87),
                              children: [
                                const TextSpan(text: 'I accept the '),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const TextSpan(text: ' and '),
                                TextSpan(
                                  text: 'Terms & Conditions',
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Add Divider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text('OR', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                      ),
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Google Sign-In Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _handleGoogleSignIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF8C5C5),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Center(
                              child: Text('G', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Continue with Google',
                              style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 26),

                // Link to Sign In
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already have an account?", style: TextStyle(color: Colors.black54)),
                    TextButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const SignInScreen()));
                      },
                      child: const Text("Sign In", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: DefaultTabController(
        length: 2,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEA6B6B),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: const TabBar(
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                tabs: [
                  Tab(text: "Privacy Policy"),
                  Tab(text: "Terms & Conditions"),
                ],
              ),
            ),
            SizedBox(
              height: 450,
              child: TabBarView(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      privacyPolicyText,
                      style: const TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
                    ),
                  ),
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      termsText,
                      style: const TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "Close",
                      style: TextStyle(color: Colors.black54, fontSize: 15),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _acceptedPrivacyPolicy = true;
                      });
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEA6B6B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text(
                      "Accept",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
