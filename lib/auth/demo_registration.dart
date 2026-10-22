class DemoRegistration {
  DemoRegistration({required this.identifier, required this.issued});
  static const code = '123456';
  final String identifier;
  final DateTime issued;
  DateTime get expires => issued.add(const Duration(minutes: 5));
  DateTime get resendAt => issued.add(const Duration(seconds: 60));
  int attempts = 0;
  bool consumed = false;
}
