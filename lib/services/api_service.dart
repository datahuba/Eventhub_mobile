import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/event.dart';
import '../models/order.dart';
import '../models/attendee.dart';

/// Enmascara tokens, credenciales y datos personales (PII) antes de registrar logs de depuración.
String maskSensitiveData(String input) {
  var masked = input;
  // Tokens Bearer y JWTs
  masked = masked.replaceAllMapped(
    RegExp(r'(Bearer\s+)[A-Za-z0-9\-._~+/]+=*', caseSensitive: false),
    (m) => '${m.group(1)}[REDACTED]',
  );
  masked = masked.replaceAll(
    RegExp(r'\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b'),
    '[REDACTED_JWT]',
  );
  // Correos electrónicos
  masked = masked.replaceAll(
    RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b'),
    '[REDACTED_EMAIL]',
  );
  // Pares clave=valor o clave: valor sensibles (tokens, secretos, PII), con o sin comillas JSON
  masked = masked.replaceAllMapped(
    RegExp(
      r'''\b(token|access_token|refresh_token|secret|password|passwd|pwd|api[_-]?key|authorization|auth|cookie|session|ci|dni|phone|celular|telefono)["']?\s*([:=])\s*("[^"]*"|'[^']*'|[^\s,;}\]]+)''',
      caseSensitive: false,
    ),
    (m) => '${m.group(1)}${m.group(2)}[REDACTED]',
  );
  return masked;
}

/// Excepción HTTP tipada que conserva el código de estado y metadatos de negocio
/// sin exponer detalles sensibles ni de transporte en la UI o logs.
class ApiHttpException implements Exception {
  final int statusCode;
  final String? errorCode;
  final String? serverMessage;

  const ApiHttpException({
    required this.statusCode,
    this.errorCode,
    this.serverMessage,
  });

  @override
  String toString() {
    final maskedMsg = serverMessage == null ? null : maskSensitiveData(serverMessage!);
    return 'ApiHttpException(statusCode: $statusCode, errorCode: $errorCode, serverMessage: $maskedMsg)';
  }
}

class ApiService {
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  dynamic _safeJsonDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      throw Exception('El servidor no respondió con el formato JSON esperado');
    }
  }

  /// Obtiene la cartelera completa de eventos activos desde GET /api/events
  Future<List<Event>> getEvents() async {
    try {
      final uri = Uri.parse(ApiConfig.eventsEndpoint);
      final response = await _client.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode >= 500) {
        throw Exception('Servidor temporalmente no disponible (HTTP ${response.statusCode})');
      }

      if (response.statusCode == 200) {
        final contentType = response.headers['content-type'] ?? '';
        if (!contentType.contains('application/json')) {
          throw Exception('Respuesta inesperada del servidor');
        }
        final dynamic data = _safeJsonDecode(response.body);
        if (data is! List) {
          throw Exception('Formato de datos de eventos no válido');
        }
        return data.map((json) => Event.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        throw Exception('Error al cargar eventos (Código: ${response.statusCode})');
      }
    } catch (e) {
      throw Exception('No se pudo conectar con el servidor: $e');
    }
  }

  /// Obtiene el detalle de un evento por su ID o slug desde GET /api/events/:id
  Future<Event> getEventById(String id) async {
    try {
      final uri = Uri.parse(ApiConfig.eventDetailEndpoint(id));
      final response = await _client.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode >= 500) {
        throw Exception('Servidor temporalmente no disponible (HTTP ${response.statusCode})');
      }

      if (response.statusCode == 200) {
        final contentType = response.headers['content-type'] ?? '';
        if (!contentType.contains('application/json')) {
          throw Exception('Respuesta inesperada del servidor');
        }
        final dynamic data = _safeJsonDecode(response.body);
        if (data is! Map<String, dynamic>) {
          throw Exception('Detalle del evento no válido');
        }
        return Event.fromJson(data);
      } else {
        throw Exception('Evento no encontrado (Código: ${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Error al consultar el evento: $e');
    }
  }

  /// Inicia la compra y genera el QR Simple del BNB llamando a POST /api/payments/bnb/generate-qr
  Future<BnbQrResponse> generateBnbQr({
    required String eventId,
    required String buyerName,
    String? buyerEmail,
    String? buyerPhone,
    required String tier,
    required List<AttendeeInput> attendees,
  }) async {
    final uri = Uri.parse(ApiConfig.generateBnbQrEndpoint);
    final body = jsonEncode({
      'eventId': eventId,
      'buyerName': buyerName,
      'buyerEmail': buyerEmail ?? '',
      'buyerPhone': buyerPhone ?? '',
      'tier': tier,
      'attendees': attendees.map((a) => a.toJson()).toList(),
    });

    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode >= 500) {
      throw ApiHttpException(statusCode: response.statusCode);
    }

    if (response.statusCode >= 400) {
      final map = _tryDecodeJsonMap(response.body);
      throw ApiHttpException(
        statusCode: response.statusCode,
        errorCode: _extractNonEmptyString(map?['code']),
        serverMessage: _extractNonEmptyString(map?['message'] ?? map?['error']),
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiHttpException(statusCode: response.statusCode);
    }

    // Preservar FormatException si una respuesta 2xx trae JSON malformado o estructura inválida.
    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Respuesta JSON inesperada del servidor');
    }

    if (decoded['success'] == true) {
      return BnbQrResponse.fromJson(decoded);
    }

    throw ApiHttpException(
      statusCode: response.statusCode,
      errorCode: _extractNonEmptyString(decoded['code']),
      serverMessage: _extractNonEmptyString(decoded['message'] ?? decoded['error']),
    );
  }

  Map<String, dynamic>? _tryDecodeJsonMap(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  String? _extractNonEmptyString(dynamic value) {
    final text = value?.toString().trim();
    return (text != null && text.isNotEmpty) ? text : null;
  }

  /// Verifica el estado de acreditación del pago consultando POST /api/payments/bnb/check-status
  Future<BnbStatusResponse> checkBnbStatus({
    required String orderId,
    String? qrId,
  }) async {
    try {
      final uri = Uri.parse(ApiConfig.checkBnbStatusEndpoint);
      final body = jsonEncode({
        'orderId': orderId,
        if (qrId != null && qrId.isNotEmpty) 'qrId': qrId,
      });

      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode >= 500) {
        throw Exception('El servidor está temporalmente fuera de servicio (HTTP ${response.statusCode})');
      }

      final dynamic decoded = _safeJsonDecode(response.body);

      if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
        return BnbStatusResponse.fromJson(decoded);
      } else {
        final errorMsg = decoded is Map<String, dynamic> ? decoded['error'] : 'Error al verificar el estado del pago';
        throw Exception(errorMsg ?? 'Error al verificar el estado del pago');
      }
    } catch (e) {
      throw Exception('Error al verificar pago: $e');
    }
  }
}
