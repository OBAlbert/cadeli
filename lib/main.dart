//import 'package:cadeli/screens/admin_page.dart';
import 'package:cadeli/screens/products_page.dart';
import 'package:cadeli/screens/register_page.dart';
import 'package:cadeli/screens/test_brand_scroll.dart';
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
import 'screens/pick_location_page.dart';
import 'services/notification_service.dart';


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

  await NotificationService.initialize();

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
        home: const StartRouter(),

        //home: const StartToIndexRouter(),

        routes: {
          '/map-picker': (context) => const PickLocationPage(),
          '/login': (context) => const LoginPage(),
          '/register': (context) => const RegisterPage(),
          '/verify': (context) => const VerifyEmailPage(),
        },
      ),
    );
  }

  // @override
  // Widget build(BuildContext context) {
  //   return MaterialApp(
  //     title: 'Cadeli Test',
  //     debugShowCheckedModeBanner: false,
  //     theme: ThemeData(
  //       primarySwatch: Colors.blue,
  //       useMaterial3: true,
  //     ),
  //     home: const TestBrandScrollPage(), // 👈 Just swap this for now
  //   );
  // }

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

class StartRouter extends StatefulWidget {
  const StartRouter({super.key});

  @override
  State<StartRouter> createState() => _StartRouterState();
}

class _StartRouterState extends State<StartRouter> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthGate()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const StartPage(); // Your splash screen
  }
}


