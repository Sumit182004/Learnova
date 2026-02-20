import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:learnova/admin_dashboard.dart';
import 'package:learnova/profile_page.dart';
import 'package:learnova/subject_screen.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'home_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const LernovaApp());
}

class LernovaApp extends StatelessWidget {
  const LernovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Lernova",
      debugShowCheckedModeBanner: false,
      initialRoute: "/login",
      routes: {
        "/login": (context) => const LoginPage(),
        "/signup": (context) => const SignupPage(),
        "/home": (context) => const HomePage(),
        "/profile": (context) => const ProfilePage(),
        "/admin": (context) =>  AdminDashboard(),
        "/subjects": (_) => SubjectsScreen(),
      },
    );
  }
}
