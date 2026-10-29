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

    test('Mapea errores 500 y de pasarela interna a mensaje de indisponibilidad temporal', () {
      const serverErr = '500 Internal Server Error: Database transaction deadlock';
      const gatewayErr = 'Error en pasarela de pagos Pagaya: Code 9999 Signature Mismatch';

      final serverResult = ErrorSanitizer.sanitize(serverErr);
      final gatewayResult = ErrorSanitizer.sanitize(gatewayErr);

      expect(serverResult, 'El servicio de pagos no está disponible temporalmente. Por favor intentá en unos minutos.');
      expect(gatewayResult, 'El servicio de pagos no está disponible temporalmente. Por favor intentá en unos minutos.');

      expect(serverResult.contains('Database'), false);
      expect(gatewayResult.contains('Pagaya'), false);
      expect(gatewayResult.contains('9999'), false);
    });

    test('Mapea mensajes de agotado/aforo a mensaje seguro de entradas agotadas', () {
      const soldOutErr1 = 'Cupo insuficiente. Capacidad restante: 0';
      const soldOutErr2 = 'Entradas agotadas para este sector';
      const soldOutErr3 = 'Sector VIP is sold out';

      expect(ErrorSanitizer.sanitize(soldOutErr1), 'Lo sentimos, las entradas para este sector se han agotado.');
      expect(ErrorSanitizer.sanitize(soldOutErr2), 'Lo sentimos, las entradas para este sector se han agotado.');
      expect(ErrorSanitizer.sanitize(soldOutErr3), 'Lo sentimos, las entradas para este sector se han agotado.');
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
