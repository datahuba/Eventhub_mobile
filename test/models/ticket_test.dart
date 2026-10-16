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
      expect(WalletPassService.isValidTicket(id: 'REAL-UUID-123', qrCode: 'ENCRYPTED-PAYLOAD'), isTrue);
      expect(WalletPassService.isValidTicket(id: 'TKT-171000-0', qrCode: 'ENCRYPTED-PAYLOAD'), isFalse);
      expect(WalletPassService.isValidTicket(id: 'REAL-UUID-123', qrCode: 'VALID-ORD-99-0'), isFalse);
      expect(WalletPassService.isValidTicket(id: '', qrCode: 'ENCRYPTED-PAYLOAD'), isFalse);
      expect(WalletPassService.isValidTicket(id: 'REAL-UUID-123', qrCode: ''), isFalse);
    });
  });
}
