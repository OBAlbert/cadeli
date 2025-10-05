import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/payment_method.dart';

class PaymentPrefs {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // SAVE selected payment method
  static Future<void> saveSelectedPaymentMethod(PaymentMethod method) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _firestore.collection('users').doc(uid).update({
      'selectedPayment': method.toMap(),
    });
  }

  // LOAD selected payment method
  static Future<PaymentMethod?> getSelectedPaymentMethod() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final doc = await _firestore.collection('users').doc(uid).get();
    final data = doc.data();
    if (data == null || !data.containsKey('selectedPayment')) return null;

    return PaymentMethod.fromMap(data['selectedPayment']);
  }
}
