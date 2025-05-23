import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'models/cart_provider.dart';
import 'screens/login_page.dart';
import 'screens/main_page.dart';
import 'screens/verify_email_page.dart';
import 'screens/start_page.dart';
import 'screens/index_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    print('Firebase already initialized: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CartProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Cadeli App',
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFFA1BDC7),
          primaryColor: Colors.blueAccent,
        ),
        home: const StartToIndexRouter(),
      ),
    );
  }
}

class StartToIndexRouter extends StatefulWidget {
  const StartToIndexRouter({super.key});

  @override
  State<StartToIndexRouter> createState() => _StartToIndexRouterState();
}

class _StartToIndexRouterState extends State<StartToIndexRouter> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const IndexPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const StartPage();
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.email == null || user.uid.isEmpty) {
      FirebaseAuth.instance.signOut(); // Auto log out if ghost
      return const LoginPage();
    }

    if (!user.emailVerified) {
      return const VerifyEmailPage();
    }

    return const MainPage();
  }
}

