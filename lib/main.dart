import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:news_application/screens/splash_screen.dart';
import 'package:news_application/screens/home_screen.dart';
import 'package:news_application/services/analytics_service.dart';

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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AnalyticsService.startSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      AnalyticsService.endSession();
    } else if (state == AppLifecycleState.resumed) {
      AnalyticsService.startSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}