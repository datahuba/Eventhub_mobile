import 'package:flutter/foundation.dart';

class ApiConfig {
  // IP o host configurable manualmente para pruebas en celulares físicos
  static String? _customHost;

  static void setCustomHost(String host) {
    _customHost = host;
  }

  /// Retorna la URL base de la API backend de EventHub.
  /// - En Android Emulator: usa 10.0.2.2:4000
  /// - En iOS Simulator / Web / Desktop: usa localhost:4000
  /// - Si se define _customHost o un String de entorno 'API_URL', usa ese valor.
  static String get baseUrl {
    if (_customHost != null && _customHost!.isNotEmpty) {
      return _customHost!;
    }

    const envUrl = String.fromEnvironment('API_URL', defaultValue: '');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }

    if (kIsWeb) {
      return 'http://localhost:4000/api';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // 10.0.2.2 es el alias del host en el emulador estándar de Android
        return 'http://10.0.2.2:4000/api';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      default:
        return 'http://localhost:4000/api';
    }
  }

  // Endpoints del backend
  static String get eventsEndpoint => '$baseUrl/events';
  static String eventDetailEndpoint(String id) => '$baseUrl/events/$id';
  static String get generateBnbQrEndpoint => '$baseUrl/payments/bnb/generate-qr';
  static String get checkBnbStatusEndpoint => '$baseUrl/payments/bnb/check-status';
}
