class PaymentMethod {
  final String type;     // e.g. "visa", "mastercard", "cod", "apple_pay"
  final String last4;    // last 4 digits, e.g. "4242"
  final String expiry;   // e.g. "12/26"

  PaymentMethod({
    required this.type,
    this.last4 = '',
    this.expiry = '',
  });

  factory PaymentMethod.fromMap(Map<String, dynamic> map) {
    return PaymentMethod(
      type: map['type'] ?? '',
      last4: map['last4'] ?? '',
      expiry: map['expiry'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'last4': last4,
      'expiry': expiry,
    };
  }
}
