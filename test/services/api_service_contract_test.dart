import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:eventhub_mobile/services/api_service.dart';
import 'package:eventhub_mobile/models/attendee.dart';
import 'package:eventhub_mobile/models/order.dart';

void main() {
  group('ApiService Contract & Error Sanitization Tests', () {
    test('generateBnbQr envía payload correcto y parsea contrato con token y qrBase64', () async {
      late http.Request capturedRequest;

      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'success': true,
            'orderId': 'ord-contract-100',
            'token': 'jwt.token.order-100',
            'qrId': 'mock_qr_100',
            'transactionId': 'tx-100',
            'qrBase64': 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
            'totalAmount': 150.0,
            'currency': 'BOB',
            'eventTitle': 'Concierto Rock 2026',
            'tier': 'VIP',
            'quantity': 1,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = ApiService(client: mockClient);
      final response = await api.generateBnbQr(
        eventId: 'evt-rock-2026',
        buyerName: 'Carlos Siles',
        buyerEmail: 'carlos@example.bo',
        buyerPhone: '+59170011223',
        tier: 'VIP',
        attendees: [AttendeeInput(name: 'Carlos Siles', ci: '1234567')],
      );

      // Verificación de contrato HTTP
      expect(capturedRequest.method, 'POST');
      expect(capturedRequest.url.path, endsWith('/payments/qr/generate'));
      expect(capturedRequest.headers['content-type'], contains('application/json'));

      final payload = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      expect(payload['eventId'], 'evt-rock-2026');
      expect(payload['buyerName'], 'Carlos Siles');
      expect(payload['tier'], 'VIP');
      expect(payload['attendees'], isA<List>());
      expect((payload['attendees'] as List).length, 1);

      // Verificación de modelo de respuesta
      expect(response.success, true);
      expect(response.orderId, 'ord-contract-100');
      expect(response.token, 'jwt.token.order-100');
      expect(response.qrId, 'mock_qr_100');
      expect(response.totalAmount, 150.0);
      expect(response.currency, 'BOB');
    });

    test('generateBnbQr ante 409 Entradas agotadas arroja mensaje seguro sin detalles técnicos', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': 'Entradas agotadas para el sector "VIP". Cupos restantes: 0.',
          }),
          409,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = ApiService(client: mockClient);

      expect(
        () => api.generateBnbQr(
          eventId: 'evt-sold-out',
          buyerName: 'Pedro Intento',
          tier: 'VIP',
          attendees: [AttendeeInput(name: 'Pedro', ci: '1234567')],
        ),
        throwsA(predicate((e) {
          final msg = e.toString();
          return msg.contains('agotado') && !msg.contains('409') && !msg.contains('status');
        })),
      );
    });

    test('generateBnbQr ante fallo de conexión (SocketException / ClientException) no expone hosts ni puertos', () async {
      final mockClient = MockClient((request) async {
        throw const SocketException('Connection refused, errno = 111, address = 10.0.2.2, port = 4000');
      });

      final api = ApiService(client: mockClient);

      expect(
        () => api.generateBnbQr(
          eventId: 'evt-1',
          buyerName: 'Usuario',
          tier: 'General',
          attendees: [AttendeeInput(name: 'Usuario', ci: '1234567')],
        ),
        throwsA(predicate((e) {
          final msg = e.toString();
          final noLeak = !msg.contains('10.0.2.2') &&
              !msg.contains('4000') &&
              !msg.contains('errno') &&
              !msg.contains('SocketException');
          final isFriendly = msg.contains('conexión a internet');
          return noLeak && isFriendly;
        })),
      );
    });

    test('generateBnbQr ante TimeoutException arroja mensaje amigable de tiempo de espera', () async {
      final mockClient = MockClient((request) async {
        throw TimeoutException('Future not completed after 0:00:20.000000');
      });

      final api = ApiService(client: mockClient);

      expect(
        () => api.generateBnbQr(
          eventId: 'evt-1',
          buyerName: 'Usuario',
          tier: 'General',
          attendees: [AttendeeInput(name: 'Usuario', ci: '1234567')],
        ),
        throwsA(predicate((e) {
          final msg = e.toString();
          return msg.contains('tardó demasiado') && !msg.contains('0:00:20');
        })),
      );
    });

    test('checkBnbStatus envía orderId, qrId, orderToken en headers y body', () async {
      late http.Request capturedRequest;

      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'status': 'COMPLETED',
            'orderId': 'ord-contract-100',
            'message': 'Pago completado',
            'attendees': [
              {'id': 'att-1', 'name': 'Carlos Siles'}
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = ApiService(client: mockClient);
      final response = await api.checkBnbStatus(
        orderId: 'ord-contract-100',
        qrId: 'qr-contract-100',
        token: 'token-auth-order-100',
      );

      expect(capturedRequest.method, 'POST');
      expect(capturedRequest.url.path, endsWith('/payments/qr/check-status'));
      expect(capturedRequest.headers['Authorization'], 'Bearer token-auth-order-100');

      final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      expect(body['orderId'], 'ord-contract-100');
      expect(body['qrId'], 'qr-contract-100');
      expect(body['token'], 'token-auth-order-100');

      expect(response.status, PaymentVerificationStatus.completed);
      expect(response.orderId, 'ord-contract-100');
    });

    test('checkBnbStatus ante error 500 del servidor arroja mensaje seguro sin detalles técnicos', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'Internal server crash in database transaction P2034'}),
          500,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = ApiService(client: mockClient);

      expect(
        () => api.checkBnbStatus(orderId: 'ord-1', qrId: 'qr-1'),
        throwsA(predicate((e) {
          final msg = e.toString();
          return !msg.contains('P2034') &&
              !msg.contains('database') &&
              !msg.contains('500') &&
              msg.contains('temporalmente');
        })),
      );
    });
  });
}
