import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show SocketException;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/theme.dart';
import '../models/event.dart';
import '../models/attendee.dart';
import '../services/api_service.dart';
import 'bnb_payment_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final Event event;
  final TicketTier selectedTier;
  final int quantity;
  final ApiService? apiService;
  final void Function(String maskedError, StackTrace stackTrace)? onDebugErrorLog;

  const CheckoutScreen({
    super.key,
    required this.event,
    required this.selectedTier,
    required this.quantity,
    this.apiService,
    this.onDebugErrorLog,
  });

  /// Allowlist explícita de códigos de negocio devueltos por el backend.
  static const Map<String, String> _allowedErrorCodes = {
    'INVALID_ATTENDEE_CI': 'El C.I. ingresado no es válido',
    'INVALID_CI': 'El C.I. ingresado no es válido',
    'SECTOR_SOLD_OUT': 'Cupo agotado para este sector',
    'TIER_SOLD_OUT': 'Cupo agotado para este sector',
    'OUT_OF_STOCK': 'Cupo agotado para este sector',
    'INSUFFICIENT_CAPACITY': 'Cupo agotado para este sector',
    'EVENT_NOT_FOUND': 'El evento seleccionado ya no está disponible',
    'EVENT_ENDED': 'Este evento ya finalizó',
    'INVALID_TIER': 'El sector seleccionado no es válido',
    'VALIDATION_ERROR': 'Datos inválidos',
    'UNAUTHORIZED': 'No autorizado',
    'FORBIDDEN': 'No autorizado',
  };

  /// Allowlist explícita de mensajes de negocio permitidos en pantalla.
  static const Map<String, String> _allowedBusinessMessages = {
    'el c.i. ingresado no es válido': 'El C.I. ingresado no es válido',
    'cupo agotado para este sector': 'Cupo agotado para este sector',
    'no quedan entradas disponibles para este sector': 'No quedan entradas disponibles para este sector',
    'las entradas para este sector están agotadas': 'Cupo agotado para este sector',
    'el evento seleccionado ya no está disponible': 'El evento seleccionado ya no está disponible',
    'este evento ya finalizó': 'Este evento ya finalizó',
    'el sector seleccionado no es válido': 'El sector seleccionado no es válido',
    'debes ingresar al menos un asistente': 'Debes ingresar al menos un asistente',
    'datos inválidos': 'Datos inválidos',
    'no autorizado': 'No autorizado',
  };

  /// Convierte excepciones técnicas en mensajes seguros y comprensibles para el usuario.
  static String sanitizeErrorMessage(Object error) {
    if (error is SocketException || error is http.ClientException) {
      return 'Sin conexión. Verificá tu internet e intentá de nuevo.';
    }
    if (error is TimeoutException) {
      return 'La operación tardó demasiado. Intentá de nuevo.';
    }
    if (error is ApiHttpException) {
      if (error.statusCode >= 500) {
        return 'Error del servidor, intentá más tarde.';
      }
      if (error.statusCode >= 400 && error.statusCode < 500) {
        final codeKey = error.errorCode?.trim().toUpperCase();
        if (codeKey != null && _allowedErrorCodes.containsKey(codeKey)) {
          return _allowedErrorCodes[codeKey]!;
        }
        final msgKey = error.serverMessage?.trim().toLowerCase();
        if (msgKey != null && _allowedBusinessMessages.containsKey(msgKey)) {
          return _allowedBusinessMessages[msgKey]!;
        }
        return switch (error.statusCode) {
          400 || 422 => 'Datos inválidos',
          403 => 'No autorizado',
          409 => 'Cupo agotado para este sector',
          _ => 'No se pudo procesar la solicitud. Intentá de nuevo.',
        };
      }
    }
    return 'Ocurrió un error inesperado. Intentá de nuevo.';
  }

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  late final ApiService _apiService;

  // Datos del Comprador
  final TextEditingController _buyerNameController = TextEditingController();
  final TextEditingController _buyerEmailController = TextEditingController();
  final TextEditingController _buyerPhoneController = TextEditingController();

  // Lista de Asistentes
  late List<AttendeeInput> _attendees;
  late List<TextEditingController> _attendeeNameControllers;
  late List<TextEditingController> _attendeeCiControllers;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _attendees = List.generate(widget.quantity, (_) => AttendeeInput.empty());
    _attendeeNameControllers = List.generate(widget.quantity, (_) => TextEditingController());
    _attendeeCiControllers = List.generate(widget.quantity, (_) => TextEditingController());
  }

  @override
  void dispose() {
    _buyerNameController.dispose();
    _buyerEmailController.dispose();
    _buyerPhoneController.dispose();
    for (var c in _attendeeNameControllers) {
      c.dispose();
    }
    for (var c in _attendeeCiControllers) {
      c.dispose();
    }
    super.dispose();
  }

  double get _totalPrice => widget.selectedTier.price * widget.quantity;

  Future<void> _submitOrder() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    // Sincronizar controladores con la lista de asistentes
    for (int i = 0; i < widget.quantity; i++) {
      _attendees[i].name = _attendeeNameControllers[i].text.trim();
      _attendees[i].ci = _attendeeCiControllers[i].text.trim();
    }

    try {
      final bnbResponse = await _apiService.generateBnbQr(
        eventId: widget.event.id,
        buyerName: _buyerNameController.text.trim(),
        buyerEmail: _buyerEmailController.text.trim(),
        buyerPhone: _buyerPhoneController.text.trim(),
        tier: widget.selectedTier.name,
        attendees: _attendees,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      // Navegar a la pantalla de pago BNB con el QR generado
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BnbPaymentScreen(
            event: widget.event,
            selectedTier: widget.selectedTier,
            bnbResponse: bnbResponse,
            attendees: _attendees,
          ),
        ),
      );
    } catch (e, st) {
      _logCheckoutError(e, st);
      if (!mounted) return;
      setState(() => _isLoading = false);

      final userMessage = CheckoutScreen.sanitizeErrorMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userMessage),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _logCheckoutError(Object error, StackTrace stackTrace) {
    if (!kDebugMode) return;
    final maskedError = maskSensitiveData(error.toString());
    widget.onDebugErrorLog?.call(maskedError, stackTrace);
    developer.log(
      'Error en CheckoutScreen._submitOrder: $maskedError',
      name: 'CheckoutScreen',
      error: maskedError,
      stackTrace: stackTrace,
    );
    debugPrint('CheckoutScreen._submitOrder error: $maskedError\n$stackTrace');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
        title: const Text(
          'Registro de Entradas',
          style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.fg),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Resumen de la Orden
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.event.title,
                    style: const TextStyle(color: AppColors.fg, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${widget.selectedTier.name} x ${widget.quantity}',
                        style: const TextStyle(color: AppColors.fgMuted, fontSize: 14),
                      ),
                      Text(
                        'Bs. ${_totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Sección 1: Datos del Comprador
            const Text(
              'Datos del Comprador',
              style: TextStyle(color: AppColors.fg, fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _buyerNameController,
              style: const TextStyle(color: AppColors.fg),
              decoration: _inputDecoration('Nombre y Apellido completo *', Icons.person_outline),
              validator: (val) => (val == null || val.trim().isEmpty) ? 'Ingresá tu nombre completo' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _buyerPhoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: AppColors.fg),
              decoration: _inputDecoration('Celular / WhatsApp (opcional)', Icons.phone_outlined),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _buyerEmailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: AppColors.fg),
              decoration: _inputDecoration('Correo electrónico (opcional)', Icons.email_outlined),
            ),
            const SizedBox(height: 28),

            // Sección 2: Asistentes Nominales
            const Text(
              'Titulares de las Entradas',
              style: TextStyle(color: AppColors.fg, fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'El Carnet de Identidad (C.I.) es requerido para la validación en puerta.',
              style: TextStyle(color: AppColors.fgMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),

            ...List.generate(widget.quantity, (index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.accentSoft,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Entrada ${index + 1}',
                            style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.selectedTier.name,
                          style: const TextStyle(color: AppColors.fgMuted, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _attendeeNameControllers[index],
                      style: const TextStyle(color: AppColors.fg),
                      decoration: _inputDecoration('Nombre del Asistente *', Icons.badge_outlined),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Ingresá el nombre' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _attendeeCiControllers[index],
                      keyboardType: TextInputType.text,
                      style: const TextStyle(color: AppColors.fg),
                      decoration: _inputDecoration('C.I. / Documento de Identidad *', Icons.credit_card_outlined),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Ingresá el C.I.' : null,
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 20),

            // Botón de generación de pago
            ElevatedButton(
              onPressed: _isLoading ? null : _submitOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.accentFg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : Text(
                      'Pagar con QR Simple (Bs. ${_totalPrice.toStringAsFixed(2)})',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      labelText: hint,
      labelStyle: const TextStyle(color: AppColors.fgMuted, fontSize: 14),
      prefixIcon: Icon(icon, color: AppColors.fgMuted, size: 20),
      filled: true,
      fillColor: AppColors.bgSoft,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
