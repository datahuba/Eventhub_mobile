import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';
import '../models/ticket.dart';

class WalletPassService {
  /// Determina si la plataforma actual es iOS (Apple Wallet)
  static bool get isAppleWalletPlatform {
    return defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Determina si la plataforma actual es Android (Google Wallet)
  static bool get isGoogleWalletPlatform {
    return defaultTargetPlatform == TargetPlatform.android;
  }

  /// URL para descargar el archivo de pase Apple Wallet (.pkpass)
  static String getAppleWalletPassUrl(IssuedTicket ticket) {
    return '${ApiConfig.baseUrl}/wallet/apple-pass/${ticket.id}';
  }

  /// URL oficial para guardar la entrada en Google Wallet (Save to Google Wallet link)
  static String getGoogleWalletSaveUrl(IssuedTicket ticket) {
    return '${ApiConfig.baseUrl}/wallet/google-pass/${ticket.id}';
  }

  /// Abre la acción nativa de añadir a Apple Wallet
  static Future<bool> addToAppleWallet(IssuedTicket ticket) async {
    final urlString = getAppleWalletPassUrl(ticket);
    final uri = Uri.parse(urlString);

    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    return false;
  }

  /// Abre la acción nativa de añadir a Google Wallet
  static Future<bool> addToGoogleWallet(IssuedTicket ticket) async {
    final urlString = getGoogleWalletSaveUrl(ticket);
    final uri = Uri.parse(urlString);

    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    return false;
  }
}
