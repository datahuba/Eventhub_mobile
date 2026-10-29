import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub_mobile/models/attendee.dart';
import 'package:eventhub_mobile/models/event.dart';
import 'package:eventhub_mobile/models/order.dart';
import 'package:eventhub_mobile/screens/bnb_payment_screen.dart';
import 'package:eventhub_mobile/screens/payment_success_screen.dart';
import 'package:eventhub_mobile/widgets/bnb_countdown_badge.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('Issue #4: Polling BNB y expiración de QR', () {
    testWidgets('con _secondsRemaining = 0 y statusResp = expired, tras 2 ticks del timer se observa como máximo una llamada (cero llamadas)', (WidgetTester tester) async {
      final fakeApi = FakeApiService(statusToReturn: PaymentVerificationStatus.expired);

      await tester.pumpWidget(
        MaterialApp(
          home: BnbPaymentScreen(
            event: createDummyEvent(),
            selectedTier: TicketTier(name: 'General', price: 100.0),
            bnbResponse: createDummyBnbResponse(),
            attendees: [AttendeeInput(name: 'Juan Perez', ci: '1234567')],
            apiService: fakeApi,
            initialSecondsRemaining: 0,
          ),
        ),
      );

      // Estado inicial en UI: explícito QR vencido
      expect(find.text('Código QR Vencido'), findsOneWidget);
      expect(find.text('Volver a generar orden'), findsOneWidget);
      expect(fakeApi.checkStatusCallCount, 0);

      // 1er tick del timer de sondeo (4 segundos)
      await tester.pump(const Duration(seconds: 4));
      expect(fakeApi.checkStatusCallCount, 0);

      // 2do tick del timer de sondeo (4 segundos más)
      await tester.pump(const Duration(seconds: 4));
      expect(fakeApi.checkStatusCallCount, 0);
    });

    testWidgets('backend devuelve expired: polling se detiene tras 1 llamada y no vuelve a consultar', (WidgetTester tester) async {
      final fakeApi = FakeApiService(statusToReturn: PaymentVerificationStatus.expired);

      await tester.pumpWidget(
        MaterialApp(
          home: BnbPaymentScreen(
            event: createDummyEvent(),
            selectedTier: TicketTier(name: 'General', price: 100.0),
            bnbResponse: createDummyBnbResponse(),
            attendees: [AttendeeInput(name: 'Juan Perez', ci: '1234567')],
            apiService: fakeApi,
            initialSecondsRemaining: 900,
          ),
        ),
      );

      // Inicialmente en vista de pago
      expect(fakeApi.checkStatusCallCount, 0);
      expect(find.text('Pago con QR Simple'), findsOneWidget);

      // 1er tick del polling (4s) -> dispara _verifyPayment
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // Debe haber llamado 1 vez y cambiado a estado expirado
      expect(fakeApi.checkStatusCallCount, 1);
      expect(find.text('Código QR Vencido'), findsOneWidget);
      expect(find.text('Volver a generar orden'), findsOneWidget);

      // 2do tick del timer (4s adicionales)
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // La llamada se mantiene en 1 (el polling se canceló)
      expect(fakeApi.checkStatusCallCount, 1);

      // 3er tick
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(fakeApi.checkStatusCallCount, 1);
    });

    testWidgets('early-return cuando _qrBytes == null por error de decodificación', (WidgetTester tester) async {
      final fakeApi = FakeApiService(statusToReturn: PaymentVerificationStatus.expired);

      await tester.pumpWidget(
        MaterialApp(
          home: BnbPaymentScreen(
            event: createDummyEvent(),
            selectedTier: TicketTier(name: 'General', price: 100.0),
            bnbResponse: createDummyBnbResponse(qrBase64: '### INVALID BASE64 ###'),
            attendees: [AttendeeInput(name: 'Juan Perez', ci: '1234567')],
            apiService: fakeApi,
            initialSecondsRemaining: 900,
          ),
        ),
      );

      // 1er tick de polling
      await tester.pump(const Duration(seconds: 4));
      expect(fakeApi.checkStatusCallCount, 0);

      // 2do tick de polling
      await tester.pump(const Duration(seconds: 4));
      expect(fakeApi.checkStatusCallCount, 0);
    });

    testWidgets('cuenta regresiva llega a 0: cancela polling y cambia a QR Vencido', (WidgetTester tester) async {
      final fakeApi = FakeApiService(statusToReturn: PaymentVerificationStatus.pending);

      await tester.pumpWidget(
        MaterialApp(
          home: BnbPaymentScreen(
            event: createDummyEvent(),
            selectedTier: TicketTier(name: 'General', price: 100.0),
            bnbResponse: createDummyBnbResponse(),
            attendees: [AttendeeInput(name: 'Juan Perez', ci: '1234567')],
            apiService: fakeApi,
            initialSecondsRemaining: 2,
          ),
        ),
      );

      expect(find.text('Pago con QR Simple'), findsOneWidget);

      // Avanzar 2 segundos para agotar el tiempo
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // UI debe reflejar estado expirado
      expect(find.text('Código QR Vencido'), findsOneWidget);
      expect(find.text('Volver a generar orden'), findsOneWidget);

      // Ticks posteriores del polling no deben llamar al endpoint
      await tester.pump(const Duration(seconds: 4));
      expect(fakeApi.checkStatusCallCount, 0);
    });

    testWidgets('botón Volver a generar orden regresa a la pantalla anterior', (WidgetTester tester) async {
      final fakeApi = FakeApiService(statusToReturn: PaymentVerificationStatus.expired);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BnbPaymentScreen(
                        event: createDummyEvent(),
                        selectedTier: TicketTier(name: 'General', price: 100.0),
                        bnbResponse: createDummyBnbResponse(),
                        attendees: [AttendeeInput(name: 'Juan Perez', ci: '1234567')],
                        apiService: fakeApi,
                        initialSecondsRemaining: 0,
                      ),
                    ),
                  );
                },
                child: const Text('Ir a pago'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Ir a pago'));
      await tester.pumpAndSettle();

      expect(find.text('Código QR Vencido'), findsOneWidget);

      await tester.tap(find.byKey(const Key('expired_back_button')));
      await tester.pumpAndSettle();

      expect(find.text('Ir a pago'), findsOneWidget);
    });
  });

  group('Issue #5: Rechazo de entradas incompletas o sintéticas en BnbPaymentScreen', () {
    testWidgets('cuando statusResp.attendeesRaw = [] en completed, no llama a saveTickets ni navega y muestra error con orderId', (WidgetTester tester) async {
      final fakeApi = FakeApiService(
        statusToReturn: PaymentVerificationStatus.completed,
        attendeesRawToReturn: [],
      );
      final fakeStorage = FakeStorageService();

      await tester.pumpWidget(
        MaterialApp(
          home: BnbPaymentScreen(
            event: createDummyEvent(),
            selectedTier: TicketTier(name: 'General', price: 100.0),
            bnbResponse: createDummyBnbResponse(),
            attendees: [AttendeeInput(name: 'Juan Perez', ci: '1234567')],
            apiService: fakeApi,
            storageService: fakeStorage,
            initialSecondsRemaining: 900,
          ),
        ),
      );

      // 1er tick de polling automático (4s)
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // No debe guardar entradas sintéticas
      expect(fakeStorage.saveTicketsCallCount, 0);

      // No debe navegar a la pantalla de éxito
      expect(find.byType(PaymentSuccessScreen), findsNothing);

      // Debe mostrar error visible que incluye el orderId para reclamo/soporte
      expect(find.textContaining('ORD-12345'), findsOneWidget);
    });

    testWidgets('cuando attendeesRaw contiene objeto sin qrCode/productP, no guarda tickets ni navega', (WidgetTester tester) async {
      final fakeApi = FakeApiService(
        statusToReturn: PaymentVerificationStatus.completed,
        attendeesRawToReturn: [
          {'id': 'REAL-ID-001'}, // falta qrCode y productP
        ],
      );
      final fakeStorage = FakeStorageService();

      await tester.pumpWidget(
        MaterialApp(
          home: BnbPaymentScreen(
            event: createDummyEvent(),
            selectedTier: TicketTier(name: 'General', price: 100.0),
            bnbResponse: createDummyBnbResponse(),
            attendees: [AttendeeInput(name: 'Juan Perez', ci: '1234567')],
            apiService: fakeApi,
            storageService: fakeStorage,
            initialSecondsRemaining: 900,
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(fakeStorage.saveTicketsCallCount, 0);
      expect(find.byType(PaymentSuccessScreen), findsNothing);
      expect(find.textContaining('ORD-12345'), findsOneWidget);
    });

    testWidgets('cuando attendeesRaw es válido y completo, guarda tickets y navega a PaymentSuccessScreen', (WidgetTester tester) async {
      final fakeApi = FakeApiService(
        statusToReturn: PaymentVerificationStatus.completed,
        attendeesRawToReturn: [
          {
            'id': 'REAL-ID-789',
            'qrCode': 'SIGNED-CRYPTOGRAPHIC-DATA-XYZ',
            'imageUrl': 'https://example.com/qr.png',
          },
        ],
        voucherId: 'VOUCHER-555',
      );
      final fakeStorage = FakeStorageService();

      await tester.pumpWidget(
        MaterialApp(
          home: BnbPaymentScreen(
            event: createDummyEvent(),
            selectedTier: TicketTier(name: 'General', price: 100.0),
            bnbResponse: createDummyBnbResponse(),
            attendees: [AttendeeInput(name: 'Juan Perez', ci: '1234567')],
            apiService: fakeApi,
            storageService: fakeStorage,
            initialSecondsRemaining: 900,
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // Debe guardar exactamente las entradas firmadas
      expect(fakeStorage.saveTicketsCallCount, 1);
      expect(fakeStorage.savedTickets.length, 1);
      expect(fakeStorage.savedTickets.first.id, 'REAL-ID-789');
      expect(fakeStorage.savedTickets.first.qrCode, 'SIGNED-CRYPTOGRAPHIC-DATA-XYZ');

      // Debe navegar a PaymentSuccessScreen
      expect(find.byType(PaymentSuccessScreen), findsOneWidget);
    });
  });

  group('Issue #9: Estado de carga del botón Ya realicé el pago', () {
    testWidgets('botón muestra spinner y "Verificando..." durante la consulta y regresa al estado original al finalizar (pending)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeApi = FakeApiService(
        statusToReturn: PaymentVerificationStatus.pending,
        checkStatusDelay: const Duration(milliseconds: 600),
      );

      final fakeStorage = FakeStorageService();
      final dummyEvent = createDummyEvent();
      final dummyBnbResponse = createDummyBnbResponse();

      await tester.pumpWidget(
        MaterialApp(
          home: BnbPaymentScreen(
            bnbResponse: dummyBnbResponse,
            event: dummyEvent,
            selectedTier: dummyEvent.tiers.first,
            attendees: [
              AttendeeInput(name: 'Ana Perez', ci: '1234567'),
            ],
            apiService: fakeApi,
            storageService: fakeStorage,
          ),
        ),
      );

      // Estado inicial: botón muestra "Ya realicé el pago" y NO spinner
      expect(find.text('Ya realicé el pago'), findsOneWidget);
      expect(find.text('Verificando...'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // El cronómetro y QR están visibles
      expect(find.textContaining('Tiempo restante:'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);

      // Presionar el botón "Ya realicé el pago"
      await tester.tap(find.text('Ya realicé el pago'));
      // Un solo pump para reflejar setState(() { _isChecking = true; })
      await tester.pump();

      // Estado intermedio (mientras checkBnbStatus está demorando 600ms):
      // El botón ahora muestra "Verificando..." y el spinner
      expect(find.text('Verificando...'), findsOneWidget);
      expect(find.text('Ya realicé el pago'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // El cronómetro y el QR siguen completamente visibles durante la verificación
      expect(find.textContaining('Tiempo restante:'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);

      // Intentar presionar de nuevo no dispara una segunda llamada concurrente
      await tester.tap(find.text('Verificando...'));
      await tester.pump();
      expect(fakeApi.checkStatusCallCount, 1);

      // Avanzar el tiempo para que concluya el delay de 600ms y el finally
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // Al finalizar (status PENDING):
      // Muestra el SnackBar informativo
      expect(find.textContaining('Aún no detectamos la transferencia en el banco'), findsOneWidget);
      // El botón regresa a su estado original "Ya realicé el pago"
      expect(find.text('Ya realicé el pago'), findsOneWidget);
      expect(find.text('Verificando...'), findsNothing);
    });

    testWidgets('en caso de error en la API, el botón muestra carga y regresa a su estado original tras el fallo', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final failingApi = FailingDelayedApiService(delay: const Duration(milliseconds: 400));
      final fakeStorage = FakeStorageService();
      final dummyEvent = createDummyEvent();
      final dummyBnbResponse = createDummyBnbResponse();

      await tester.pumpWidget(
        MaterialApp(
          home: BnbPaymentScreen(
            bnbResponse: dummyBnbResponse,
            event: dummyEvent,
            selectedTier: dummyEvent.tiers.first,
            attendees: [
              AttendeeInput(name: 'Ana Perez', ci: '1234567'),
            ],
            apiService: failingApi,
            storageService: fakeStorage,
          ),
        ),
      );

      expect(find.text('Ya realicé el pago'), findsOneWidget);

      await tester.tap(find.text('Ya realicé el pago'));
      await tester.pump();

      // Estado intermedio: cargando
      expect(find.text('Verificando...'), findsOneWidget);

      // Avanzar y completar la excepción
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Muestra SnackBar con mensaje sanitizado seguro y botón restaurado
      expect(find.text('No pudimos conectar con el servidor. Por favor revisá tu conexión a internet.'), findsOneWidget);
      expect(find.textContaining('Error al consultar:'), findsNothing);
      expect(find.text('Ya realicé el pago'), findsOneWidget);
      expect(find.text('Verificando...'), findsNothing);
    });
  });

  group('Issue #10: Manejo de errores de red en polling automático de BNB', () {
    testWidgets('3 fallos consecutivos en polling automático muestran el banner de advertencia', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeApi = FakeApiService(
        exceptionToThrow: Exception('Sin conexión WiFi'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BnbPaymentScreen(
            event: createDummyEvent(),
            selectedTier: TicketTier(name: 'General', price: 100.0),
            bnbResponse: createDummyBnbResponse(),
            attendees: [AttendeeInput(name: 'Carlos Perez', ci: '1234567')],
            apiService: fakeApi,
          ),
        ),
      );

      // Inicialmente no hay banner de error
      expect(find.byKey(const Key('bnb_poll_failure_banner')), findsNothing);
      expect(fakeApi.checkStatusCallCount, 0);

      // Tick 1 (4s): 1 fallo
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(fakeApi.checkStatusCallCount, 1);
      expect(find.byKey(const Key('bnb_poll_failure_banner')), findsNothing);

      // Tick 2 (4s): 2 fallos
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(fakeApi.checkStatusCallCount, 2);
      expect(find.byKey(const Key('bnb_poll_failure_banner')), findsNothing);

      // Tick 3 (4s): 3 fallos consecutivos -> Banner de advertencia visible
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(fakeApi.checkStatusCallCount, 3);
      expect(find.byKey(const Key('bnb_poll_failure_banner')), findsOneWidget);
      expect(
        find.text("No pudimos verificar el pago. Verificá tu conexión o tocá 'Ya realicé el pago' para reintentar manualmente."),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('al recuperar la red tras 3 fallos, un poll exitoso oculta el banner de error', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeApi = FakeApiService(
        throwExceptionTimes: 3,
        statusToReturn: PaymentVerificationStatus.pending,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BnbPaymentScreen(
            event: createDummyEvent(),
            selectedTier: TicketTier(name: 'General', price: 100.0),
            bnbResponse: createDummyBnbResponse(),
            attendees: [AttendeeInput(name: 'Carlos Perez', ci: '1234567')],
            apiService: fakeApi,
          ),
        ),
      );

      // 3 fallos consecutivos
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      // Banner visible en fallo 3
      expect(find.byKey(const Key('bnb_poll_failure_banner')), findsOneWidget);

      // Tick 4 (4s): 4ta llamada tiene éxito (Pending)
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      // El banner desaparece al tener éxito
      expect(find.byKey(const Key('bnb_poll_failure_banner')), findsNothing);
    });

    testWidgets('click manual en Ya realicé el pago muestra SnackBar de error sin alterar el flujo', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeApi = FakeApiService(
        exceptionToThrow: Exception('Conexión perdida'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BnbPaymentScreen(
            event: createDummyEvent(),
            selectedTier: TicketTier(name: 'General', price: 100.0),
            bnbResponse: createDummyBnbResponse(),
            attendees: [AttendeeInput(name: 'Carlos Perez', ci: '1234567')],
            apiService: fakeApi,
          ),
        ),
      );

      await tester.tap(find.text('Ya realicé el pago'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('No pudimos conectar con el servidor. Por favor revisá tu conexión a internet.'), findsOneWidget);
      expect(find.textContaining('Conexión perdida'), findsNothing);
      expect(find.textContaining('Error al consultar:'), findsNothing);
    });
  });

  group('Issue #11: Falla al decodificar Base64 de QR en BnbPaymentScreen', () {
    testWidgets('Base64 corrupto muestra widget de error, oculta contador, deshabilita botón y no renderiza Image.memory', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeApi = FakeApiService();

      await tester.pumpWidget(
        MaterialApp(
          home: BnbPaymentScreen(
            event: createDummyEvent(),
            selectedTier: TicketTier(name: 'General', price: 100.0),
            bnbResponse: createDummyBnbResponse(qrBase64: 'data:image/png;base64,@@@esto_no_es_base64@@@'),
            attendees: [AttendeeInput(name: 'Carlos Perez', ci: '1234567')],
            apiService: fakeApi,
          ),
        ),
      );

      // Muestra ícono de error y texto explicativo
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(
        find.text('No pudimos generar el código QR del banco. Tocá Reintentar para volver a pedirlo.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(ElevatedButton, 'Reintentar'), findsOneWidget);

      // NO renderiza Image.memory
      expect(find.byType(Image), findsNothing);

      // Contador de expiración oculto
      expect(find.byType(BnbCountdownBadge), findsNothing);

      // Botón "Ya realicé el pago" deshabilitado
      final payButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Ya realicé el pago'));
      expect(payButton.onPressed, isNull);
    });

    testWidgets('si el reintento de regeneración falla, muestra mensaje de fallo sin crashear', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeApi = FakeApiService(
        generateBnbQrException: Exception('No se pudo regenerar en el banco'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BnbPaymentScreen(
            event: createDummyEvent(),
            selectedTier: TicketTier(name: 'General', price: 100.0),
            bnbResponse: createDummyBnbResponse(qrBase64: 'data:image/png;base64,@@@invalido@@@'),
            attendees: [AttendeeInput(name: 'Carlos Perez', ci: '1234567')],
            apiService: fakeApi,
          ),
        ),
      );

      // Presionar Reintentar
      await tester.tap(find.widgetWithText(ElevatedButton, 'Reintentar'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Muestra mensaje de reintento fallido
      expect(
        find.text('Reintento fallido. Probá más tarde o contactá a soporte.'),
        findsOneWidget,
      );
      // El botón Reintentar sigue visible para volver a intentar
      expect(find.widgetWithText(ElevatedButton, 'Reintentar'), findsOneWidget);
    });

    testWidgets('si el reintento es exitoso, muestra Image.memory, reactiva contador y habilita pago', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final validBnbResponse = createDummyBnbResponse();
      final fakeApi = FakeApiService(
        bnbQrResponseToReturn: validBnbResponse,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BnbPaymentScreen(
            event: createDummyEvent(),
            selectedTier: TicketTier(name: 'General', price: 100.0),
            bnbResponse: createDummyBnbResponse(qrBase64: 'data:image/png;base64,@@@invalido@@@'),
            attendees: [AttendeeInput(name: 'Carlos Perez', ci: '1234567')],
            apiService: fakeApi,
          ),
        ),
      );

      // Inicialmente en error
      expect(find.byType(Image), findsNothing);
      expect(find.byType(BnbCountdownBadge), findsNothing);

      // Presionar Reintentar con API retornando QR válido
      await tester.tap(find.widgetWithText(ElevatedButton, 'Reintentar'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Ahora se recuperó con éxito
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(BnbCountdownBadge), findsOneWidget);
      final payButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Ya realicé el pago'));
      expect(payButton.onPressed, isNotNull);
    });
  });
}
