import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/event.dart';
import '../models/order.dart';
import '../models/attendee.dart';
import '../utils/error_sanitizer.dart';

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
        throw Exception('El servicio de eventos no está disponible temporalmente.');
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
        throw Exception('No se pudieron cargar los eventos');
      }
    } catch (e) {
      throw Exception(ErrorSanitizer.sanitizeEvents(e));
    }
  }

  /// Obtiene el detalle de un evento por su ID o slug desde GET /api/events/:id
  Future<Event> getEventById(String id) async {
    try {
      final uri = Uri.parse(ApiConfig.eventDetailEndpoint(id));
      final response = await _client.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode >= 500) {
        throw Exception('El servicio de eventos no está disponible temporalmente.');
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
        throw Exception('El evento solicitado no fue encontrado');
      }
    } catch (e) {
      throw Exception(ErrorSanitizer.sanitizeEvents(e));
    }
  }

  /// Inicia la compra y genera la orden con QR llamando a POST /api/payments/v1/orders
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
      final errorObj = map?['error'] is Map<String, dynamic>
          ? map!['error'] as Map<String, dynamic>
          : null;
      throw ApiHttpException(
        statusCode: response.statusCode,
        errorCode: _extractNonEmptyString(errorObj?['code'] ?? map?['code']),
        serverMessage: _extractNonEmptyString(
          errorObj?['message'] ?? map?['message'] ?? map?['error'],
        ),
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

    if (decoded['success'] == false) {
      final errorObj = decoded['error'] is Map<String, dynamic>
          ? decoded['error'] as Map<String, dynamic>
          : null;
      throw ApiHttpException(
        statusCode: response.statusCode,
        errorCode: _extractNonEmptyString(errorObj?['code'] ?? decoded['code']),
        serverMessage: _extractNonEmptyString(
          errorObj?['message'] ?? decoded['message'] ?? decoded['error'],
        ),
      );
    }

    final bnbResponse = BnbQrResponse.fromJson(decoded);
    if (bnbResponse.orderId.trim().isEmpty ||
        bnbResponse.token == null ||
        bnbResponse.token!.trim().isEmpty ||
        bnbResponse.qrBase64.trim().isEmpty) {
      throw const FormatException(
        'Respuesta de orden incompleta: se requieren orderId, token y código QR',
      );
    }
    return bnbResponse;
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

  /// Verifica el estado de acreditación del pago consultando POST /api/payments/v1/orders/:orderId/status
  Future<BnbStatusResponse> checkBnbStatus({
    required String orderId,
    String? qrId,
    String? token,
  }) async {
    if (token == null || token.trim().isEmpty) {
      throw ArgumentError('Se requiere token de autorización (Bearer) para consultar el estado del pago');
    }

    try {
      final uri = Uri.parse(ApiConfig.checkBnbStatusEndpoint(orderId));
      final body = jsonEncode({
        if (qrId != null && qrId.isNotEmpty) 'qrId': qrId,
      });

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await _client.post(
        uri,
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode >= 500) {
        throw Exception('El servicio de pagos no está disponible temporalmente. Por favor intentá en unos minutos.');
      }

      final dynamic decoded = _safeJsonDecode(response.body);

      if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
        return BnbStatusResponse.fromJson(decoded, fallbackOrderId: orderId);
      } else {
        final rawError = decoded is Map<String, dynamic>
            ? (decoded['message'] ?? decoded['error'])
            : null;
        throw Exception(ErrorSanitizer.sanitizePayment(rawError ?? 'No se pudo verificar el estado del pago'));
      }
    } catch (e) {
      throw Exception(ErrorSanitizer.sanitizePayment(e));
    }
  }
}
