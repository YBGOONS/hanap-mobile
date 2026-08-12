import 'package:flutter/services.dart';

/// Caps input at 11 digits and groups it "0917 123 4567" as the user
/// types — matches the shape of a normal PH mobile number, so it's not
/// possible to type in an overly long/garbled value in the first place.
class PhPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final capped = digits.substring(0, digits.length > 11 ? 11 : digits.length);
    final buffer = StringBuffer();
    for (var i = 0; i < capped.length; i++) {
      if (i == 4 || i == 7) buffer.write(' ');
      buffer.write(capped[i]);
    }
    return TextEditingValue(text: buffer.toString(), selection: TextSelection.collapsed(offset: buffer.length));
  }
}

/// A normal PH mobile number: exactly 11 digits, starting with "09"
/// (e.g. 0917 123 4567) — this is what GCash/PayMongo expect, so it's
/// enforced everywhere a phone number is collected (registration, and
/// each role's Profile/Settings screen).
bool isValidPhMobile(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  return RegExp(r'^09\d{9}$').hasMatch(digits);
}

const phPhoneErrorMessage = "Enter a valid PH mobile number (e.g. 0917 123 4567).";
