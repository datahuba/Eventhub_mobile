import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/event.dart';
import '../models/order.dart';
import '../models/attendee.dart';

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
        throw Exception('El servidor de pagos está temporalmente fuera de servicio (HTTP ${response.statusCode})');
      }

      final dynamic decoded = _safeJsonDecode(response.body);

      if (response.statusCode == 200 && decoded is Map<String, dynamic> && decoded['success'] == true) {
        return BnbQrResponse.fromJson(decoded);
      } else {
        final errorMsg = decoded is Map<String, dynamic> ? decoded['error'] : 'Error al generar el QR de pago';
        throw Exception(errorMsg ?? 'Error al generar el QR de pago');
      }
    } catch (e) {
      throw Exception('Error en pasarela BNB: $e');
    }
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

  /// Envía la orden con comprobante a POST /api/submit para auditoría con IA
  Future<SubmitOrderResponse> submitOrderWithProof({
    required String eventId,
    required String buyerName,
    String? buyerEmail,
    String? buyerPhone,
    required String tier,
    required List<AttendeeInput> attendees,
    required List<int> proofBytes,
    required String proofFileName,
  }) async {
    try {
      final uri = Uri.parse(ApiConfig.submitEndpoint);
      final request = http.MultipartRequest('POST', uri);

      request.fields['eventId'] = eventId;
      request.fields['paymentMethod'] = 'multiplica';
      request.fields['tier'] = tier;
      request.fields['buyer'] = jsonEncode({
        'name': buyerName,
        'email': buyerEmail ?? '',
        'phone': buyerPhone ?? '',
      });
      request.fields['attendees'] = jsonEncode(
        attendees.map((a) => a.toJson()).toList(),
      );

      final multipartFile = http.MultipartFile.fromBytes(
        'proof',
        proofBytes,
        filename: proofFileName,
      );
      request.files.add(multipartFile);

      final streamedResponse = await request.send().timeout(const Duration(seconds: 40));
      final response = await http.Response.fromStream(streamedResponse);

      final dynamic decoded = _safeJsonDecode(response.body);

      if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
        return SubmitOrderResponse.fromJson(decoded);
      } else {
        final errorMsg = decoded is Map<String, dynamic> ? decoded['message'] : 'Error al procesar comprobante';
        throw Exception(errorMsg ?? 'Error al procesar compra (Código: ${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Fallo en auditoría de pago: $e');
    }
  }

  /// Consulta el detalle de una orden y sus tickets generados (GET /api/orders/:id)
  Future<Map<String, dynamic>> getOrderDetails(String orderId) async {
    try {
      final uri = Uri.parse(ApiConfig.orderDetailEndpoint(orderId));
      final response = await _client.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return _safeJsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('No se pudo consultar el detalle de la orden');
      }
    } catch (e) {
      throw Exception('Error al consultar orden: $e');
    }
  }
}

class SubmitOrderResponse {
  final String orderId;
  final String paymentStatus;
  final String message;
  final Map<String, dynamic>? evaluation;
  final Map<String, dynamic>? ocrData;

  SubmitOrderResponse({
    required this.orderId,
    required this.paymentStatus,
    required this.message,
    this.evaluation,
    this.ocrData,
  });

  bool get isCompleted => paymentStatus == 'COMPLETED';

  factory SubmitOrderResponse.fromJson(Map<String, dynamic> json) {
    return SubmitOrderResponse(
      orderId: json['orderId']?.toString() ?? '',
      paymentStatus: json['paymentStatus']?.toString() ?? 'PENDING',
      message: json['message']?.toString() ?? 'Registro procesado',
      evaluation: json['evaluation'] as Map<String, dynamic>?,
      ocrData: json['ocrData'] as Map<String, dynamic>?,
    );
  }
}
