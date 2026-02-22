import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'sign_in_screen.dart';
import 'home_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(seconds: 2));

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("authToken");
    final isLoggedIn = prefs.getBool("isLoggedIn") ?? false;

    if (!isLoggedIn || token == null) {
      _navigateToSignIn();
      return;
    }

    // Verify token with backend
    try {
      final response = await http.post(
        Uri.parse("http://13.51.242.86:5000/api/auth/verify-token"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"token": token}),
      ).timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data["valid"] == true) {
        // Token is valid, go to home
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const NewsFeedScreen()),
        );
      } else {
        // Token expired or invalid
        await _clearSession();
        _navigateToSignIn();
      }
    } catch (e) {
      print("Session check failed: $e");
      _navigateToSignIn();
    }
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  void _navigateToSignIn() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SignInScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'LOGO 1024x1024.png',
              height: 120,
              width: 120,
            ),
            const SizedBox(height: 20),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '₹',
                    style: GoogleFonts.playfairDisplay(
                      color: Colors.red,
                      fontSize: 45,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: 'upee Letter',
                    style: GoogleFonts.playfairDisplay(
                      color: Colors.black,
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            Text(
              'Your one-stop solution for fast\nand clear '
              'financial news!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
