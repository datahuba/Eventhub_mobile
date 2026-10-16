import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub_mobile/main.dart';
import 'package:eventhub_mobile/widgets/eventhub_logo.dart';
import 'package:eventhub_mobile/models/event.dart';
import 'package:eventhub_mobile/models/order.dart';
import 'package:eventhub_mobile/models/attendee.dart';
import 'package:eventhub_mobile/models/ticket.dart';
import 'package:eventhub_mobile/screens/bnb_payment_screen.dart';
import 'package:eventhub_mobile/screens/events_screen.dart';
import 'package:eventhub_mobile/screens/payment_success_screen.dart';
import 'package:eventhub_mobile/services/api_service.dart';
import 'package:eventhub_mobile/services/storage_service.dart';
import 'package:eventhub_mobile/services/wallet_pass_service.dart';

class FakeApiService extends ApiService {
  int checkStatusCallCount = 0;
  PaymentVerificationStatus statusToReturn;
  List<dynamic>? attendeesRawToReturn;
  String? voucherIdToReturn;
  List<Event>? eventsToReturn;

  FakeApiService({
    this.statusToReturn = PaymentVerificationStatus.expired,
    this.attendeesRawToReturn,
    this.eventsToReturn,
    String? voucherId,
    String? voucherIdToReturn,
  }) : voucherIdToReturn = voucherId ?? voucherIdToReturn;

  @override
  Future<List<Event>> getEvents() async {
    return eventsToReturn ?? [];
  }

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
      attendeesRaw: attendeesRawToReturn,
      voucherId: voucherIdToReturn,
    );
  }
}

class FakeStorageService extends StorageService {
  int saveTicketsCallCount = 0;
  List<IssuedTicket> savedTickets = [];

  @override
  Future<void> saveTickets(List<IssuedTicket> newTickets) async {
    saveTicketsCallCount++;
    savedTickets.addAll(newTickets);
  }

