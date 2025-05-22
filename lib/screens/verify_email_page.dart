import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
      backgroundColor: const Color(0xFFA1BDC7),
      appBar: AppBar(
        title: const Text('Verify Your Email'),
        backgroundColor: Colors.black87,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.email_outlined, size: 60),
              const SizedBox(height: 20),
              const Text(
                "A verification link has been sent to your email.\nPlease verify to continue.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _sendVerificationEmail,
                icon: const Icon(Icons.send),
                label: const Text("Resend Verification Email"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                ),
              ),
              if (_errorOccurred)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    "Could not send email. Check connection.",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
