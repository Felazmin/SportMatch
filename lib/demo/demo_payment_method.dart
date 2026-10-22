class DemoPaymentMethod {
  const DemoPaymentMethod({
    required this.provider,
    required this.last4,
    this.isDefault = false,
  });
  final String provider, last4;
  final bool isDefault;
  bool get isCard => provider == 'Visa' || provider == 'Mastercard';
  String get id => '$provider-$last4';
  Map<String, Object?> toJson() => {
    'provider': provider,
    'last4': last4,
    'default': isDefault,
  };
  factory DemoPaymentMethod.fromJson(Map<String, dynamic> json) {
    final method = DemoPaymentMethod(
      provider: json['provider'] as String,
      last4: json['last4'] as String,
      isDefault: (json['default'] ?? false) as bool,
    );
    if (!['Visa', 'Mastercard', 'MoMo', 'ZaloPay'].contains(method.provider) ||
        !RegExp(r'^\d{4}$').hasMatch(method.last4)) {
      throw const FormatException('Invalid demo payment method');
    }
    return method;
  }
}
