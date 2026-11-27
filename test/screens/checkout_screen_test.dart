import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:eventhub_mobile/screens/checkout_screen.dart';
import 'package:eventhub_mobile/services/api_service.dart';
import '../helpers/test_helpers.dart';

void main() {
  void assertSnackBarSanitized(WidgetTester tester, String expectedText) {
    final snackBarFinder = find.byType(SnackBar);
    expect(snackBarFinder, findsOneWidget);

    final snackBar = tester.widget<SnackBar>(snackBarFinder);
    final contentWidget = snackBar.content as Text;
    final displayed = contentWidget.data ?? '';

    expect(displayed, expectedText);
    expect(displayed, isNot(contains('payments/bnb/generate-qr')));
    expect(displayed, isNot(contains('http://')));
    expect(displayed, isNot(contains('https://')));
    expect(displayed, isNot(contains('10.0.2.2')));
    expect(displayed, isNot(contains('SQLSTATE')));
    expect(displayed.toLowerCase(), isNot(contains('token=')));
    expect(displayed, isNot(contains('Exception')));
    expect(displayed.toLowerCase(), isNot(contains('stack')));
    expect(displayed, isNot(contains('\n')));
  }

  Future<void> fillValidCheckoutFormAndSubmit(WidgetTester tester) async {
    final fields = find.byType(TextFormField);
    // Campo 0: Nombre del comprador, Campo 3: Nombre asistente, Campo 4: C.I. asistente
    await tester.enterText(fields.at(0), 'Bernardo Chavez');
    await tester.enterText(fields.at(3), 'Bernardo Chavez');
    await tester.enterText(fields.at(4), '12345678');

    final payButton = find.byType(ElevatedButton);
    await tester.ensureVisible(payButton);
    await tester.tap(payButton);
    await tester.pumpAndSettle();
  }

  group('Issue #33: Sanitización de errores en CheckoutScreen', () {
    final cases = <({String name, Object error, String expectedMessage})>[
      (
        name: 'SocketException con URL/host',
        error: const SocketException(
          'Failed host lookup: http://10.0.2.2:4000/api/payments/bnb/generate-qr',
        ),
        expectedMessage: 'Sin conexión. Verificá tu internet e intentá de nuevo.',
      ),
      (
        name: 'http.ClientException con URI del endpoint',
        error: http.ClientException(
          'Connection refused',
          Uri.parse('http://10.0.2.2:4000/api/payments/bnb/generate-qr'),
        ),
        expectedMessage: 'Sin conexión. Verificá tu internet e intentá de nuevo.',
      ),
      (
        name: 'TimeoutException',
        error: TimeoutException(
          'Future not completed for http://10.0.2.2:4000/api/payments/bnb/generate-qr',
          const Duration(seconds: 20),
        ),
        expectedMessage: 'La operación tardó demasiado. Intentá de nuevo.',
      ),
      (
        name: 'FormatException directa',
        error: const FormatException('Unexpected character at offset 0: <html>502</html>'),
        expectedMessage: 'Ocurrió un error inesperado. Intentá de nuevo.',
      ),
      (
        name: 'HTTP 400 sin mensaje de servidor',
        error: const ApiHttpException(statusCode: 400),
        expectedMessage: 'Datos inválidos',
      ),
      (
        name: 'HTTP 400 con código de negocio en allowlist',
        error: const ApiHttpException(
          statusCode: 400,
          errorCode: 'INVALID_ATTENDEE_CI',
        ),
        expectedMessage: 'El C.I. ingresado no es válido',
      ),
      (
        name: 'HTTP 400 con mensaje de negocio en allowlist',
        error: const ApiHttpException(
          statusCode: 400,
          serverMessage: 'El C.I. ingresado no es válido',
        ),
        expectedMessage: 'El C.I. ingresado no es válido',
      ),
      (
        name: 'HTTP 400 con host:puerto (10.0.2.2:4000) fuera de allowlist',
        error: const ApiHttpException(
          statusCode: 400,
          serverMessage: 'Conexión rechazada por 10.0.2.2:4000',
        ),
        expectedMessage: 'Datos inválidos',
      ),
      (
        name: 'HTTP 400 con SQLSTATE fuera de allowlist',
        error: const ApiHttpException(
          statusCode: 400,
          serverMessage: 'SQLSTATE[23505]: duplicate key value violates unique constraint',
        ),
        expectedMessage: 'Datos inválidos',
      ),
      (
        name: 'HTTP 400 con token= fuera de allowlist',
        error: const ApiHttpException(
          statusCode: 400,
          serverMessage: 'Error validando token=super_secreto_123',
        ),
        expectedMessage: 'Datos inválidos',
      ),
      (
        name: 'HTTP 400 con mensaje de servidor inseguro (URL y stack)',
        error: const ApiHttpException(
          statusCode: 400,
          serverMessage:
              'Exception at http://10.0.2.2:4000/api/payments/bnb/generate-qr\nstack trace',
        ),
        expectedMessage: 'Datos inválidos',
      ),
      (
        name: 'HTTP 422 sin mensaje de servidor',
        error: const ApiHttpException(statusCode: 422),
        expectedMessage: 'Datos inválidos',
      ),
      (
        name: 'HTTP 403 con mensaje técnico Bearer fuera de allowlist',
        error: const ApiHttpException(
          statusCode: 403,
          serverMessage: 'Invalid Bearer eyJhbGciOiJIUzI1NiJ9.aaa.bbb',
        ),
        expectedMessage: 'No autorizado',
      ),
      (
        name: 'HTTP 409 sin mensaje de servidor',
        error: const ApiHttpException(statusCode: 409),
        expectedMessage: 'Cupo agotado para este sector',
      ),
      (
        name: 'HTTP 500 error del servidor',
        error: const ApiHttpException(statusCode: 500),
        expectedMessage: 'Error del servidor, intentá más tarde.',
      ),
      (
        name: 'Excepción genérica con URL, Exception, stack y saltos de línea',
        error: Exception(
          'FormatException en http://10.0.2.2:4000/api/payments/bnb/generate-qr\nstack: line 42',
        ),
        expectedMessage: 'Ocurrió un error inesperado. Intentá de nuevo.',
      ),
    ];

    for (final testCase in cases) {
      testWidgets('muestra mensaje sanitizado para ${testCase.name}', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final fakeApi = FakeApiService(generateBnbQrError: testCase.error);
        final dummyEvent = createDummyEvent();

        await tester.pumpWidget(
          MaterialApp(
            home: CheckoutScreen(
              event: dummyEvent,
              selectedTier: dummyEvent.tiers.first,
              quantity: 1,
              apiService: fakeApi,
            ),
          ),
        );

        await fillValidCheckoutFormAndSubmit(tester);

        expect(fakeApi.generateBnbQrCallCount, 1);
        assertSnackBarSanitized(tester, testCase.expectedMessage);
      });
    }

    testWidgets('enmascara tokens y PII en el log de diagnóstico en debug sin exponerlos en el SnackBar', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final originalDebugPrint = debugPrint;
      final capturedDebugPrints = <String>[];
      String? loggedMaskedError;
      StackTrace? loggedStack;
      const rawError = ApiHttpException(
        statusCode: 400,
        serverMessage:
            'Fallo en token=secreto_999 email=usuario@test.com Bearer abcdef12345 ci=8877665',
      );
      final fakeApi = FakeApiService(generateBnbQrError: rawError);
      final dummyEvent = createDummyEvent();

      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) {
          capturedDebugPrints.add(message);
        }
      };

      try {
        await tester.pumpWidget(
          MaterialApp(
            home: CheckoutScreen(
              event: dummyEvent,
              selectedTier: dummyEvent.tiers.first,
              quantity: 1,
              apiService: fakeApi,
              onDebugErrorLog: (maskedError, stackTrace) {
                loggedMaskedError = maskedError;
                loggedStack = stackTrace;
              },
            ),
          ),
        );

        await fillValidCheckoutFormAndSubmit(tester);
      } finally {
        debugPrint = originalDebugPrint;
      }

      // SnackBar sanitizado mediante allowlist
      assertSnackBarSanitized(tester, 'Datos inválidos');

      // El log conserva el código HTTP para diagnóstico, pero enmascara tokens y PII
      expect(loggedMaskedError, isNotNull);
      expect(loggedMaskedError, contains('statusCode: 400'));
      expect(loggedMaskedError, contains('[REDACTED]'));
      expect(loggedMaskedError, contains('[REDACTED_EMAIL]'));
      expect(loggedMaskedError, isNot(contains('secreto_999')));
      expect(loggedMaskedError, isNot(contains('usuario@test.com')));
      expect(loggedMaskedError, isNot(contains('abcdef12345')));
      expect(loggedMaskedError, isNot(contains('8877665')));
      expect(loggedStack, isNotNull);

      expect(
        capturedDebugPrints.any(
          (msg) =>
              msg.contains('statusCode: 400') &&
              !msg.contains('secreto_999') &&
              !msg.contains('usuario@test.com') &&
              !msg.contains('abcdef12345') &&
              !msg.contains('8877665'),
        ),
        isTrue,
      );
    });
  });

  group('ApiService.generateBnbQr preserva excepciones tipadas y códigos HTTP', () {
    test('lanza ApiHttpException(409) con mensaje cuando el backend responde 409 JSON', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'code': 'SECTOR_SOLD_OUT', 'message': 'Cupo agotado para este sector'}),
          409,
          headers: {'content-type': 'application/json'},
        );
      });
      final api = ApiService(client: mockClient);

      await expectLater(
        api.generateBnbQr(
          eventId: 'evt-1',
          buyerName: 'Juan',
          tier: 'VIP',
          attendees: [],
        ),
        throwsA(
          isA<ApiHttpException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having((e) => e.errorCode, 'errorCode', 'SECTOR_SOLD_OUT')
              .having((e) => e.serverMessage, 'serverMessage', 'Cupo agotado para este sector'),
        ),
      );
    });

    test('lanza ApiHttpException con el código real en respuestas 4xx sin JSON', () async {
      for (final testCase in [
        (code: 400, body: 'Bad Request'),
        (code: 403, body: '<html><body>Forbidden</body></html>'),
        (code: 404, body: ''),
        (code: 409, body: 'Conflict'),
        (code: 422, body: 'Unprocessable Entity'),
      ]) {
        final mockClient = MockClient((request) async {
          return http.Response(testCase.body, testCase.code);
        });
        final api = ApiService(client: mockClient);

        await expectLater(
          api.generateBnbQr(
            eventId: 'evt-1',
            buyerName: 'Juan',
            tier: 'General',
            attendees: [],
          ),
          throwsA(
            isA<ApiHttpException>()
                .having((e) => e.statusCode, 'statusCode', testCase.code)
                .having((e) => e.serverMessage, 'serverMessage', isNull),
          ),
        );
      }
    });

    test('lanza ApiHttpException(500) cuando el backend responde 500', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });
      final api = ApiService(client: mockClient);

      await expectLater(
        api.generateBnbQr(
          eventId: 'evt-1',
          buyerName: 'Juan',
          tier: 'General',
          attendees: [],
        ),
        throwsA(
          isA<ApiHttpException>().having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });

    test('preserva FormatException en respuestas 2xx con JSON malformado o no objeto', () async {
      final invalidJsonClient = MockClient((request) async {
        return http.Response('<html>OK</html>', 200);
      });
      await expectLater(
        ApiService(client: invalidJsonClient).generateBnbQr(
          eventId: 'evt-1',
          buyerName: 'Juan',
          tier: 'General',
          attendees: [],
        ),
        throwsA(isA<FormatException>()),
      );

      final nonMapJsonClient = MockClient((request) async {
        return http.Response('[]', 200);
      });
      await expectLater(
        ApiService(client: nonMapJsonClient).generateBnbQr(
          eventId: 'evt-1',
          buyerName: 'Juan',
          tier: 'General',
          attendees: [],
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('propaga SocketException, ClientException y TimeoutException sin envolverlas', () async {
      final socketClient = MockClient((request) async {
        throw const SocketException('Network is unreachable');
      });
      await expectLater(
        ApiService(client: socketClient).generateBnbQr(
          eventId: 'evt-1',
          buyerName: 'Juan',
          tier: 'General',
          attendees: [],
        ),
        throwsA(isA<SocketException>()),
      );

      final httpClientError = MockClient((request) async {
        throw http.ClientException(
          'Connection refused',
          Uri.parse('http://10.0.2.2:4000/api/payments/bnb/generate-qr'),
        );
      });
      await expectLater(
        ApiService(client: httpClientError).generateBnbQr(
          eventId: 'evt-1',
          buyerName: 'Juan',
          tier: 'General',
          attendees: [],
        ),
        throwsA(isA<http.ClientException>()),
      );

      final timeoutClient = MockClient((request) async {
        throw TimeoutException('Request timed out');
      });
      await expectLater(
        ApiService(client: timeoutClient).generateBnbQr(
          eventId: 'evt-1',
          buyerName: 'Juan',
          tier: 'General',
          attendees: [],
        ),
        throwsA(isA<TimeoutException>()),
      );
    });
  });
}
