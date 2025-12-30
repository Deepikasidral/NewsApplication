import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:news_application/screens/splash_screen.dart';
import 'package:news_application/screens/home_screen.dart';

final GlobalKey<NavigatorState> navigatorKey =
    GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await dotenv.load(fileName: ".env");

  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // 🔔 REQUEST PERMISSION
  NotificationSettings settings =
      await messaging.requestPermission();

  print("🔔 Permission: ${settings.authorizationStatus}");

  // 🔔 SUBSCRIBE TO TOPIC
  await messaging.subscribeToTopic("market_alerts");
  print("✅ Subscribed to market_alerts");

  // 🔔 APP TERMINATED STATE
  RemoteMessage? initialMessage =
      await FirebaseMessaging.instance.getInitialMessage();

  if (initialMessage != null) {
    _handleNotification(initialMessage.data);
  }

  // 🔔 APP BACKGROUND STATE
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    _handleNotification(message.data);
  });

  runApp(const MyApp());
}

void _handleNotification(Map<String, dynamic> data) {
  final fileName = data['FileName'];

  if (fileName == null || navigatorKey.currentContext == null) return;

  navigatorKey.currentState!.push(
    MaterialPageRoute(
      builder: (_) => NewsFeedScreen(openFileName: fileName),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}