  @override
  Future<List<IssuedTicket>> getTickets() async {
    return savedTickets;
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

  group('Issue #5: Rechazo de entradas incompletas o sintéticas', () {
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

    test('IssuedTicket lanza ArgumentError si id o qrCode están vacíos o inician con TKT- o VALID-', () {
      expect(
        () => IssuedTicket(
          id: 'TKT-12345678-0',
          orderId: 'ORD-1',
          eventTitle: 'Test',
          eventDate: 'Hoy',
          eventLocation: 'Lugar',
          tierName: 'General',
          attendeeName: 'Juan',
          attendeeCi: '12345',
          qrCode: 'SIGNED-DATA',
          purchasedAt: DateTime.now(),
        ),
        throwsArgumentError,
      );

      expect(
        () => IssuedTicket(
          id: 'REAL-ID',
          orderId: 'ORD-1',
          eventTitle: 'Test',
          eventDate: 'Hoy',
          eventLocation: 'Lugar',
          tierName: 'General',
          attendeeName: 'Juan',
          attendeeCi: '12345',
          qrCode: 'VALID-ORD-1-0',
          purchasedAt: DateTime.now(),
        ),
        throwsArgumentError,
      );

      expect(
        () => IssuedTicket(
          id: '',
          orderId: 'ORD-1',
          eventTitle: 'Test',
          eventDate: 'Hoy',
          eventLocation: 'Lugar',
          tierName: 'General',
          attendeeName: 'Juan',
          attendeeCi: '12345',
          qrCode: 'SIGNED-DATA',
          purchasedAt: DateTime.now(),
        ),
        throwsArgumentError,
      );
    });

    test('WalletPassService.isValidTicket valida correctamente los identificadores legítimos', () {
      expect(WalletPassService.isValidTicket(
        IssuedTicket(
          id: 'REAL-ID-123',
          orderId: 'ORD-1',
          eventTitle: 'Test',
          eventDate: 'Hoy',
          eventLocation: 'Lugar',
          tierName: 'General',
          attendeeName: 'Juan',
          attendeeCi: '12345',
          qrCode: 'CRYPTO-DATA',
          purchasedAt: DateTime.now(),
        ),
      ), isTrue);
    });
  });

  group('Issue #6: Filtrado por pestaña Pasados / En Cartelera', () {
    final pastEvent1 = Event(
      id: 'past-1',
      title: 'Festival Pasado Rock',
      subtitle: 'Concluido',
      heroImage: '',
      images: [],
      startsAt: DateTime.now().subtract(const Duration(days: 10)),
      time: '18:00',
      location: 'La Paz',
      address: 'Calle 1',
      description: ['Desc'],
      category: 'Música',
      categoryColor: '#EC3013',
      tiers: [TicketTier(name: 'General', price: 50.0)],
      pricingNotes: [],
      isSoldOut: false,
    );

    final pastEvent2 = Event(
      id: 'past-2',
      title: 'Obra Teatral Pasada',
      subtitle: 'Concluido',
      heroImage: '',
      images: [],
      startsAt: DateTime.now().subtract(const Duration(days: 20)),
      time: '19:00',
      location: 'Cochabamba',
      address: 'Calle 2',
      description: ['Desc'],
      category: 'Teatro',
      categoryColor: '#EC3013',
      tiers: [TicketTier(name: 'General', price: 80.0)],
      pricingNotes: [],
      isSoldOut: false,
    );

    final futureEvent1 = Event(
      id: 'future-1',
      title: 'Concierto Futuro Pop',
      subtitle: 'Próximamente',
      heroImage: '',
      images: [],
      startsAt: DateTime.now().add(const Duration(days: 10)),
      time: '20:00',
      location: 'La Paz',
      address: 'Calle 3',
      description: ['Desc'],
      category: 'Música',
      categoryColor: '#EC3013',
      tiers: [TicketTier(name: 'General', price: 120.0)],
      pricingNotes: [],
      isSoldOut: false,
    );

    final futureEvent2 = Event(
      id: 'future-2',
      title: 'Torneo Deportivo Futuro',
      subtitle: 'Próximamente',
      heroImage: '',
      images: [],
      startsAt: DateTime.now().add(const Duration(days: 15)),
      time: '16:00',
      location: 'Santa Cruz',
      address: 'Calle 4',
      description: ['Desc'],
      category: 'Deportes',
      categoryColor: '#EC3013',
      tiers: [TicketTier(name: 'General', price: 40.0)],
      pricingNotes: [],
      isSoldOut: false,
    );

    final mixedEvents = [pastEvent1, pastEvent2, futureEvent1, futureEvent2];

    test('Helper de filtrado: pestaña 0 ("En Cartelera") retorna solo eventos vigentes (isPast == false)', () {
      final results = EventsScreen.filterEventsHelper(mixedEvents, selectedTab: 0);

      expect(results.length, 2);
      expect(results.every((e) => !e.isPast), isTrue);
      expect(results.map((e) => e.id), containsAll(['future-1', 'future-2']));
      expect(results.map((e) => e.id), isNot(contains('past-1')));
    });

    test('Helper de filtrado: pestaña 1 ("Pasados") retorna solo eventos ya concluidos (isPast == true)', () {
      final results = EventsScreen.filterEventsHelper(mixedEvents, selectedTab: 1);

      expect(results.length, 2);
      expect(results.every((e) => e.isPast), isTrue);
      expect(results.map((e) => e.id), containsAll(['past-1', 'past-2']));
      expect(results.map((e) => e.id), isNot(contains('future-1')));
    });

    test('Helper de filtrado: combina pestaña "Pasados" con categoría aplicando lógica AND', () {
      final resultsMusic = EventsScreen.filterEventsHelper(
        mixedEvents,
        selectedTab: 1,
        selectedCategory: 'Música',
      );

      expect(resultsMusic.length, 1);
      expect(resultsMusic.first.id, 'past-1');

      final resultsTheater = EventsScreen.filterEventsHelper(
        mixedEvents,
        selectedTab: 1,
        selectedCategory: 'Teatro',
      );

      expect(resultsTheater.length, 1);
      expect(resultsTheater.first.id, 'past-2');
    });

    test('Helper de filtrado: combina pestaña "Pasados" con búsqueda de texto aplicando lógica AND', () {
      final results = EventsScreen.filterEventsHelper(
        mixedEvents,
        selectedTab: 1,
        searchQuery: 'Rock',
      );

      expect(results.length, 1);
      expect(results.first.id, 'past-1');
    });

    testWidgets('Widget EventsScreen: cambia contenido al alternar entre En Cartelera y Pasados', (WidgetTester tester) async {
      final fakeApi = FakeApiService(eventsToReturn: mixedEvents);

      await tester.pumpWidget(
        MaterialApp(
          home: EventsScreen(apiService: fakeApi),
        ),
      );

      // Esperar carga de FutureBuilder
      await tester.pumpAndSettle();

      // Pestaña inicial: 0 ("En Cartelera") -> solo futuros visibles
      expect(find.text('Concierto Futuro Pop'), findsOneWidget);
      expect(find.text('Torneo Deportivo Futuro'), findsOneWidget);
      expect(find.text('Festival Pasado Rock'), findsNothing);
      expect(find.text('Obra Teatral Pasada'), findsNothing);

      // Tocar pestaña "Pasados"
      await tester.tap(find.text('Pasados'));
      await tester.pumpAndSettle();

      // Ahora solo deben estar visibles los eventos pasados
      expect(find.text('Festival Pasado Rock'), findsOneWidget);
      expect(find.text('Obra Teatral Pasada'), findsOneWidget);
      expect(find.text('Concierto Futuro Pop'), findsNothing);
      expect(find.text('Torneo Deportivo Futuro'), findsNothing);

      // Debe mostrar el contador de filtros activos (botón Limpiar filtros visible)
      expect(find.text('Limpiar filtros'), findsOneWidget);

      // Tocar nuevamente "En Cartelera"
      await tester.tap(find.text('En Cartelera'));
      await tester.pumpAndSettle();

      // Vuelven los eventos vigentes
      expect(find.text('Concierto Futuro Pop'), findsOneWidget);
      expect(find.text('Torneo Deportivo Futuro'), findsOneWidget);
      expect(find.text('Festival Pasado Rock'), findsNothing);
    });
  });
}



