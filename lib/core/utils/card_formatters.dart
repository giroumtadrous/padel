import 'package:flutter/services.dart';

class CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.length > 16) text = text.substring(0, 16);
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i + 1) % 4 == 0 && i != text.length - 1) buffer.write(' ');
    }
    final result = buffer.toString();
    return newValue.copyWith(text: result, selection: TextSelection.collapsed(offset: result.length));
  }
}

class CardExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.length > 4) text = text.substring(0, 4);
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if (i == 1 && i != text.length - 1) buffer.write('/');
    }
    final result = buffer.toString();
    return newValue.copyWith(text: result, selection: TextSelection.collapsed(offset: result.length));
  }
}

/// Detects card network from the leading digits so the UI can show a
/// Visa/Mastercard badge as the user types.
enum CardNetwork { visa, mastercard, unknown }

CardNetwork detectCardNetwork(String digits) {
  if (digits.startsWith('4')) return CardNetwork.visa;
  if (digits.isNotEmpty) {
    final prefix2 = digits.length >= 2 ? int.tryParse(digits.substring(0, 2)) : null;
    final prefix4 = digits.length >= 4 ? int.tryParse(digits.substring(0, 4)) : null;
    if (prefix2 != null && prefix2 >= 51 && prefix2 <= 55) return CardNetwork.mastercard;
    if (prefix4 != null && prefix4 >= 2221 && prefix4 <= 2720) return CardNetwork.mastercard;
  }
  return CardNetwork.unknown;
}
