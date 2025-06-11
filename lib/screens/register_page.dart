import 'dart:ui';
import 'package:cadeli/screens/main_page.dart';
import 'package:cadeli/screens/verify_email_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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

  List<FocusNode> otpFocusNodes = List.generate(6, (_) => FocusNode());
  List<String> otpValues = List.filled(6, '');

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
      await FirebaseAuth.instance.signOut();

      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'fullName': nameController.text.trim(),
        'email': emailController.text.trim(),
        'phone': phoneController.text.trim(),
        'address': addressController.text.trim(),
        'notes': '',
        'bio': '',
        'favourites': [],
        'orderHistory': [],
        'activeOrders': [],
        'createdAt': Timestamp.now(),
      });
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .collection('addresses')
          .add({
        'label': addressController.text.trim(),
        'isDefault': true,
        'timestamp': Timestamp.now(),
      });



      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const VerifyEmailPage()));
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            // 🔙 Back Button
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                onPressed: prevStep,
                tooltip: "Back to index",
                style: ButtonStyle(
                  overlayColor: MaterialStateProperty.all(Colors.transparent),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // 🔄 Timeline
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(4, (index) {
                  bool isActive = index == currentStep;
                  bool isCompleted = index < currentStep;

                  return CircleAvatar(
                    radius: 18,
                    backgroundColor: isCompleted
                        ? Colors.blueGrey
                        : isActive
                        ? Colors.blueAccent
                        : Colors.white.withOpacity(0.7),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 30),

            // 📱 Phone Title
            const Text("Phone Verification",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            _formLabel("Phone Number"),

            // ☎️ Phone Input (styled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
                decoration: InputDecoration(
                  hintText: " e.g (+357 99888777)",
                  hintStyle: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            if (isCodeSent) ...[
              const SizedBox(height: 18),
              _formLabel("Enter OTP Code"),
              const SizedBox(height: 14),
              _buildOtpFields(context),
            ],


            const SizedBox(height: 30),

            // 📤 Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _button(
                isCodeSent ? "Verify Code" : "Send Code",
                onPressed: isCodeSent ? verifyOtp : sendOtp,
              ),
            ),
            _loginRedirect(),
          ],

        );

      case 1:
        return Column(

          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: prevStep,
                tooltip: "Back to previous step",
              ),
            ),


            // Timeline bubbles
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(4, (index) {
                  bool isActive = index == currentStep;
                  bool isCompleted = index < currentStep;

                  return CircleAvatar(
                    radius: 18,
                    backgroundColor: isCompleted
                        ? Colors.blueGrey
                        : isActive
                        ? Colors.blueAccent
                        : Colors.white.withOpacity(0.7),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 30),

            const Text("Personal Info",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),

            const SizedBox(height: 16),
            _formLabel("First Name"),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _input(nameController, hint: "Enter name"),
            ),
            const SizedBox(height: 10),
            _formLabel("Email"),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _input(emailController, hint: "Enter email", keyboardType: TextInputType.emailAddress),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _button("Save & Continue", onPressed: nextStep),
            ),
            _loginRedirect(),
          ],
        );



      case 2:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: prevStep,
                  tooltip: "Previous step",
                ),
              ),

              const SizedBox(height: 30),

              // 🚚 Page Title
              const Text(
                "Delivery Address",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 16),

              // 🏠 Address Input Field (Google Suggest)
              _formLabel("Address"),
              _input(addressController, hint: "Start typing your address..."),

              const SizedBox(height: 16),

              // 🗺️ Choose on Map Button
              ElevatedButton.icon(
                onPressed: () async {
                  final picked = await Navigator.pushNamed(context, '/map-picker');
                  if (picked is String && picked.isNotEmpty) {
                    setState(() {
                      addressController.text = picked;
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.map),
                label: const Text("Choose on Map", style: TextStyle(fontWeight: FontWeight.bold)),
              ),

              const SizedBox(height: 24),

              // ✅ Save Button
              _button("Save & Continue", onPressed: () {
                if (addressController.text.trim().isEmpty) {
                  _showError("Please enter your address.");
                } else {
                  nextStep();
                }
              }),
              _loginRedirect(),
            ],
          ),
        );

      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: prevStep,
                tooltip: "Previous step",
              ),
            ),

            const Text("Create Password", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _formLabel("Password"),
            _input(passwordController, hint: "Enter password", obscure: true),
            const SizedBox(height: 10),
            _formLabel("Confirm Password"),
            _input(confirmPasswordController, hint: "Repeat password", obscure: true),
            const SizedBox(height: 20),
            _button("Create Account", onPressed: createAccount),
            _loginRedirect(),
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
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  Widget _loginRedirect() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Center(
        child: GestureDetector(
          onTap: () => Navigator.pushReplacementNamed(context, '/login'),
          child: const Text(
            "Already have an account? Sign in",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
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

  Widget _buildOtpFields(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(6, (index) {
        return SizedBox(
          width: 40,
          height: 50,
          child: TextField(
            focusNode: otpFocusNodes[index],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: Colors.white.withOpacity(0.95),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) {
              otpValues[index] = value;
              if (value.isNotEmpty && index < 5) {
                FocusScope.of(context).requestFocus(otpFocusNodes[index + 1]);
              }
              otpController.text = otpValues.join();
            },
          ),
        );
      }),
    );
  }
}




