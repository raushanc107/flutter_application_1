import 'dart:math' as math;

import 'package:flutter/services.dart';

/// Card types as stored in the `saved_cards.card_type` column.
class CardTypes {
  static const credit = 'CREDIT';
  static const debit = 'DEBIT';
  static const prepaid = 'PREPAID';
  static const other = 'OTHER';
  static const all = [credit, debit, prepaid, other];

  static String label(String type) {
    switch (type) {
      case credit:
        return 'Credit';
      case debit:
        return 'Debit';
      case prepaid:
        return 'Prepaid';
      default:
        return 'Other';
    }
  }
}

/// Card networks as stored in the `saved_cards.network` column.
class CardNetworks {
  static const visa = 'visa';
  static const mastercard = 'mastercard';
  static const rupay = 'rupay';
  static const amex = 'amex';
  static const other = 'other';
  static const all = [visa, mastercard, rupay, amex, other];

  static String label(String network) {
    switch (network) {
      case visa:
        return 'Visa';
      case mastercard:
        return 'Mastercard';
      case rupay:
        return 'RuPay';
      case amex:
        return 'Amex';
      default:
        return 'Other';
    }
  }

  /// Best-effort guess from the leading digits; null when unknown.
  static String? detect(String digits) {
    if (digits.startsWith('4')) return visa;
    if (RegExp(r'^(5[1-5]|2[2-7])').hasMatch(digits)) return mastercard;
    if (RegExp(r'^3[47]').hasMatch(digits)) return amex;
    if (RegExp(r'^(60|65|81|82|508)').hasMatch(digits)) return rupay;
    return null;
  }
}

/// Card face colours as stored in the `saved_cards.color_tone` column.
class CardTones {
  static const _tones = <String, List<Color>>{
    'indigo': [Color(0xFF6366F1), Color(0xFF4338CA)],
    'ocean': [Color(0xFF0EA5E9), Color(0xFF1D4ED8)],
    'emerald': [Color(0xFF10B981), Color(0xFF047857)],
    'rose': [Color(0xFFF43F5E), Color(0xFFBE123C)],
    'amber': [Color(0xFFF59E0B), Color(0xFFB45309)],
    'slate': [Color(0xFF475569), Color(0xFF1E293B)],
  };

  static List<String> get keys => _tones.keys.toList();

  static List<Color> colors(String tone) => _tones[tone] ?? _tones['indigo']!;
}

class CardNumbers {
  static const minLength = 13;
  static const maxLength = 19;

  static String digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

  /// Groups digits for display: 4-6-5 for Amex, 4-4-4-... for everything else.
  static String format(String value) {
    final d = digitsOnly(value);
    if (RegExp(r'^3[47]').hasMatch(d)) {
      return [
        d.substring(0, math.min(4, d.length)),
        if (d.length > 4) d.substring(4, math.min(10, d.length)),
        if (d.length > 10) d.substring(10, math.min(15, d.length)),
      ].join(' ');
    }
    final groups = <String>[];
    for (var i = 0; i < d.length; i += 4) {
      groups.add(d.substring(i, math.min(i + 4, d.length)));
    }
    return groups.join(' ');
  }

  static String last4(String value) {
    final d = digitsOnly(value);
    return d.length <= 4 ? d : d.substring(d.length - 4);
  }

  /// Same grouping as [format], with every digit except the last four hidden.
  static String mask(String value) {
    final d = digitsOnly(value);
    if (d.isEmpty) return '•••• •••• •••• ••••';
    var i = 0;
    return format(d).replaceAllMapped(RegExp(r'\d'), (m) {
      final show = ++i > d.length - 4;
      return show ? m.group(0)! : '•';
    });
  }

  static bool isValidLength(String value) {
    final n = digitsOnly(value).length;
    return n >= minLength && n <= maxLength;
  }
}

enum ExpiryStatus { ok, expiringSoon, expired }

class CardExpiry {
  /// Parses 'MM/YY' into the last instant of that month, or null if invalid.
  static DateTime? endOfMonth(String value) {
    final m = RegExp(r'^(0[1-9]|1[0-2])/(\d{2})$').firstMatch(value);
    if (m == null) return null;
    final month = int.parse(m.group(1)!);
    final year = 2000 + int.parse(m.group(2)!);
    return DateTime(year, month + 1, 1).subtract(const Duration(seconds: 1));
  }

  static bool isValid(String value) => endOfMonth(value) != null;

  static ExpiryStatus status(String value, {DateTime? now}) {
    final end = endOfMonth(value);
    if (end == null) return ExpiryStatus.ok;
    final today = now ?? DateTime.now();
    if (end.isBefore(today)) return ExpiryStatus.expired;
    if (end.difference(today).inDays <= 62) return ExpiryStatus.expiringSoon;
    return ExpiryStatus.ok;
  }
}

/// Digits only, grouped as the user types, capped at [CardNumbers.maxLength].
class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = CardNumbers.digitsOnly(newValue.text);
    final capped = digits.length > CardNumbers.maxLength
        ? digits.substring(0, CardNumbers.maxLength)
        : digits;
    final formatted = CardNumbers.format(capped);

    // Keep the caret next to the same digit it was beside before regrouping.
    final cursor = newValue.selection.baseOffset.clamp(0, newValue.text.length);
    final digitsBeforeCursor = CardNumbers.digitsOnly(
      newValue.text.substring(0, cursor),
    ).length.clamp(0, capped.length);
    var offset = 0;
    var seen = 0;
    while (offset < formatted.length && seen < digitsBeforeCursor) {
      if (RegExp(r'\d').hasMatch(formatted[offset])) seen++;
      offset++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

/// Formats as MM/YY while typing.
class ExpiryInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = CardNumbers.digitsOnly(newValue.text);
    if (digits.length > 4) digits = digits.substring(0, 4);
    final text = digits.length > 2
        ? '${digits.substring(0, 2)}/${digits.substring(2)}'
        : digits;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
