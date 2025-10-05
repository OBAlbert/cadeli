import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'firebase_options.dart';
import 'models/cart_provider.dart';
import 'services/notification_service.dart';

// Screens
import 'screens/start_page.dart';          // splash visual
import 'screens/index_page.dart';          // public landing (Login / Register entry)
import 'screens/login_page.dart';
import 'screens/register_page.dart';
import 'screens/verify_email_page.dart';
import 'screens/main_page.dart';
import 'screens/admin_main_page.dart';
import 'screens/pick_location_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
  } catch (_) {}
  await NotificationService.initialize();

  // Stripe
  Stripe.publishableKey = 'pk_test_51S6UmbI3V93NylQgC8WsOktl7aErCo55vNa9LIV95sCnwvCHoCD2PV1LBLjcUp0wQeJ4wvUJ5h0aZJUnZVVbPef4003m4GIw6g';
  if (Platform.isIOS) Stripe.merchantIdentifier = 'merchant.com.cadeli';
  await Stripe.instance.applySettings();

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
          scaffoldBackgroundColor: Colors.white,
          primaryColor: Colors.blueAccent,
        ),
        home: const SplashGate(), // always show splash first
        routes: {
          '/index'     : (_) => const IndexPage(),       // landing (not signed-in)
          '/auth'      : (_) => const AuthGate(),        // decides AdminMain/Main
          '/login'     : (_) => const LoginPage(),
          '/register'  : (_) => const RegisterPage(),
          '/verify'    : (_) => const VerifyEmailPage(),
          '/home'      : (_) => const MainPage(),
          '/adminHome' : (_) => const AdminMainPage(),
          '/map-picker': (_) => const PickLocationPage(),
        },
      ),
    );
  }
}

/// Splash → after 1.5s route:
/// - signed in? → /auth  (go straight to app)
/// - not signed in? → /index (public landing)
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});
  @override
  State<SplashGate> createState() => _SplashGateState();
}
class _SplashGateState extends State<SplashGate> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      final user = FirebaseAuth.instance.currentUser;
      Navigator.of(context).pushReplacementNamed(user == null ? '/index' : '/auth');
    });
  }
  @override
  Widget build(BuildContext context) => const StartPage();
}

/// AuthGate: live auth → reload email → stream users/{uid}.isAdmin → route
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(), // login/logout live
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) return const _Loading();
        final user = authSnap.data;

        // If user signs out while here, go back to Index
        if (user == null) return const IndexPage();

        // Refresh email verification before routing
        return FutureBuilder(
          future: user.reload(),
          builder: (context, reloadSnap) {
            if (reloadSnap.connectionState == ConnectionState.waiting) return const _Loading();
            final refreshed = FirebaseAuth.instance.currentUser!;
            if (!refreshed.emailVerified) return const VerifyEmailPage();

            // Live admin/customer
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').doc(refreshed.uid).snapshots(),
              builder: (context, userDocSnap) {
                if (userDocSnap.connectionState == ConnectionState.waiting) return const _Loading();
                final isAdmin = (userDocSnap.data?.data()?['isAdmin'] ?? false) == true;
                return isAdmin ? const AdminMainPage() : const MainPage();
              },
            );
          },
        );
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

/// Call this on any "Logout" button:
/// await AuthNavigator.signOutToIndex(context);
class AuthNavigator {
  static Future<void> signOutToIndex(BuildContext context) async {
    try { await FirebaseAuth.instance.signOut(); } catch (_) {}
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/index', (r) => false);
    }
  }
}
