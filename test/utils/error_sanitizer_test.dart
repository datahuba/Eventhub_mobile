import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:eventhub_mobile/utils/error_sanitizer.dart';

void main() {
  group('ErrorSanitizer Unit Tests', () {
    test('Mapea TimeoutException a mensaje seguro sin tiempo ni stack trace', () {
      final err = TimeoutException('Future not completed after 0:00:20.000000');
      final result = ErrorSanitizer.sanitize(err);

      expect(result, 'El servidor tardó demasiado en responder. Por favor revisá tu conexión e intentá de nuevo.');
      expect(result.contains('0:00:20'), false);
      expect(result.contains('TimeoutException'), false);
    });

    test('Mapea SocketException y ClientException a mensaje seguro de conexión', () {
      const socketErr = SocketException('Connection refused, errno = 111, address = 192.168.1.100, port = 4000');
      final clientErr = http.ClientException('ClientException: Connection closed before full header was received, uri = https://api.pagaya.bo/v1/charge');

      final socketResult = ErrorSanitizer.sanitize(socketErr);
      final clientResult = ErrorSanitizer.sanitize(clientErr);

      expect(socketResult, 'No pudimos conectar con el servidor. Por favor revisá tu conexión a internet.');
      expect(clientResult, 'No pudimos conectar con el servidor. Por favor revisá tu conexión a internet.');

      // Verificar que NUNCA se filtran IPs, puertos, URLs o nombres de clases
      expect(socketResult.contains('192.168.1.100'), false);
      expect(socketResult.contains('4000'), false);
      expect(socketResult.contains('SocketException'), false);
      expect(clientResult.contains('api.pagaya.bo'), false);
      expect(clientResult.contains('ClientException'), false);
    });

    test('Mapea FormatException y errores HTML de proxies a mensaje seguro de respuesta inesperada', () {
      const formatErr = FormatException('Unexpected character at line 1 column 1: <');
      const proxyErr = '502 Bad Gateway: <html><body>nginx proxy error</body></html>';

      final formatResult = ErrorSanitizer.sanitize(formatErr);
      final proxyResult = ErrorSanitizer.sanitize(proxyErr);

      expect(formatResult, 'Respuesta inesperada del servidor. Por favor intentá nuevamente más tarde.');
      expect(proxyResult, 'Respuesta inesperada del servidor. Por favor intentá nuevamente más tarde.');

      expect(formatResult.contains('Unexpected character'), false);
      expect(proxyResult.contains('nginx'), false);
      expect(proxyResult.contains('<html>'), false);
    });

    test('Mapea errores 500 y de pasarela a mensaje de pagos sin afectar eventos', () {
      const serverErr = '500 Internal Server Error: Database transaction deadlock';
      const gatewayErr = 'Error en pasarela de pagos Pagaya: Code 9999 Signature Mismatch';

      final paymentResult = ErrorSanitizer.sanitizePayment(serverErr);
      final gatewayResult = ErrorSanitizer.sanitizePayment(gatewayErr);

      expect(paymentResult, 'El servicio de pagos no está disponible temporalmente. Por favor intentá en unos minutos.');
      expect(gatewayResult, 'El servicio de pagos no está disponible temporalmente. Por favor intentá en unos minutos.');

      expect(paymentResult.contains('Database'), false);
      expect(gatewayResult.contains('Pagaya'), false);
      expect(gatewayResult.contains('9999'), false);
    });

    test('Mapea errores 500 en catálogo o detalle de eventos a servicio de eventos (no de pagos)', () {
      const eventServerErr = '500 Internal Server Error en /api/events: Connection timeout to PostgreSQL';

      final eventsResult = ErrorSanitizer.sanitizeEvents(eventServerErr);
      final eventsFallback = ErrorSanitizer.sanitizeEvents('Error desconocido al listar cartelera');

      expect(eventsResult, 'El servicio de eventos no está disponible temporalmente. Por favor intentá en unos instantes.');
      expect(eventsResult.contains('pagos'), false);
      expect(eventsResult.contains('PostgreSQL'), false);

      expect(eventsFallback, 'No se pudieron cargar los eventos. Por favor intentá nuevamente.');
      expect(eventsFallback.contains('pagos'), false);
    });

    test('Distingue límite máximo de 10 entradas incluso si el mensaje menciona cupo o capacidad', () {
      const limitErr1 = 'No se pueden comprar más de 10 entradas por orden. Por razones de seguridad y control de cupos, el límite máximo permitido por orden es de 10 entradas.';
      const limitErr2 = 'Supera el cupo máximo por orden. Límite máximo: 10 entradas.';
      const limitErr3 = 'El límite máximo de capacidad por compra es de 10 entradas.';
      const limitErr4 = 'No se pueden comprar más de 10 entradas.';

      expect(ErrorSanitizer.sanitize(limitErr1), 'No se pueden comprar más de 10 entradas por orden.');
      expect(ErrorSanitizer.sanitize(limitErr2), 'No se pueden comprar más de 10 entradas por orden.');
      expect(ErrorSanitizer.sanitize(limitErr3), 'No se pueden comprar más de 10 entradas por orden.');
      expect(ErrorSanitizer.sanitize(limitErr4), 'No se pueden comprar más de 10 entradas por orden.');
    });

    test('Distingue capacidad restante mayor a cero y no lo considera agotado', () {
      // Caso backend típico: incluye la palabra "agotadas" pero informa Cupos restantes: 3
      const backendRemainingErr = 'Entradas agotadas para el sector "General". Cupos restantes: 3.';
      const remainingPluralErr = 'Capacidad insuficiente. Cupos restantes: 4';
      const remainingSingularErr = 'No hay suficiente capacidad. Cupos restantes: 1';
      const remainingAltErr = 'Solo quedan 2 cupos disponibles para este sector';
      const remainingGeneralErr = 'Capacidad insuficiente para la cantidad solicitada';

      expect(ErrorSanitizer.sanitize(backendRemainingErr), 'No hay suficientes entradas disponibles. Solo quedan 3 cupos disponibles.');
      expect(ErrorSanitizer.sanitize(remainingPluralErr), 'No hay suficientes entradas disponibles. Solo quedan 4 cupos disponibles.');
      expect(ErrorSanitizer.sanitize(remainingSingularErr), 'No hay suficientes entradas disponibles. Solo queda 1 cupo disponible.');
      expect(ErrorSanitizer.sanitize(remainingAltErr), 'No hay suficientes entradas disponibles. Solo quedan 2 cupos disponibles.');
      expect(ErrorSanitizer.sanitize(remainingGeneralErr), 'No hay suficientes entradas disponibles para la cantidad solicitada.');
    });

    test('Mapea mensajes de agotado real o capacidad 0 a entradas agotadas', () {
      const soldOutZero1 = 'Cupo insuficiente. Capacidad restante: 0';
      const soldOutZero2 = 'Entradas agotadas para el sector "VIP". Cupos restantes: 0.';
      const soldOutText = 'Entradas agotadas para este sector';
      const soldOutEnglish = 'Sector VIP is sold out';
      const soldOutSinEntradas = 'Sin entradas disponibles';
      const soldOutSinCupo = 'Sin cupo disponible';

      expect(ErrorSanitizer.sanitize(soldOutZero1), 'Lo sentimos, las entradas para este sector se han agotado.');
      expect(ErrorSanitizer.sanitize(soldOutZero2), 'Lo sentimos, las entradas para este sector se han agotado.');
      expect(ErrorSanitizer.sanitize(soldOutText), 'Lo sentimos, las entradas para este sector se han agotado.');
      expect(ErrorSanitizer.sanitize(soldOutEnglish), 'Lo sentimos, las entradas para este sector se han agotado.');
      expect(ErrorSanitizer.sanitize(soldOutSinEntradas), 'Lo sentimos, las entradas para este sector se han agotado.');
      expect(ErrorSanitizer.sanitize(soldOutSinCupo), 'Lo sentimos, las entradas para este sector se han agotado.');
    });

    test('Fallback estricto ante objetos o excepciones no reconocidas nunca expone el contenido crudo', () {
      final weirdErr = Exception('SECRET_KEY_EXPOSURE_CRASH_DUMP: trace 0xdeadbeef at internal_driver.c:42');
      final result = ErrorSanitizer.sanitize(weirdErr);

      expect(result, 'No se pudo completar la operación. Por favor intentá nuevamente.');
      expect(result.contains('SECRET_KEY'), false);
      expect(result.contains('0xdeadbeef'), false);
      expect(result.contains('internal_driver'), false);
    });

    test('Maneja valores nulos de forma segura', () {
      final result = ErrorSanitizer.sanitize(null);
      expect(result, 'Ocurrió un problema inesperado. Por favor intentá nuevamente.');
    });
  });
}
