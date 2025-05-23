import 'dart:ui'; // 👈 Needed for blur effect
import 'package:flutter/material.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';
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
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController smsCodeController = TextEditingController();

  final AuthService auth = AuthService();
  String _verificationId = '';
  bool _showPhoneField = false;
  bool _codeSent = false;
  bool _showPassword = false;

  Future<void> login() async {
    final user = await auth.signIn(
      emailController.text.trim(),
      passwordController.text.trim(),
    );

    if (user != null) {
      if (!user.emailVerified) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const VerifyEmailPage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainPage()),
        );
      }
    } else {
      _showError("Login failed. Please check your credentials.");
    }
  }

  Future<void> loginWithGoogle() async {
    final user = await auth.signInWithGoogle();
    if (user != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainPage()),
      );
    } else {
      _showError("Google Sign-In failed.");
    }
  }

  void _sendCode() async {
    final phone = phoneController.text.trim();
    if (phone.isEmpty) return;

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainPage()));
      },
      verificationFailed: (FirebaseAuthException e) {
        _showError('Verification failed: ${e.message}');
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _codeSent = true;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
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
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainPage()));
    } catch (e) {
      _showError("Invalid SMS code.");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background/fade_base.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  // children: [
                  //   const Text(
                  //     "Hello Again!",
                  //     textAlign: TextAlign.center,
                  //     style: TextStyle(
                  //       fontSize: 28,
                  //       fontWeight: FontWeight.bold,
                  //       color: Colors.white,
                  //     ),
                  //   ),
                  //   SizedBox(height: 4),
                  //   const Text(
                  //     "Set it once. Forget the rest.",
                  //     textAlign: TextAlign.center,
                  //     style: TextStyle(
                  //       fontSize: 14,
                  //       color: Colors.white70,
                  //     ),
                  //   ),
                  //
                  //   _glassInput("Enter email", emailController),
                  //   const SizedBox(height: 14),
                  //   _glassInput("Password", passwordController, isPassword: true),
                  //
                  //   const SizedBox(height: 6),
                  //   Align(
                  //     alignment: Alignment.centerRight,
                  //     child: TextButton(
                  //       onPressed: () {},
                  //       child: const Text(
                  //         "Recovery Password",
                  //         style: TextStyle(fontSize: 12, color: Colors.white),
                  //       ),
                  //     ),
                  //   ),
                  //
                  //   // 🔴 Sign In Button (C70418)
                  //   ElevatedButton(
                  //     onPressed: login,
                  //     style: ElevatedButton.styleFrom(
                  //       backgroundColor: const Color(0xFFC70418),
                  //       padding: const EdgeInsets.symmetric(vertical: 14),
                  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  //     ),
                  //     child: const Text("Sign In", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  //   ),
                  //
                  //   const SizedBox(height: 20),
                  //   const Center(child: Text("Or continue with", style: TextStyle(color: Colors.white70))),
                  //   const SizedBox(height: 12),
                  //
                  //   Row(
                  //     mainAxisAlignment: MainAxisAlignment.center,
                  //     children: [
                  //       SignInButton(
                  //         Buttons.GoogleDark,
                  //         onPressed: loginWithGoogle,
                  //       ),
                  //       const SizedBox(width: 16),
                  //       IconButton(
                  //         icon: const Icon(Icons.phone, size: 30, color: Colors.white),
                  //         onPressed: () => setState(() => _showPhoneField = !_showPhoneField),
                  //       ),
                  //     ],
                  //   ),
                  //
                  //   const SizedBox(height: 16),
                  //
                  //   if (_showPhoneField) ...[
                  //     _glassInput("Enter phone (e.g. +357...)", phoneController),
                  //     const SizedBox(height: 10),
                  //     if (_codeSent)
                  //       _glassInput("Enter code", smsCodeController),
                  //     const SizedBox(height: 10),
                  //     ElevatedButton.icon(
                  //       icon: const Icon(Icons.sms),
                  //       label: Text(_codeSent ? "Verify Code" : "Send SMS Code"),
                  //       onPressed: _codeSent ? _verifyCode : _sendCode,
                  //       style: ElevatedButton.styleFrom(
                  //         backgroundColor: Colors.blueAccent,
                  //         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  //       ),
                  //     ),
                  //   ],
                  //
                  //   const SizedBox(height: 20),
                  //   Row(
                  //     mainAxisAlignment: MainAxisAlignment.center,
                  //     children: [
                  //       const Text("Not a member? ", style: TextStyle(color: Colors.white)),
                  //       GestureDetector(
                  //         onTap: () {
                  //           Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage()));
                  //         },
                  //         child: const Text(
                  //           "Register now",
                  //           style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purpleAccent),
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                  // ],
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(height: 10),

                const SizedBox(height: 16),

                const Text(
                  "Hello Again!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),

                const Text(
                  "Set it once. Forget the rest.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),

                const SizedBox(height: 32),

                _glassInput("Username or email", emailController),
                const SizedBox(height: 16),
                _glassInput("Password", passwordController, isPassword: true),

                const SizedBox(height: 8),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: const Text(
                      "Recovery password",
                      style: TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                ElevatedButton(
                  onPressed: login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC70418),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text("Sign in", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),

                const SizedBox(height: 24),

                Row(
                  children: const [
                    Expanded(child: Divider(color: Colors.white38)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text("or continue with", style: TextStyle(color: Colors.white70)),
                    ),
                    Expanded(child: Divider(color: Colors.white38)),
                  ],
                ),

                const SizedBox(height: 16),

                // Row(
                //   mainAxisAlignment: MainAxisAlignment.center,
                //   children: [
                //     SignInButton(
                //       Buttons.GoogleDark,
                //       padding: const EdgeInsets.symmetric(horizontal: 12),
                //       onPressed: loginWithGoogle,
                //     ),
                //     const SizedBox(width: 12),
                //     IconButton(
                //       icon: const Icon(Icons.phone, size: 28, color: Colors.white),
                //       onPressed: () => setState(() => _showPhoneField = !_showPhoneField),
                //     ),
                //   ],
                // ),
                const SizedBox(height: 16),

                // Google Sign-In styled button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.g_mobiledata, color: Colors.white, size: 28),
                    label: const Text(
                      "Continue with Google",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    onPressed: loginWithGoogle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.05),
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Phone Sign-In styled button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.phone, color: Colors.white),
                    label: const Text(
                      "Continue with phone number",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    onPressed: () => setState(() => _showPhoneField = !_showPhoneField),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.05),
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),


                if (_showPhoneField) ...[
                  const SizedBox(height: 16),
                  _glassInput("Enter phone (e.g. +357...)", phoneController),
                  const SizedBox(height: 10),
                  if (_codeSent) _glassInput("Enter code", smsCodeController),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.sms),
                    label: Text(_codeSent ? "Verify Code" : "Send SMS Code"),
                    onPressed: _codeSent ? _verifyCode : _sendCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage()));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.05),
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      "Create an account",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),


                const SizedBox(height: 16),

                const Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: Text(
                    "Information about your login or registration.\nBy signing up you agree to our terms and conditions and privacy policy.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ),

              ],

            ),
              ),
            ),
          ),
        );
  }


  // 🔹 Custom glassy TextField builder
  Widget _glassInput(String hint, TextEditingController controller, {bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? !_showPassword : false,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(
            _showPassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.white70,
          ),
          onPressed: () => setState(() => _showPassword = !_showPassword),
        )
            : null,
      ),
    );
  }
}
