import 'package:url_launcher/url_launcher.dart';

import 'dart:io';

class CommunicationService {
  /// Sends a WhatsApp message to the given [phoneNumber] with the [message].
  /// Returns `true` if launched successfully, `false` otherwise.
  /// Throws an exception if phone number is empty.
  static Future<bool> sendWhatsAppReminder(
    String phoneNumber,
    String message,
  ) async {
    if (phoneNumber.trim().isEmpty) {
      throw Exception('Phone number is empty');
    }

    // Basic cleaning of phone number
    String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    // If it doesn't start with +, assume India (+91) for this context or leave as is if we want to be generic.
    // Ideally, we should ask the user for country code, but for a simple "Khatabook" clone in India Context:
    if (!cleanPhone.startsWith('+')) {
      if (cleanPhone.length == 10) {
        cleanPhone = '+91$cleanPhone';
      }
    }

    final url = Uri.parse(
      'whatsapp://send?phone=$cleanPhone&text=${Uri.encodeComponent(message)}',
    );

    // Fallback for web or if scheme fails
    final webUrl = Uri.parse(
      'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}',
    );

    if (await canLaunchUrl(url)) {
      return await launchUrl(url);
    } else if (await canLaunchUrl(webUrl)) {
      return await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Sends an SMS to the given [phoneNumber] with the [message].
  static Future<bool> sendSmsReminder(
    String phoneNumber,
    String message,
  ) async {
    if (phoneNumber.trim().isEmpty) {
      throw Exception('Phone number is empty');
    }

    String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    if (Platform.isAndroid) {
      // Android manual construction with ? separator and %20 for spaces
      final String uriString =
          'sms:$cleanPhone?body=${Uri.encodeComponent(message)}';
      final Uri finalUri = Uri.parse(uriString);

      if (await canLaunchUrl(finalUri)) {
        return await launchUrl(finalUri);
      }
    } else if (Platform.isIOS) {
      // iOS: Using '&' separator as a workaround for missing recipient issue on recent iOS versions.
      final String uriString =
          'sms:$cleanPhone&body=${Uri.encodeComponent(message)}';
      final Uri finalUri = Uri.parse(uriString);
      if (await canLaunchUrl(finalUri)) {
        return await launchUrl(finalUri);
      }
    }

    final Uri smsLaunchUri = Uri(
      scheme: 'sms',
      path: phoneNumber,
      queryParameters: <String, String>{'body': message},
    );

    if (await canLaunchUrl(smsLaunchUri)) {
      return await launchUrl(smsLaunchUri);
    }
    return false;
  }
}
