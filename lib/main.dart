import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; 
import 'firebase_options.dart'; 
import 'screens/splash_screen.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();


  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const WalkBeatApp());
}

class WalkBeatApp extends StatelessWidget {
  const WalkBeatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WalkBeat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blueGrey,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const SplashScreen(),
    );
  }
}
