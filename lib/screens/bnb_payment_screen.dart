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
  final ApiService? apiService;
  final StorageService? storageService;
  final int? initialSecondsRemaining;

  const BnbPaymentScreen({
    super.key,
    required this.event,
    required this.selectedTier,
    required this.bnbResponse,
    required this.attendees,
    this.apiService,
    this.storageService,
    this.initialSecondsRemaining,
  });

  @override
  State<BnbPaymentScreen> createState() => _BnbPaymentScreenState();
}

class _BnbPaymentScreenState extends State<BnbPaymentScreen> {
  late final ApiService _apiService;
  late final StorageService _storageService;

  Uint8List? _qrBytes;
  bool _isChecking = false;
  bool _isExpired = false;
  Timer? _pollingTimer;
  Timer? _countdownTimer;
  late int _secondsRemaining;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _storageService = widget.storageService ?? StorageService();
    _secondsRemaining = widget.initialSecondsRemaining ?? (15 * 60);
    _decodeQrBase64();
    if (_secondsRemaining <= 0) {
      _isExpired = true;
    } else {
      _startCountdown();
    }
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
      final decoded = base64Decode(cleanBase64);
      if (mounted) {
        setState(() {
          _qrBytes = decoded;
        });
      } else {
        _qrBytes = decoded;
      }
    } catch (e) {
      debugPrint('Error al decodificar Base64 de QR BNB: $e');
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
        if (_secondsRemaining <= 0) {
          _handleExpired();
        }
      } else {
        _handleExpired();
      }
    });
  }

  void _handleExpired() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (mounted && !_isExpired) {
      setState(() {
        _isExpired = true;
      });
    }
  }

  void _startAutoPolling() {
    // Sondeo suave cada 4 segundos
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_secondsRemaining <= 0 || _qrBytes == null || _isExpired) {
        return;
      }
      _verifyPayment(isManual: false);
    });
  }

  String get _formattedTimeRemaining {
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _verifyPayment({bool isManual = true}) async {
    if (_isChecking || _isExpired) return;

    _isChecking = true;
    if (isManual && mounted) {
      setState(() {});
    }

    try {
      final statusResp = await _apiService.checkBnbStatus(
        orderId: widget.bnbResponse.orderId,
        qrId: widget.bnbResponse.qrId,
      );

      if (statusResp.status == PaymentVerificationStatus.completed) {
        final attendeesRaw = statusResp.attendeesRaw;
        bool isIncomplete = false;

        if (attendeesRaw == null || attendeesRaw.length < widget.attendees.length) {
          isIncomplete = true;
        } else {
          for (int i = 0; i < widget.attendees.length; i++) {
            final raw = attendeesRaw[i];
            if (raw == null || raw is! Map<String, dynamic>) {
              isIncomplete = true;
              break;
            }
            final id = raw['id']?.toString().trim();
            final qrCode = (raw['productP'] ?? raw['qrCode'])?.toString().trim();
            if (id == null || id.isEmpty || qrCode == null || qrCode.isEmpty || id.startsWith('TKT-') || qrCode.startsWith('VALID-')) {
              isIncomplete = true;
              break;
            }
          }
        }

        if (isIncomplete || attendeesRaw == null) {
          _pollingTimer?.cancel();
          _pollingTimer = null;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'El pago fue acreditado pero las entradas aún se están procesando (Orden: ${widget.bnbResponse.orderId}). Por favor reintentá en unos momentos o contactá a soporte.',
                ),
                backgroundColor: AppColors.error,
                duration: const Duration(seconds: 6),
              ),
            );
          }
          return;
        }

        _pollingTimer?.cancel();
        _pollingTimer = null;
        _countdownTimer?.cancel();
        _countdownTimer = null;

        // Convertir la respuesta a objetos IssuedTicket legítimos y firmados
        final List<IssuedTicket> issuedTickets = [];

        for (int i = 0; i < widget.attendees.length; i++) {
          final attInput = widget.attendees[i];
          final raw = attendeesRaw[i] as Map<String, dynamic>;
          final ticketId = raw['id'].toString().trim();
          final qrCode = (raw['productP'] ?? raw['qrCode']).toString().trim();

          issuedTickets.add(
            IssuedTicket(
              id: ticketId,
              orderId: widget.bnbResponse.orderId,
              eventTitle: widget.event.title,
              eventDate: widget.event.formattedDate,
              eventLocation: widget.event.location,
              tierName: widget.selectedTier.name,
              attendeeName: attInput.name,
              attendeeCi: attInput.ci,
              qrCode: qrCode,
              imageUrl: raw['imageUrl']?.toString(),
              voucherId: statusResp.voucherId,
              purchasedAt: DateTime.now(),
              eventStartsAt: widget.event.startsAt,
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
        _pollingTimer = null;
        _countdownTimer?.cancel();
        _countdownTimer = null;
        if (mounted) {
          setState(() {
            _isExpired = true;
          });
        }
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
      _isChecking = false;
      if (isManual && mounted) {
        setState(() {});
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
        title: Text(
          _isExpired ? 'Orden Expirada' : 'Pago con QR Simple BNB',
          style: const TextStyle(color: AppColors.fg, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.fg),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isExpired ? _buildExpiredView() : _buildActiveQrView(),
    );
  }

  Widget _buildExpiredView() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.errorBg,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.error.withValues(alpha: 0.2), width: 2),
            ),
            child: const Icon(
              Icons.timer_off_outlined,
              color: AppColors.error,
              size: 40,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Center(
          child: Text(
            'Código QR Vencido',
            style: TextStyle(
              color: AppColors.fg,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'El tiempo límite de 15 minutos para concretar la transferencia ha expirado. Por seguridad bancaria y reserva de entradas, este código QR ya no es válido.',
            style: TextStyle(
              color: AppColors.fgMuted,
              fontSize: 14,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 28),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Orden', style: TextStyle(color: AppColors.fgMuted, fontSize: 13)),
                  Text(
                    widget.bnbResponse.orderId,
                    style: const TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ),
              const Divider(height: 16, color: AppColors.border),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Evento', style: TextStyle(color: AppColors.fgMuted, fontSize: 13)),
                  Expanded(
                    child: Text(
                      widget.bnbResponse.eventTitle,
                      style: const TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600, fontSize: 13),
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Divider(height: 16, color: AppColors.border),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Monto total', style: TextStyle(color: AppColors.fgMuted, fontSize: 13)),
                  Text(
                    'Bs. ${widget.bnbResponse.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(color: AppColors.fg, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              const Divider(height: 16, color: AppColors.border),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Estado', style: TextStyle(color: AppColors.fgMuted, fontSize: 13)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.errorBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'EXPIRADO',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          key: const Key('expired_back_button'),
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.accentFg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: 0,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_back, size: 20),
              SizedBox(width: 8),
              Text(
                'Volver a generar orden',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveQrView() {
    return ListView(
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
    );
  }
}

