import 'dart:ui';
import 'package:cadeli/screens/main_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// or wherever your MainPage is located

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  int currentStep = 0;
  bool isCodeSent = false;
  String? verificationId;

  final TextEditingController phoneController = TextEditingController();
  final TextEditingController otpController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  // Firebase Phone Auth
  void sendOtp() async {
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneController.text.trim(),
      verificationCompleted: (_) {},
      verificationFailed: (e) {
        _showError("Verification failed: ${e.message}");
      },
      codeSent: (id, _) {
        setState(() {
          verificationId = id;
          isCodeSent = true;
        });
      },
      codeAutoRetrievalTimeout: (id) => verificationId = id,
    );
  }

  void verifyOtp() async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId!,
        smsCode: otpController.text.trim(),
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      nextStep(); // Proceed
    } catch (e) {
      _showError("Invalid OTP.");
    }
  }

  void createAccount() async {
    if (passwordController.text != confirmPasswordController.text) {
      _showError("Passwords do not match.");
      return;
    }

    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'phone': phoneController.text.trim(),
        'address': addressController.text.trim(),
        'city': cityController.text.trim(),
        'createdAt': Timestamp.now(),
      });

      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainPage()));
    } catch (e) {
      _showError("Account creation failed: ${e.toString()}");
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void nextStep() {
    if (currentStep < 3) {
      setState(() => currentStep++);
    }
  }

  void prevStep() {
    if (currentStep > 0) {
      setState(() => currentStep--);
    }
  }

  Widget buildStepContent() {
    switch (currentStep) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Phone Verification", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _formLabel("Phone Number"),
            _input(phoneController, hint: "+357...", keyboardType: TextInputType.phone),
            if (isCodeSent) ...[
              const SizedBox(height: 12),
              _formLabel("Enter OTP Code"),
              _input(otpController, hint: "6-digit code", keyboardType: TextInputType.number),
            ],
            const SizedBox(height: 20),
            _button(isCodeSent ? "Verify Code" : "Send Code", onPressed: isCodeSent ? verifyOtp : sendOtp),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Personal Info", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _formLabel("First Name"),
            _input(nameController, hint: "Enter name"),
            const SizedBox(height: 10),
            _formLabel("Email"),
            _input(emailController, hint: "Enter email", keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 20),
            _button("Save & Continue", onPressed: nextStep),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Delivery Address", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _formLabel("Address"),
            _input(addressController, hint: "Street, Building, etc."),
            const SizedBox(height: 10),
            _formLabel("City"),
            _input(cityController, hint: "City or Area"),
            const SizedBox(height: 20),
            _button("Save & Continue", onPressed: nextStep),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Create Password", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _formLabel("Password"),
            _input(passwordController, hint: "Enter password", obscure: true),
            const SizedBox(height: 10),
            _formLabel("Confirm Password"),
            _input(confirmPasswordController, hint: "Repeat password", obscure: true),
            const SizedBox(height: 20),
            _button("Create Account", onPressed: createAccount),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  Widget _input(TextEditingController ctrl, {String hint = '', bool obscure = false, TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white.withOpacity(0.9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _formLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }

  Widget _button(String text, {required VoidCallback onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFC70418),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            "assets/background/fade_base.jpg",
            fit: BoxFit.cover,
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              color: Colors.black.withOpacity(0.2),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
              child: Column(
                children: [
                  if (currentStep > 0)
                    Align(
                      alignment: Alignment.topLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: prevStep,
                      ),
                    ),
                  const SizedBox(height: 10),
                  Expanded(child: SingleChildScrollView(child: buildStepContent())),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
