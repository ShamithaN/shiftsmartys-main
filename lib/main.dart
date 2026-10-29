import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 👈 Added for Session Check

// Screen Imports
import 'package:shiftsmart/screens/login.dart';
// Manager Dashboard
// Employee Dashboard

// Service & Provider Imports
import 'package:shiftsmart/providers/user_provider.dart';
import 'package:shiftsmart/services/notification_service.dart';
import 'package:shiftsmart/services/auth_service.dart'; // 👈 Added for Profile Fetch

// --- 1. Background Message Handler ---
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
  print("Background Data: ${message.data}");

  // Initialize Local Notifications (Required for background isolate)
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.max,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // Manual Parsing Logic for Backend Data Messages
  String? title;
  String? body;

  if (message.data.containsKey('shiftDetails')) {
    title = "New Shift Assigned";
    body = message.data['shiftDetails'];
  } else if (message.data.containsKey('completionDetails')) {
    title = "Shift Completed";
    body = message.data['completionDetails'];
  } else if (message.data.containsKey('Status')) {
    title = "Leave Update";
    body = "Your leave request is ${message.data['Status']}";
  } else if (message.notification != null) {
    // Fallback for standard notifications
    title = message.notification?.title;
    body = message.notification?.body;
  }

  // Show the Notification
  if (body != null) {
    await flutterLocalNotificationsPlugin.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          icon: '@mipmap/ic_launcher', // Ensure this icon exists
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }
}

// --- 2. Global Notification Channel Setup ---
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> setupLocalNotifications() async {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    description:
        'This channel is used for important notifications.', // description
    importance: Importance.max,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase & Environment
  await Firebase.initializeApp();
  await dotenv.load();

  // Set up Background Handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Setup Local Notifications (For Foreground Pop-ups)
  await setupLocalNotifications();

  // Initialize FCM Service (Permission Request)
  // We pass employeeId: 0 to setup listeners, BUT skip registration to avoid 403 error.
  await NotificationService().initializeFCM(
    employeeId: 0,
    userTag: "guest",
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MyHomePage(title: 'Welcome'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Add AuthService to fetch profile
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    // Replaced the simple timer with the Smart Session Check
    _checkLoginStatus();
  }

  // 🚀 LOGIC: Check Disk for Token -> Restore Session -> Navigate
  Future<void> _checkLoginStatus() async {
    // 1. Give the splash screen a visual delay (2 seconds)
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('appToken');
      final String? email = prefs.getString('userEmail');

      // 2. Do we have a token saved?
      if (token != null && token.isNotEmpty && email != null) {
        print("🔹 Found saved session. Redirecting to Biometric Login...");

        // 3. Navigate to Login Screen with Biometric Prompt enabled
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const Login(promptBiometric: true),
          ),
        );
        return;
      }
    } catch (e) {
      print("⚠️ Session check failed: $e");
    }

    // 4. Fallback: If no token or invalid token, go to Login (Standard)
    if (mounted) {
      print("🔸 No valid session found. Going to Standard Login.");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Login(promptBiometric: false)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.height,
            color: const Color(0xFF242C3B),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image(
                  image: AssetImage('assets/logo.png'),
                  width: 250,
                  height: 250,
                ),
                SizedBox(height: 20),
                // Optional loading spinner so user knows we are checking session
                CircularProgressIndicator(color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
