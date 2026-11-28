import 'package:eventhub_mobile/models/attendee.dart';
import 'package:eventhub_mobile/models/event.dart';
import 'package:eventhub_mobile/models/order.dart';
import 'package:eventhub_mobile/models/ticket.dart';
import 'package:eventhub_mobile/services/api_service.dart';
import 'package:eventhub_mobile/services/storage_service.dart';

class FakeApiService extends ApiService {
  int checkStatusCallCount = 0;
  final List<({String orderId, String? qrId})> checkStatusCalls = [];
  PaymentVerificationStatus statusToReturn;
  List<dynamic>? attendeesRawToReturn;
  String? voucherIdToReturn;
  List<Event>? eventsToReturn;
  Duration? checkStatusDelay;
  Exception? exceptionToThrow;
  int? throwExceptionTimes;
  int generateBnbQrCallCount = 0;
  int getEventsCallCount = 0;
  BnbQrResponse? bnbQrResponseToReturn;
  Exception? generateBnbQrException;
  Object? generateBnbQrError;
  Future<List<Event>> Function()? getEventsHandler;

  FakeApiService({
    this.statusToReturn = PaymentVerificationStatus.expired,
    this.attendeesRawToReturn,
    this.eventsToReturn,
    String? voucherId,
    String? voucherIdToReturn,
    this.checkStatusDelay,
    this.exceptionToThrow,
    this.throwExceptionTimes,
    this.bnbQrResponseToReturn,
    this.generateBnbQrException,
    this.generateBnbQrError,
    this.getEventsHandler,
  }) : voucherIdToReturn = voucherId ?? voucherIdToReturn;

  @override
  Future<BnbQrResponse> generateBnbQr({
    required String eventId,
    required String buyerName,
    String? buyerEmail,
    String? buyerPhone,
    required String tier,
    required List<AttendeeInput> attendees,
  }) async {
    generateBnbQrCallCount++;
    if (generateBnbQrError != null) {
      throw generateBnbQrError!;
    }
    if (generateBnbQrException != null) {
      throw generateBnbQrException!;
    }
    return bnbQrResponseToReturn ?? createDummyBnbResponse();
  }

  @override
  Future<List<Event>> getEvents() async {
    getEventsCallCount++;
    if (getEventsHandler != null) {
      return getEventsHandler!();
    }
    return eventsToReturn ?? [];
  }

  @override
  Future<BnbStatusResponse> checkBnbStatus({
    required String orderId,
    String? qrId,
  }) async {
    checkStatusCallCount++;
    checkStatusCalls.add((orderId: orderId, qrId: qrId));
    if (checkStatusDelay != null) {
      await Future.delayed(checkStatusDelay!);
    }
    if (throwExceptionTimes != null && checkStatusCallCount <= throwExceptionTimes!) {
      throw exceptionToThrow ?? Exception('Error de conexión con el banco');
    }
    if (exceptionToThrow != null && throwExceptionTimes == null) {
      throw exceptionToThrow!;
    }
    return BnbStatusResponse(
      status: statusToReturn,
      orderId: orderId,
      message: 'Status: $statusToReturn',
      attendeesRaw: attendeesRawToReturn,
      voucherId: voucherIdToReturn,
    );
  }
}

class FailingDelayedApiService extends ApiService {
  final Duration delay;
  FailingDelayedApiService({required this.delay});

  @override
  Future<BnbStatusResponse> checkBnbStatus({required String orderId, String? qrId}) async {
    await Future.delayed(delay);
    throw Exception('Error de conexión con el banco');
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

BnbQrResponse createDummyBnbResponse({
  String? qrBase64,
  String orderId = 'ORD-12345',
  String qrId = 'QR-999',
  double totalAmount = 100.0,
  DateTime? expiresAt,
  int? expiresInSeconds,
}) {
  return BnbQrResponse(
    success: true,
    orderId: orderId,
    qrId: qrId,
    qrBase64: qrBase64 ??
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
    totalAmount: totalAmount,
    currency: 'BOB',
    eventTitle: 'Concierto de Prueba',
    tier: 'General',
    quantity: 1,
    expiresAt: expiresAt,
    expiresInSeconds: expiresInSeconds,
  );
}
