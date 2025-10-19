import 'package:flutter/material.dart';
import 'sign_in_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SignInScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // "₹upee Letter" logo text
            RichText(
              text: TextSpan(
                children: [
                  const TextSpan(
                    text: '₹',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 45,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Times New Roman',
                    ),
                  ),
                  const TextSpan(
                    text: 'upee Letter',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 38,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Times New Roman',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              'Your one-stop solution for fast\nand clear '
              'financial news!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
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
