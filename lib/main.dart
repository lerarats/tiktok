import 'package:flutter/material.dart';
import 'package:kurshachtt/provider/nav/nav_provider.dart';
import 'package:kurshachtt/screen/reel/login_screen.dart';
import 'package:kurshachtt/screen/reel/user_profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://ehdliqszkyprsiurkjwf.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVoZGxpcXN6a3lwcnNpdXJrandmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDE5NjAzNTcsImV4cCI6MjA1NzUzNjM1N30.wpIIX2VRKDPQAd0J9VdADf4-BlngPM6XHrkLfXbovK0',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => NavProvider()),
      ],
      child: const ThemeWrapper(),
    );
  }
}

class ThemeWrapper extends StatelessWidget {
  const ThemeWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginScreen(),
      routes: {
        '/login': (context) => LoginScreen(),
        '/userProfile': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, String>;
          return UserProfileScreen(
            userId: args['userId']!,
          );
        },
      },


    );
  }

}