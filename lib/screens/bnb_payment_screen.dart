import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/event.dart';
import '../models/order.dart';
import '../models/attendee.dart';
import '../models/ticket.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'payment_success_screen.dart';

class BnbPaymentScreen extends StatefulWidget {
  final Event event;
  final TicketTier selectedTier;
  final BnbQrResponse bnbResponse;
  final List<AttendeeInput> attendees;

  const BnbPaymentScreen({
    super.key,
    required this.event,
    required this.selectedTier,
    required this.bnbResponse,
    required this.attendees,
  });

  @override
  State<BnbPaymentScreen> createState() => _BnbPaymentScreenState();
}

class _BnbPaymentScreenState extends State<BnbPaymentScreen> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();

  Uint8List? _qrBytes;
  bool _isChecking = false;
  Timer? _pollingTimer;
  Timer? _countdownTimer;
  int _secondsRemaining = 15 * 60; // 15 minutos de vigencia

  @override
  void initState() {
    super.initState();
    _decodeQrBase64();
    _startCountdown();
    _startAutoPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _decodeQrBase64() {
    try {
      String cleanBase64 = widget.bnbResponse.qrBase64.trim();
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',').last;
      }
      setState(() {
        _qrBytes = base64Decode(cleanBase64);
      });
    } catch (e) {
      debugPrint('Error al decodificar Base64 de QR BNB: $e');
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  void _startAutoPolling() {
    // Sondeo suave cada 4 segundos
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      _verifyPayment(isManual: false);
    });
  }

  String get _formattedTimeRemaining {
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _verifyPayment({bool isManual = true}) async {
    if (_isChecking) return;

    if (isManual) {
      setState(() => _isChecking = true);
    }

    try {
      final statusResp = await _apiService.checkBnbStatus(
        orderId: widget.bnbResponse.orderId,
        qrId: widget.bnbResponse.qrId,
      );

      if (statusResp.status == PaymentVerificationStatus.completed) {
        _pollingTimer?.cancel();
        _countdownTimer?.cancel();

        // Convertir la respuesta a objetos IssuedTicket
        final List<IssuedTicket> issuedTickets = [];
        final attendeesRaw = statusResp.attendeesRaw ?? [];

        for (int i = 0; i < widget.attendees.length; i++) {
          final attInput = widget.attendees[i];
          final raw = i < attendeesRaw.length ? attendeesRaw[i] : null;

          issuedTickets.add(
            IssuedTicket(
              id: raw != null && raw['id'] != null ? raw['id'].toString() : 'TKT-${DateTime.now().millisecondsSinceEpoch}-$i',
              orderId: widget.bnbResponse.orderId,
              eventTitle: widget.event.title,
              eventDate: widget.event.formattedDate,
              eventLocation: widget.event.location,
              tierName: widget.selectedTier.name,
              attendeeName: attInput.name,
              attendeeCi: attInput.ci,
              qrCode: raw != null && (raw['productP'] != null || raw['qrCode'] != null)
                  ? (raw['productP'] ?? raw['qrCode']).toString()
                  : 'VALID-${widget.bnbResponse.orderId}-$i',
              imageUrl: raw != null ? raw['imageUrl']?.toString() : null,
              voucherId: statusResp.voucherId,
              purchasedAt: DateTime.now(),
            ),
          );
        }

        // Guardar automáticamente en la billetera local del teléfono (cero login)
        await _storageService.saveTickets(issuedTickets);

        if (!mounted) return;

        // Navegar a la pantalla de confirmación y tickets
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentSuccessScreen(
              event: widget.event,
              tickets: issuedTickets,
              voucherId: statusResp.voucherId,
            ),
          ),
        );
      } else if (statusResp.status == PaymentVerificationStatus.expired) {
        _pollingTimer?.cancel();
        _countdownTimer?.cancel();
        if (isManual && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('El código QR ha expirado en el banco. Generá una nueva orden.'),
              backgroundColor: Colors.orangeAccent,
            ),
          );
        }
      } else {
        // PENDING
        if (isManual && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aún no detectamos la transferencia en el banco. Si ya pagaste, esperá unos segundos.'),
              backgroundColor: Colors.white24,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (isManual && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al consultar: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (isManual && mounted) {
        setState(() => _isChecking = false);
      }
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
          'Pago con QR Simple BNB',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Banner explicativo
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2A1A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, color: Colors.greenAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pago seguro acreditado directamente por la Red BNB / Banco Central',
                    style: TextStyle(color: Colors.greenAccent.shade100, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Monto a Pagar
          Center(
            child: Column(
              children: [
                const Text('Monto total a transferir', style: TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  'Bs. ${widget.bnbResponse.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFFEC3013),
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${widget.bnbResponse.eventTitle} • ${widget.selectedTier.name} (${widget.attendees.length} entrada${widget.attendees.length > 1 ? 's' : ''})',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Contenedor blanco con el Código QR Simple de BNB
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  if (_qrBytes != null)
                    Image.memory(
                      _qrBytes!,
                      width: 240,
                      height: 240,
                      fit: BoxFit.contain,
                    )
                  else
                    const SizedBox(
                      width: 240,
                      height: 240,
                      child: Center(
                        child: CircularProgressIndicator(color: Color(0xFFEC3013)),
                      ),
                    ),
                  const SizedBox(height: 10),
                  const Text(
                    'Escaneá con cualquier app bancaria',
                    style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Contador de expiración
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer_outlined, color: Colors.white54, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Tiempo restante: $_formattedTimeRemaining',
                  style: TextStyle(
                    color: _secondsRemaining < 120 ? Colors.redAccent : Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // Botón Principal: "Ya realicé el pago"
          ElevatedButton(
            onPressed: _isChecking ? null : () => _verifyPayment(isManual: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEC3013),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.white12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
            ),
            child: _isChecking
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Verificando con el banco...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Ya realicé el pago',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),

          // Texto informativo de sondeo automático
          const Center(
            child: Text(
              'La aplicación verifica automáticamente cada 4 segundos.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
