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

    // URL oficial de producción en el VPS de DataHub
    return 'https://api-eventhub.datahuba.com/api';
  }

  /// Retorna el host raíz del backend (sin /api)
  static String get backendHost {
    final base = baseUrl;
    if (base.endsWith('/api')) {
      return base.substring(0, base.length - 4);
    }
    return base;
  }

  /// Retorna la URL base del frontend web oficial
  static String get webBaseUrl {
    const envUrl = String.fromEnvironment('WEB_URL', defaultValue: '');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    return 'https://eventhub.datahuba.com';
  }

  // Endpoints del backend
  static String get eventsEndpoint => '$baseUrl/events';
  static String eventDetailEndpoint(String id) => '$baseUrl/events/$id';
  static String get generateBnbQrEndpoint => '$baseUrl/payments/bnb/generate-qr';
  static String get checkBnbStatusEndpoint => '$baseUrl/payments/bnb/check-status';
}
