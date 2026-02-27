import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
// 1. THIS IS THE IMPORT LINE YOU ASKED FOR:
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // --- ONESIGNAL SETUP ---
  // 2. THIS IS WHERE YOU ADD THE ID FROM YOUR SCREENSHOT
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize("YOUR_ONESIGNAL_APP_ID");
  OneSignal.Notifications.requestPermission(true);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Evalock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF002147),
        useMaterial3: true,
      ),
      // 3. This calls the class from login_screen.dart
      home: const LoginScreen(),
    );
  }
}
