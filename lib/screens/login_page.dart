
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'main_page.dart';
import 'register_page.dart';
import 'verify_email_page.dart';




class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final phoneController = TextEditingController();
  final smsCodeController = TextEditingController();

  final AuthService auth = AuthService();
  String _verificationId = '';
  bool _showPhoneField = false;
  bool _codeSent = false;
  bool _showPassword = false;
  bool _isLoading = false;

  // 🔐 EMAIL LOGIN
  Future<void> login() async {
    setState(() => _isLoading = true);
    final user = await auth.signIn(
      emailController.text.trim(),
      passwordController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (user != null) {
      if (!user.emailVerified) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const VerifyEmailPage()),
        );
      } else {
        Navigator.pushNamedAndRemoveUntil(context, '/auth', (r) => false);
      }
    } else {
      _showError("Invalid login. Please try again.");
    }
  }

  // 🔐 GOOGLE LOGIN
  Future<void> loginWithGoogle() async {
    setState(() => _isLoading = true);
    final user = await auth.signInWithGoogle();
    setState(() => _isLoading = false);

    if (user != null) {
      Navigator.pushNamedAndRemoveUntil(context, '/auth', (r) => false);
    } else {
      _showError("Google Sign-In failed.");
    }
  }

  // 🔐 PHONE LOGIN FLOW
  void _sendCode() async {
    final phone = phoneController.text.trim();
    if (phone.isEmpty) return;

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        Navigator.pushNamedAndRemoveUntil(context, '/auth', (r) => false);

      },
      verificationFailed: (e) => _showError('Verification failed: ${e.message}'),
      codeSent: (String id, int? token) {
        setState(() {
          _verificationId = id;
          _codeSent = true;
        });
      },
      codeAutoRetrievalTimeout: (id) => _verificationId = id,
    );
  }

  void _verifyCode() async {
    final code = smsCodeController.text.trim();
    if (code.isEmpty || _verificationId.isEmpty) return;

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: code,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      Navigator.pushNamedAndRemoveUntil(context, '/auth', (r) => false);

    } catch (_) {
      _showError("Invalid code.");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background/fade_base.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text("Welcome back!",
                      style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  _glassInput("Email", emailController),
                  const SizedBox(height: 14),
                  _glassInput("Password", passwordController, isPassword: true),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
                      child: const Text("Forgot Password?", style: TextStyle(color: Colors.white70)),
                    ),
                  ),

                  ElevatedButton(
                    onPressed: login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC70418),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text("Sign In", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),

                  const SizedBox(height: 20),
                  const Center(child: Text("Or continue with", style: TextStyle(color: Colors.white60))),

                  const SizedBox(height: 20),
                  _socialButton(
                    icon: Image.asset("assets/icons/google_icon.png", height: 22),
                    label: "Continue with Google",
                    onPressed: loginWithGoogle,
                  ),



                  const SizedBox(height: 20),
                  _socialButton(
                    icon: const Icon(Icons.phone, color: Colors.white),
                    label: "Continue with phone",
                    onPressed: () => setState(() => _showPhoneField = !_showPhoneField),
                  ),


                  if (_showPhoneField) ...[
                    const SizedBox(height: 14),
                    _glassInput("Phone Number", phoneController),
                    const SizedBox(height: 10),
                    if (_codeSent) _glassInput("SMS Code", smsCodeController),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.sms),
                      label: Text(_codeSent ? "Verify Code" : "Send Code"),
                      onPressed: _codeSent ? _verifyCode : _sendCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage())),
                    child: const Text("Don't have an account? Register",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 Glass-style input fields
  Widget _glassInput(String hint, TextEditingController controller, {bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? !_showPassword : false,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, color: Colors.white70),
          onPressed: () => setState(() => _showPassword = !_showPassword),
        )
            : null,
      ),
    );
  }

  // 🔹 Reusable social sign-in button
  Widget _socialButton({
    required Widget icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: icon,
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.06),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
