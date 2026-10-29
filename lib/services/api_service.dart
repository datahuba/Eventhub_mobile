import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/event.dart';
import '../models/order.dart';
import '../models/attendee.dart';
import '../utils/error_sanitizer.dart';

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
      throw Exception(ErrorSanitizer.sanitize(e));
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
      throw Exception(ErrorSanitizer.sanitize(e));
    }
  }

  /// Inicia la compra y genera el QR Simple llamando a POST /api/payments/qr/generate
  Future<BnbQrResponse> generateBnbQr({
    required String eventId,
    required String buyerName,
    String? buyerEmail,
    String? buyerPhone,
    required String tier,
    required List<AttendeeInput> attendees,
  }) async {
    try {
      final uri = Uri.parse(ApiConfig.generateBnbQrEndpoint);
      final body = jsonEncode({
        'eventId': eventId,
        'buyerName': buyerName,
        'buyerEmail': buyerEmail ?? '',
        'buyerPhone': buyerPhone ?? '',
        'tier': tier,
        'attendees': attendees.map((a) => a.toJson()).toList(),
      });

      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode >= 500) {
        throw Exception('El servicio de pagos no está disponible en este momento. Por favor intentá en unos minutos.');
      }

      final dynamic decoded = _safeJsonDecode(response.body);

      if (response.statusCode == 200 && decoded is Map<String, dynamic> && decoded['success'] == true) {
        return BnbQrResponse.fromJson(decoded);
      } else {
        final rawError = decoded is Map<String, dynamic> ? decoded['error'] : null;
        throw Exception(ErrorSanitizer.sanitize(rawError ?? 'No se pudo generar el código QR de pago'));
      }
    } catch (e) {
      throw Exception(ErrorSanitizer.sanitize(e));
    }
  }

  /// Verifica el estado de acreditación del pago consultando POST /api/payments/qr/check-status
  Future<BnbStatusResponse> checkBnbStatus({
    required String orderId,
    String? qrId,
    String? token,
  }) async {
    try {
      final uri = Uri.parse(ApiConfig.checkBnbStatusEndpoint);
      final body = jsonEncode({
        'orderId': orderId,
        if (qrId != null && qrId.isNotEmpty) 'qrId': qrId,
        if (token != null && token.isNotEmpty) 'token': token,
      });

      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await _client.post(
        uri,
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode >= 500) {
        throw Exception('El servicio de verificación no está disponible en este momento. Por favor intentá en unos instantes.');
      }

      final dynamic decoded = _safeJsonDecode(response.body);

      if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
        return BnbStatusResponse.fromJson(decoded);
      } else {
        final rawError = decoded is Map<String, dynamic> ? decoded['error'] : null;
        throw Exception(ErrorSanitizer.sanitize(rawError ?? 'No se pudo verificar el estado del pago'));
      }
    } catch (e) {
      throw Exception(ErrorSanitizer.sanitize(e));
    }
  }
}
