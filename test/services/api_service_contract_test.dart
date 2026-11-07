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
    test('generateBnbQr envía payload correcto y parsea contrato canónico PagaYa v1 (HTTP 201)', () async {
      late http.Request capturedRequest;

      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'orderId': 'ord-contract-100',
            'orderToken': 'jwt.token.order-100',
            'token': 'jwt.token.order-100',
            'qrId': 'mock_qr_100',
            'transactionId': 'tx-100',
            'reference': 'REF-100',
            'qrImageBase64': 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
            'qrBase64': 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
            'amount': 150.0,
            'totalAmount': 150.0,
            'currency': 'BOB',
            'tier': 'VIP',
            'quantity': 1,
            'expiresAt': '2026-11-07T18:30:00.000Z',
            'success': true,
          }),
          201,
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

      // Verificación de contrato HTTP según PagaYa v1 (/api/payments/v1/orders)
      expect(capturedRequest.method, 'POST');
      expect(capturedRequest.url.path, endsWith('/payments/v1/orders'));
      expect(capturedRequest.headers['content-type'], contains('application/json'));

      final payload = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      expect(payload['eventId'], 'evt-rock-2026');
      expect(payload['buyerName'], 'Carlos Siles');
      expect(payload['tier'], 'VIP');
      expect(payload['attendees'], isA<List>());
      expect((payload['attendees'] as List).length, 1);

      // Verificación de modelo de respuesta canónico
      expect(response.success, true);
      expect(response.orderId, 'ord-contract-100');
      expect(response.token, 'jwt.token.order-100');
      expect(response.orderToken, 'jwt.token.order-100');
      expect(response.qrId, 'mock_qr_100');
      expect(response.qrBase64, isNotEmpty);
      expect(response.qrImageBase64, isNotEmpty);
      expect(response.totalAmount, 150.0);
      expect(response.currency, 'BOB');
      expect(response.expiresAt, '2026-11-07T18:30:00.000Z');
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

      await expectLater(
        api.generateBnbQr(
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

      await expectLater(
        api.generateBnbQr(
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

      await expectLater(
        api.generateBnbQr(
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

    test('checkBnbStatus envía orderId en path y token en Authorization Bearer header según PagaYa v1', () async {
      late http.Request capturedRequest;

      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'status': 'COMPLETED',
            'paymentStatus': 'COMPLETED',
            'success': true,
            'paidAt': '2026-11-07T18:00:00.000Z',
            'ticketsReady': true,
            'expiresAt': '2026-11-07T18:15:00.000Z',
            'amount': 150.0,
            'totalAmount': 150.0,
            'currency': 'BOB',
            'attendees': [
              {
                'id': 'att-contract-001',
                'name': 'Carlos Siles',
                'ci': '1234567',
                'qrCode': '29384729102',
                'productP': '29384729102',
              }
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
      expect(capturedRequest.url.path, endsWith('/payments/v1/orders/ord-contract-100/status'));
      expect(capturedRequest.headers['Authorization'], 'Bearer token-auth-order-100');

      final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      expect(body['qrId'], 'qr-contract-100');

      expect(response.status, PaymentVerificationStatus.completed);
      expect(response.orderId, 'ord-contract-100');
      expect(response.paidAt, '2026-11-07T18:00:00.000Z');
      expect(response.expiresAt, '2026-11-07T18:15:00.000Z');
      expect(response.ticketsReady, true);
      expect(response.attendeesRaw, isNotNull);
      expect(response.attendeesRaw!.length, 1);
      final firstAtt = response.attendeesRaw!.first as Map<String, dynamic>;
      expect(firstAtt['id'], 'att-contract-001');
      expect(firstAtt['productP'], '29384729102');
    });

    test('generateBnbQr rechaza respuestas incompletas (solo orderId sin token o sin QR) y lanza excepción sanitizada', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'orderId': 'ord-only-id-no-token',
            'success': true,
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = ApiService(client: mockClient);

      await expectLater(
        api.generateBnbQr(
          eventId: 'evt-1',
          buyerName: 'Carlos Siles',
          tier: 'VIP',
          attendees: [AttendeeInput(name: 'Carlos Siles', ci: '1234567')],
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('checkBnbStatus sin token Bearer no realiza petición HTTP y lanza ArgumentError inmediatamente', () async {
      var httpRequestMade = false;
      final mockClient = MockClient((request) async {
        httpRequestMade = true;
        return http.Response('{}', 200);
      });

      final api = ApiService(client: mockClient);

      expect(
        () => api.checkBnbStatus(orderId: 'ord-123', token: null),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => api.checkBnbStatus(orderId: 'ord-123', token: '   '),
        throwsA(isA<ArgumentError>()),
      );
      expect(httpRequestMade, false);
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

      await expectLater(
        api.checkBnbStatus(orderId: 'ord-1', qrId: 'qr-1', token: 'valid-test-token'),
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
