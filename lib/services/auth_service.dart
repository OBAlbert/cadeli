import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 🔐 Sign in with email/password
  Future<User?> signIn(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!result.user!.emailVerified) {
        await result.user!.sendEmailVerification();
        print('Verification email sent');
      }

      return result.user;
    } catch (e) {
      print('Login Error: $e');
      return null;
    }
  }

  /// 📝 Register user and send verification
  Future<User?> register(String email, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = result.user;

      if (user != null) {
        // 1. Send verification
        await user.sendEmailVerification();

        // 2. Create Firestore profile
        final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final doc = await docRef.get();

        if (!doc.exists) {
          await docRef.set({
            'email': email,
            'fullName': '',
            'address': '',
            'phone': '',
            'bio': '',
            'favourites': [],
            'orderHistory': [],
            'activeOrders': [],
            'createdAt': Timestamp.now(),
          });
          print("User data saved to Firestore");
        } else {
          print("User doc already exists");
        }
      }

      return user;
    } catch (e) {
      print('Registration error: $e');
      return null;
    }
  }

  /// 🧼 Log out user
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// 👤 Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// 🔑 Google Sign-In
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null; // User cancelled

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      // Create profile if new
      final docRef = FirebaseFirestore.instance.collection('users').doc(user!.uid);
      final doc = await docRef.get();
      if (!doc.exists) {
        await docRef.set({
          'email': user.email,
          'fullName': user.displayName ?? '',
          'address': '',
          'phone': user.phoneNumber ?? '',
          'bio': '',
          'favourites': [],
          'orderHistory': [],
          'activeOrders': [],
          'createdAt': Timestamp.now(),
        });
      }

      return user;
    } catch (e) {
      print("Google Sign-In error: $e");
      return null;
    }
  }
}
