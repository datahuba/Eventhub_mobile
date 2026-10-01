import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../config/theme.dart';
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
              backgroundColor: AppColors.warning,
            ),
          );
        }
      } else {
        // PENDING
        if (isManual && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aún no detectamos la transferencia en el banco. Si ya pagaste, esperá unos segundos.'),
              backgroundColor: AppColors.fg,
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
            backgroundColor: AppColors.error,
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
          'Pago con QR Simple BNB',
          style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.fg),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Banner explicativo seguro
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.successBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, color: AppColors.success, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pago seguro acreditado directamente por la Red BNB / Banco Central',
                    style: TextStyle(
                      color: AppColors.success.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
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
                const Text('Monto total a transferir', style: TextStyle(color: AppColors.fgMuted, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  'Bs. ${widget.bnbResponse.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.bnbResponse.eventTitle} • ${widget.selectedTier.name} (${widget.attendees.length} entrada${widget.attendees.length > 1 ? 's' : ''})',
                  style: const TextStyle(color: AppColors.fgMuted, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Contenedor con el Código QR Simple de BNB
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0C000000),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  if (_qrBytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _qrBytes!,
                        width: 240,
                        height: 240,
                        fit: BoxFit.contain,
                      ),
                    )
                  else
                    const SizedBox(
                      width: 240,
                      height: 240,
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.accent),
                      ),
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    'Escaneá con cualquier app bancaria',
                    style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Contador de expiración
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.bgSoft,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    color: _secondsRemaining < 120 ? AppColors.error : AppColors.fgMuted,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Tiempo restante: $_formattedTimeRemaining',
                    style: TextStyle(
                      color: _secondsRemaining < 120 ? AppColors.error : AppColors.fg,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Botón Principal: "Ya realicé el pago"
          ElevatedButton(
            onPressed: _isChecking ? null : () => _verifyPayment(isManual: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.accentFg,
              disabledBackgroundColor: AppColors.border,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                      Icon(Icons.check_circle_outline, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Ya realicé el pago',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),

          // Texto informativo de sondeo automático
          const Center(
            child: Text(
              'La aplicación verifica automáticamente cada 4 segundos.',
              style: TextStyle(color: AppColors.fgMuted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
