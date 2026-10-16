import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub_mobile/models/ticket.dart';
import 'package:eventhub_mobile/services/wallet_pass_service.dart';

void main() {
  group('Model Ticket & WalletPassService: Validación de identificadores legítimos', () {
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
      expect(
        WalletPassService.isValidTicket(
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
        ),
        isTrue,
      );
    });
  });
}
