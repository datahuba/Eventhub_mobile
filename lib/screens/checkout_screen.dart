import 'package:flutter/material.dart';
import '../models/event.dart';
import '../models/attendee.dart';
import '../services/api_service.dart';
import 'bnb_payment_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final Event event;
  final TicketTier selectedTier;
  final int quantity;

  const CheckoutScreen({
    super.key,
    required this.event,
    required this.selectedTier,
    required this.quantity,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

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
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString().replaceAll("Exception: ", "")}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181818),
        elevation: 0,
        title: const Text(
          'Registro de Entradas',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
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
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2C2C2C)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.event.title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${widget.selectedTier.name} x ${widget.quantity}',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      Text(
                        'Bs. ${_totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xFFEC3013),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _buyerNameController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Nombre y Apellido completo *', Icons.person_outline),
              validator: (val) => (val == null || val.trim().isEmpty) ? 'Ingresá tu nombre completo' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _buyerPhoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Celular / WhatsApp (opcional)', Icons.phone_outlined),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _buyerEmailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Correo electrónico (opcional)', Icons.email_outlined),
            ),
            const SizedBox(height: 28),

            // Sección 2: Asistentes Nominales
            const Text(
              'Titulares de las Entradas',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'El Carnet de Identidad (C.I.) es requerido para la validación en puerta.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),

            ...List.generate(widget.quantity, (index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF181818),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF282828)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEC3013).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Entrada ${index + 1}',
                            style: const TextStyle(color: Color(0xFFEC3013), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.selectedTier.name,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _attendeeNameControllers[index],
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Nombre del Asistente *', Icons.badge_outlined),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Ingresá el nombre' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _attendeeCiControllers[index],
                      keyboardType: TextInputType.text,
                      style: const TextStyle(color: Colors.white),
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
                backgroundColor: const Color(0xFFEC3013),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      'Pagar con QR Simple BNB (Bs. ${_totalPrice.toStringAsFixed(2)})',
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
      labelStyle: const TextStyle(color: Colors.white54, fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.white38, size: 20),
      filled: true,
      fillColor: const Color(0xFF222222),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF333333)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF333333)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFEC3013), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
