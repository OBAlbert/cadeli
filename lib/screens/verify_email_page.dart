import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main_page.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool _emailVerified = false;
  bool _errorOccurred = false;
  late final User _user;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser!;
    _emailVerified = _user.emailVerified;

    if (!_emailVerified) {
      _sendVerificationEmail();
      _startEmailCheckTimer();
    }
  }

  void _sendVerificationEmail() async {
    try {
      await _user.sendEmailVerification();
    } catch (e) {
      debugPrint("Error sending email: $e");
      setState(() => _errorOccurred = true);
    }
  }

  void _startEmailCheckTimer() {
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        await _user.reload();
        final refreshedUser = FirebaseAuth.instance.currentUser;
        if (refreshedUser != null && refreshedUser.emailVerified) {
          _timer.cancel();
          Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (_) => const MainPage(),
          ));
        }
      } catch (e) {
        debugPrint("Timer check error: $e");
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/background/fade_base.jpg',
            fit: BoxFit.cover,
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              color: Colors.black.withOpacity(0.2),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.email_outlined, size: 80, color: Colors.white),
                  const SizedBox(height: 20),
                  const Text(
                    "Verify Your Email",
                    style: TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "We've sent a verification link to your email.\nPlease confirm to access your account.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _sendVerificationEmail,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text("Resend Email", style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  if (_errorOccurred)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Text(
                        "Could not send email. Please check your connection.",
                        style: TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
