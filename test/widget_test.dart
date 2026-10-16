import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub_mobile/main.dart';
import 'package:eventhub_mobile/widgets/eventhub_logo.dart';
import 'package:eventhub_mobile/models/event.dart';
import 'package:eventhub_mobile/models/order.dart';
import 'package:eventhub_mobile/models/attendee.dart';
import 'package:eventhub_mobile/screens/bnb_payment_screen.dart';
import 'package:eventhub_mobile/services/api_service.dart';

class FakeApiService extends ApiService {
  int checkStatusCallCount = 0;
  PaymentVerificationStatus statusToReturn;

  FakeApiService({this.statusToReturn = PaymentVerificationStatus.expired});

  @override
  Future<BnbStatusResponse> checkBnbStatus({
    required String orderId,
    String? qrId,
  }) async {
    checkStatusCallCount++;
    return BnbStatusResponse(
      status: statusToReturn,
      orderId: orderId,
      message: 'Status: $statusToReturn',
    );
  }
}

Event createDummyEvent() {
  return Event(
    id: 'evt-1',
    title: 'Concierto de Prueba',
    subtitle: 'En vivo',
    heroImage: '',
    images: [],
    startsAt: DateTime.now().add(const Duration(days: 2)),
    time: '20:00',
    location: 'Teatro al Aire Libre',
    address: 'Av. del Poeta',
    description: ['Gran concierto'],
    category: 'Música',
    categoryColor: '#EC3013',
    tiers: [TicketTier(name: 'General', price: 100.0)],
    pricingNotes: [],
    isSoldOut: false,
  );
}

BnbQrResponse createDummyBnbResponse({String? qrBase64}) {
  return BnbQrResponse(
    success: true,
    orderId: 'ORD-12345',
    qrId: 'QR-999',
    qrBase64: qrBase64 ??
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
    totalAmount: 100.0,
    currency: 'BOB',
    eventTitle: 'Concierto de Prueba',
    tier: 'General',
    quantity: 1,
  );
}

void main() {
  testWidgets('EventHubApp smoke test - renders logo and initial view', (WidgetTester tester) async {
    // Construir la app y disparar un frame inicial
    await tester.pumpWidget(const EventHubApp());

    // Verificar que el nuevo logotipo EventHubLogo se renderiza en la cabecera
    expect(find.byType(EventHubLogo), findsOneWidget);

    // Verificar que el botón de Mis Entradas está presente en la barra superior
    expect(find.byIcon(Icons.confirmation_number_outlined), findsOneWidget);
  });

  testWidgets('EventHubLogo widget test - renders correctly with dual color branding', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EventHubLogo(fontSize: 24),
        ),
      ),
    );

    expect(find.byType(EventHubLogo), findsOneWidget);
    expect(find.byType(RichText), findsOneWidget);
  });

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
      expect(find.text('Pago con QR Simple BNB'), findsOneWidget);

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

      expect(find.text('Pago con QR Simple BNB'), findsOneWidget);

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
}

