import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment_method.dart';

class AddPaymentMethodPage extends StatefulWidget {
  const AddPaymentMethodPage({super.key});

  @override
  State<AddPaymentMethodPage> createState() => _AddPaymentMethodPageState();
}

class _AddPaymentMethodPageState extends State<AddPaymentMethodPage> {
  final _cardNumberController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _expiryMonthController = TextEditingController();
  final _expiryYearController = TextEditingController();
  final _cvvController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  String cardType = 'unknown';

  @override
  void initState() {
    super.initState();
    _cardNumberController.addListener(_detectCardType);
  }

  void _detectCardType() {
    final number = _cardNumberController.text.replaceAll(RegExp(r'\s'), '');
    String detectedType = 'unknown';

    if (RegExp(r'^4').hasMatch(number)) {
      detectedType = 'visa';
    } else if (RegExp(r'^5[1-5]').hasMatch(number)) {
      detectedType = 'mastercard';
    }

    if (cardType != detectedType) {
      setState(() => cardType = detectedType);
    }
  }

  String? _validateCardNumber(String? value) {
    if (value == null || value.isEmpty) return 'Card number is required';
    final digits = value.replaceAll(RegExp(r'\s'), '');
    if (digits.length < 13 || digits.length > 19) return 'Invalid card number';
    return null;
  }

  String? _validateExpiryMonth(String? value) {
    if (value == null || value.isEmpty) return 'Month is required';
    final month = int.tryParse(value) ?? 0;
    if (month < 1 || month > 12) return 'Invalid month';
    return null;
  }

  String? _validateExpiryYear(String? value) {
    if (value == null || value.isEmpty) return 'Year is required';
    final year = int.tryParse(value) ?? 0;
    final currentYear = DateTime.now().year % 100;
    if (year < currentYear || year > currentYear + 20) return 'Invalid year';
    return null;
  }

  String? _validateCVV(String? value) {
    if (value == null || value.isEmpty) return 'CVV is required';
    if (value.length < 3 || value.length > 4) return 'Invalid CVV';
    return null;
  }

  Future<void> savePaymentMethod() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final cardNumber = _cardNumberController.text.trim();
    final cardHolder = _cardHolderController.text.trim();
    final expiryMonth = _expiryMonthController.text.trim();
    final expiryYear = _expiryYearController.text.trim();
    final cvv = _cvvController.text.trim();

    final last4 = cardNumber.substring(cardNumber.length - 4);
    final expiry = '$expiryMonth/${expiryYear.length == 2 ? '20$expiryYear' : expiryYear}';

    final method = PaymentMethod(
      type: cardType,
      last4: last4,
      expiry: expiry,
    );

    setState(() => isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('paymentMethods')
          .add(method.toMap());
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving card: ${e.toString()}')),
      );
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF254573);
    const buttonColor = Color(0xFFC70418);
    const backgroundColor = Color(0xFFF5F5F5);
    const cardBackground = Color(0xE6FFFFFF);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Add Payment Method',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Card Container
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black.withOpacity(0.1)),
                    boxShadow: [
                      BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card Type Logo
                    Align(
                      alignment: Alignment.centerRight,
                      child: cardType == 'visa'
                          ? Image.asset(
                        'assets/icons/visa.png',
                        height: 30,
                        width: 50,
                        fit: BoxFit.contain,
                      )
                          : cardType == 'mastercard'
                          ? Image.asset(
                        'assets/icons/mastercard.png',
                        height: 30,
                        width: 50,
                        fit: BoxFit.contain,
                      )
                          : const Icon(
                        Icons.credit_card,
                        size: 30,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Card Number Field
                    const Text(
                      'CARD NUMBER',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextFormField(
                        controller: _cardNumberController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(19),
                          CardNumberFormatter(),
                        ],
                        validator: _validateCardNumber,
                        decoration: const InputDecoration(
                          hintText: '1234 5678 9012 3456',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Cardholder Name Field
                    const Text(
                      'CARDHOLDER NAME',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextFormField(
                        controller: _cardHolderController,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) =>
                        value?.isEmpty ?? true ? 'Name is required' : null,
                        decoration: const InputDecoration(
                          hintText: 'John Doe',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Expiry Date and CVV Row
                    Row(
                      children: [
                        // Expiry Date
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'EXPIRY DATE',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  children: [
                                    // Month
                                    Flexible(
                                      child: TextFormField(
                                        controller: _expiryMonthController,
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 16,
                                        ),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          LengthLimitingTextInputFormatter(2),
                                        ],
                                        validator: _validateExpiryMonth,
                                        decoration: const InputDecoration(
                                          hintText: 'MM',
                                          hintStyle: TextStyle(color: Colors.grey),
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 4),
                                      child: Text(
                                        '/',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    // Year
                                    Flexible(
                                      child: TextFormField(
                                        controller: _expiryYearController,
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 16,
                                        ),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          LengthLimitingTextInputFormatter(2),
                                        ],
                                        validator: _validateExpiryYear,
                                        decoration: const InputDecoration(
                                          hintText: 'YY',
                                          hintStyle: TextStyle(color: Colors.grey),
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),

                        // CVV
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CVV',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: TextFormField(
                                  controller: _cvvController,
                                  keyboardType: TextInputType.number,
                                  obscureText: true,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 16,
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(4),
                                  ],
                                  validator: _validateCVV,
                                  decoration: const InputDecoration(
                                    hintText: '123',
                                    hintStyle: TextStyle(color: Colors.grey),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : savePaymentMethod,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text(
                    'SAVE CARD',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final text = newValue.text.replaceAll(RegExp(r'\s'), '');

    if (text.isEmpty) return newValue;

    String formatted = '';
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) formatted += ' ';
      formatted += text[i];
    }

    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}