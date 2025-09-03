import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cadeli/screens/main_page.dart';
import 'package:cadeli/screens/verify_email_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  int currentStep = 0;
  bool isCodeSent = false;
  String? verificationId;
  double? pickedLat;
  double? pickedLng;


  final phoneController = TextEditingController();
  final otpController = TextEditingController();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final addressController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final otpFocusNodes = List.generate(6, (_) => FocusNode());
  final otpValues = List.filled(6, '');


  // ─────────────────────────────────────────
  // PHONE AUTH & FIRESTORE LOGIC (unchanged)
  String e164(String raw) {
    final p = raw.trim();
    if (p.startsWith('+')) return p;
    // fallback: prepend your default country code if needed
    return '+357$p';
  }

  void sendOtp() async {
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: e164(phoneController.text),
      verificationCompleted: (_) {},
      verificationFailed: (e) => _showError("Verification failed: ${e.message}"),
      codeSent: (id, _) => setState(() {
        verificationId = id;
        isCodeSent = true;
      }),
      codeAutoRetrievalTimeout: (id) => verificationId = id,
    );
  }

  void verifyOtp() async {
    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: verificationId!,
        smsCode: otpController.text.trim(),
      );
      await FirebaseAuth.instance.signInWithCredential(cred);
      nextStep();
    } catch (_) {
      _showError("Invalid OTP.");
    }
  }

  Future<void> createAccount() async {
    if (passwordController.text != confirmPasswordController.text) {
      _showError("Passwords do not match.");
      return;
    }

    // Must be signed in already via phone (after verifyOtp)
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError("Session expired. Please verify your phone again.");
      setState(() { currentStep = 0; isCodeSent = false; });
      return;
    }

    try {
      // 1) LINK email/password to the same account (no signOut!)
      final emailCred = EmailAuthProvider.credential(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      await user.linkWithCredential(emailCred);

      final uid = user.uid;

      // 2) Write/merge the user profile
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
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
        // store last known coordinates at root too (handy for queries)
        'lat': pickedLat,
        'lng': pickedLng,
      }, SetOptions(merge: true));

      // 3) Save a default address with coordinates
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('addresses')
          .add({
        'label': addressController.text.trim(),
        'isDefault': true,
        'timestamp': Timestamp.now(),
        // GeoPoint so you can use Firestore geospatial queries later
        'location': (pickedLat != null && pickedLng != null)
            ? GeoPoint(pickedLat!, pickedLng!)
            : null,
        // store scalar copies too (optional convenience)
        'lat': pickedLat,
        'lng': pickedLng,
      });

      // 4) (Optional but recommended) send email verification
      await user.sendEmailVerification();

      // 5) Move to the verify email screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const VerifyEmailPage()),
      );
    } catch (e) {
      _showError("Account creation failed: ${e.toString()}");
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void nextStep() {
    if (currentStep < 3) setState(() => currentStep++);
  }

  void prevStep() {
    if (currentStep > 0) setState(() => currentStep--);
  }
  // ─────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(fit: StackFit.expand, children: [
        // background blur
        Image.asset("assets/background/fade_base.jpg", fit: BoxFit.cover),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            color: Colors.black.withOpacity(0.2),
            child: Column(
              children: [
                // ───── SCROLLABLE CONTENT ─────
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.zero,
                    child: buildStepContent(),
                  ),
                ),

                // ───── FIXED BOTTOM BAR ─────
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Primary Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: () {
                            if (currentStep == 0) {
                              isCodeSent ? verifyOtp() : sendOtp();
                            } else if (currentStep < 3) {
                              nextStep();
                            } else {
                              createAccount();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC70418),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            currentStep == 0
                                ? (isCodeSent ? "Verify Code" : "Send Code")
                                : (currentStep < 3
                                ? "Save & Continue"
                                : "Create Account"),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Sign-In Redirect
                      GestureDetector(
                        onTap: () =>
                            Navigator.pushReplacementNamed(context, '/login'),
                        child: const Text(
                          "Already have an account? Sign in",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ───────────────────────────────
              ],
            ),
          ),
        ),
      ]),
    );
  }

  /// Builds the content for each step (no more “timeline” bubbles)
  Widget buildStepContent() {
    switch (currentStep) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),

            // Top back arrow in a circle + “Back to Home” text
            GestureDetector(
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const MainPage()),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "start",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 50),
            // Step Title
            const Center(
              child: Text(
                "Phone Verification",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),

            _formLabel("Phone Number"),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _input(
                controller: phoneController,
                hint: "(+357 99888777)",
                keyboardType: TextInputType.phone,
              ),
            ),

            if (isCodeSent) ...[
              const SizedBox(height: 24),
              _formLabel("Enter OTP Code"),
              const SizedBox(height: 16),
              _buildOtpFields(),
            ],

            // extra space so content isn’t hidden behind bottom bar
            const SizedBox(height: 120),
          ],
        );

      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            // Glassy “Previous Step” button
            Align(
              alignment: Alignment.centerLeft,
              child: _glassyButton(
                label: "Previous Step",
                onTap: prevStep,
              ),
            ),
            const SizedBox(height: 40),
            // Step Title
            const Center(
              child: Text(
                "Personal Info",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),

            _formLabel("First Name"),
            _input(controller: nameController, hint: "Enter name"),
            const SizedBox(height: 20),

            _formLabel("Email"),
            _input(
              controller: emailController,
              hint: "Enter email",
              keyboardType: TextInputType.emailAddress,
            ),

            const SizedBox(height: 120),
          ],
        );

      case 2:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Align(
                alignment: Alignment.centerLeft,
                child: _glassyButton(
                  label: "Previous Step",
                  onTap: prevStep,
                ),
              ),
              const SizedBox(height: 40),
              const Center(
                child: Text(
                  "Delivery Address",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              _formLabel("Address"),
              _input(controller: addressController, hint: "Start typing your address..."),

              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  // Expect your map picker to return: { 'label': String, 'lat': double, 'lng': double }
                  final picked = await Navigator.pushNamed(context, '/map-picker');

                  if (picked is Map) {
                    setState(() {
                      addressController.text = (picked['label'] as String?) ?? '';
                      pickedLat = picked['lat'] as double?;
                      pickedLng = picked['lng'] as double?;
                    });
                  } else if (picked is String && picked.isNotEmpty) {
                    // Backwards-compat: if your picker still returns only a string
                    setState(() => addressController.text = picked);
                    pickedLat = null;
                    pickedLng = null;
                  }
                },

                icon: const Icon(Icons.map),
                label: const Text("Choose on Map",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                ),
              ),

              const SizedBox(height: 120),
            ],
          ),
        );

      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            Align(
              alignment: Alignment.centerLeft,
              child: _glassyButton(
                label: "Previous Step",
                onTap: prevStep,
              ),
            ),
            const SizedBox(height: 40),
            const Center(
              child: Text(
                "Create Password",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),

            _formLabel("Password"),
            _input(controller: passwordController, hint: "Enter password", obscure: true),
            const SizedBox(height: 20),

            _formLabel("Confirm Password"),
            _input(controller: confirmPasswordController, hint: "Repeat password", obscure: true),

            const SizedBox(height: 120),
          ],
        );

      default:
        return const SizedBox();
    }
  }

  // ─────────────────────────────────────────
  // TextField builder with larger padding & font
  Widget _input({
    required TextEditingController controller,
    String hint = '',
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.white.withOpacity(0.9),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // Larger, bold white labels
  Widget _formLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  // OTP fields (unchanged size increase)
  Widget _buildOtpFields() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(6, (i) {
        return SizedBox(
          width: 45,
          height: 55,
          child: TextField(
            focusNode: otpFocusNodes[i],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            style: const TextStyle(
              fontSize: 22,
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
            onChanged: (v) {
              otpValues[i] = v;
              if (v.isNotEmpty && i < 5) {
                FocusScope.of(context).requestFocus(otpFocusNodes[i + 1]);
              }
              otpController.text = otpValues.join();
            },
          ),
        );
      }),
    );
  }

  // Glassy “Previous Step” button
  Widget _glassyButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              offset: Offset(0, 4),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
          border: Border.all(
            color: Colors.white54,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
          ),
        ),
      ),
    );
  }
}
