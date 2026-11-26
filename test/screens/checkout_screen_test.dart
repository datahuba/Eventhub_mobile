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
        name: 'HTTP 400 sin mensaje de servidor',
        error: const ApiHttpException(statusCode: 400),
        expectedMessage: 'Datos inválidos',
      ),
      (
        name: 'HTTP 400 con mensaje de negocio seguro',
        error: const ApiHttpException(
          statusCode: 400,
          serverMessage: 'El C.I. ingresado no es válido',
        ),
        expectedMessage: 'El C.I. ingresado no es válido',
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
        name: 'HTTP 403 sin mensaje de servidor',
        error: const ApiHttpException(statusCode: 403),
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

    testWidgets('registra la excepción completa en el log de diagnóstico en debug sin exponerla en el SnackBar', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final originalDebugPrint = debugPrint;
      final capturedDebugPrints = <String>[];
      Object? loggedError;
      StackTrace? loggedStack;
      final rawError = http.ClientException(
        'Connection failed',
        Uri.parse('http://10.0.2.2:4000/api/payments/bnb/generate-qr'),
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
              onDebugErrorLog: (error, stackTrace) {
                loggedError = error;
                loggedStack = stackTrace;
              },
            ),
          ),
        );

        await fillValidCheckoutFormAndSubmit(tester);
      } finally {
        debugPrint = originalDebugPrint;
      }

      // SnackBar sanitizado
      assertSnackBarSanitized(
        tester,
        'Sin conexión. Verificá tu internet e intentá de nuevo.',
      );

      // Log de diagnóstico recibe la excepción completa y el stack trace
      expect(loggedError, same(rawError));
      expect(loggedStack, isNotNull);
      expect(
        capturedDebugPrints.any(
          (msg) => msg.contains('payments/bnb/generate-qr') && msg.contains('Connection failed'),
        ),
        isTrue,
      );
    });
  });

  group('ApiService.generateBnbQr preserva excepciones tipadas', () {
    test('lanza ApiHttpException(409) con mensaje de negocio cuando el backend responde 409', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'No quedan entradas en VIP'}),
          409,
          headers: {'content-type': 'application/json'},
        );
      });
      final api = ApiService(client: mockClient);

      expect(
        () => api.generateBnbQr(
          eventId: 'evt-1',
          buyerName: 'Juan',
          tier: 'VIP',
          attendees: [],
        ),
        throwsA(
          isA<ApiHttpException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having((e) => e.serverMessage, 'serverMessage', 'No quedan entradas en VIP'),
        ),
      );
    });

    test('lanza ApiHttpException(500) cuando el backend responde 500', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });
      final api = ApiService(client: mockClient);

      expect(
        () => api.generateBnbQr(
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

    test('propaga SocketException y ClientException sin envolverlas en Exception genérica', () async {
      final socketClient = MockClient((request) async {
        throw const SocketException('Network is unreachable');
      });
      final api = ApiService(client: socketClient);

      await expectLater(
        api.generateBnbQr(
          eventId: 'evt-1',
          buyerName: 'Juan',
          tier: 'General',
          attendees: [],
        ),
        throwsA(isA<SocketException>()),
      );
    });
  });
}
