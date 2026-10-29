enum ErrorContext {
  general,
  events,
  payments,
}

/// Utilidad centralizada para sanitizar errores técnicos, excepciones de red y mensajes de proveedores
/// garantizando que nunca se expongan detalles técnicos, URLs, IPs, stack traces o códigos internos al usuario.
class ErrorSanitizer {
  /// Transforma cualquier error o excepción a un mensaje seguro, amigable y en español neutral.
  /// Permite especificar el contexto (general, eventos, pagos) para evitar mensajes engañosos.
  static String sanitize(dynamic error, {ErrorContext context = ErrorContext.general}) {
    if (error == null) {
      return 'Ocurrió un problema inesperado. Por favor intentá nuevamente.';
    }

    final raw = error.toString().toLowerCase();

    // 1. Entradas agotadas / Aforo alcanzado / Capacidad 0
    if (raw.contains('agotad') ||
        raw.contains('cupo') ||
        raw.contains('capacidad') ||
        raw.contains('sold out') ||
        raw.contains('sin entradas')) {
      return 'Lo sentimos, las entradas para este sector se han agotado.';
    }

    // 2. Alta demanda o colisión de concurrencia
    if (raw.contains('demanda') ||
        raw.contains('conflict') ||
        raw.contains('reintent') ||
        raw.contains('intentá de nuevo') ||
        raw.contains('serializ')) {
      return 'Hay alta demanda en este momento. Por favor intentá de nuevo en unos segundos.';
    }

    // 3. Timeouts de red o proveedor (cuando no es un error 500 del servidor)
    if ((raw.contains('timeoutexception') ||
            raw.contains('timed out') ||
            raw.contains('timeout') ||
            raw.contains('tardó demasiado') ||
            raw.contains('tiempo de espera')) &&
        !raw.contains('500') &&
        !raw.contains('internal server error')) {
      return 'El servidor tardó demasiado en responder. Por favor revisá tu conexión e intentá de nuevo.';
    }

    // 4. Errores de conexión / Socket / DNS / HTTP Client
    if (raw.contains('socketexception') ||
        raw.contains('clientexception') ||
        raw.contains('connection refused') ||
        raw.contains('failed host lookup') ||
        raw.contains('network is unreachable') ||
        raw.contains('network') ||
        raw.contains('conexión') ||
        raw.contains('sin conexión') ||
        raw.contains('no pudimos conectar')) {
      return 'No pudimos conectar con el servidor. Por favor revisá tu conexión a internet.';
    }

    // 5. Formato JSON / Respuestas corruptas / HTML de proxies 502/504
    if (raw.contains('formatexception') ||
        raw.contains('syntaxerror') ||
        raw.contains('json') ||
        raw.contains('xml') ||
        raw.contains('doctype') ||
        raw.contains('bad gateway') ||
        raw.contains('gateway timeout') ||
        raw.contains('formato')) {
      return 'Respuesta inesperada del servidor. Por favor intentá nuevamente más tarde.';
    }

    // 6. Errores de pasarela / Servidor 5xx / Servicio no disponible
    if (raw.contains('pasarela') ||
        raw.contains('500') ||
        raw.contains('502') ||
        raw.contains('503') ||
        raw.contains('504') ||
        raw.contains('servidor') ||
        raw.contains('no está disponible') ||
        raw.contains('verificación') ||
        raw.contains('internal server error')) {
      if (context == ErrorContext.events || raw.contains('evento') || raw.contains('cartelera')) {
        return 'El servicio de eventos no está disponible temporalmente. Por favor intentá en unos instantes.';
      }
      if (context == ErrorContext.payments || raw.contains('pago') || raw.contains('qr') || raw.contains('banco') || raw.contains('verificación')) {
        return 'El servicio de pagos no está disponible temporalmente. Por favor intentá en unos minutos.';
      }
      return 'El servicio no está disponible temporalmente. Por favor intentá en unos instantes.';
    }

    // 7. Validaciones específicas de reglas de negocio
    if (raw.contains('10 entradas') || raw.contains('límite máximo')) {
      return 'No se pueden comprar más de 10 entradas por orden.';
    }
    if (raw.contains('concluido') || raw.contains('finalizado') || raw.contains('evento pasado')) {
      return 'Este evento ya ha concluido. No se pueden adquirir más entradas.';
    }
    if (raw.contains('expirad') || raw.contains('expired')) {
      return 'El código QR ha expirado. Por favor generá una nueva orden.';
    }

    // 8. Fallback estricto de seguridad: NUNCA devolver el error crudo
    if (context == ErrorContext.events) {
      return 'No se pudieron cargar los eventos. Por favor intentá nuevamente.';
    }
    return 'No se pudo completar la operación. Por favor intentá nuevamente.';
  }

  /// Método específico para sanitizar errores al consultar o listar eventos
  static String sanitizeEvents(dynamic error) => sanitize(error, context: ErrorContext.events);

  /// Método específico para sanitizar errores en flujos de pago o verificación
  static String sanitizePayment(dynamic error) => sanitize(error, context: ErrorContext.payments);
}
