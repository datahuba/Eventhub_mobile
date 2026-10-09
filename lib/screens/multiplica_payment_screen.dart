import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';
import '../models/event.dart';
import '../models/attendee.dart';
import '../models/ticket.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'payment_success_screen.dart';

class MultiplicaPaymentScreen extends StatefulWidget {
  final Event event;
  final TicketTier selectedTier;
  final int quantity;
  final String buyerName;
  final String? buyerEmail;
  final String? buyerPhone;
  final List<AttendeeInput> attendees;

  const MultiplicaPaymentScreen({
    super.key,
    required this.event,
    required this.selectedTier,
    required this.quantity,
    required this.buyerName,
    this.buyerEmail,
    this.buyerPhone,
    required this.attendees,
  });

  @override
  State<MultiplicaPaymentScreen> createState() => _MultiplicaPaymentScreenState();
}

class _MultiplicaPaymentScreenState extends State<MultiplicaPaymentScreen> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final ImagePicker _imagePicker = ImagePicker();

  Uint8List? _proofBytes;
  String? _proofFileName;
  String? _proofSizeKb;
  bool _isSubmitting = false;

  double get _totalPrice => widget.selectedTier.price * widget.quantity;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (file != null) {
        final bytes = await file.readAsBytes();
        final sizeKb = (bytes.lengthInBytes / 1024).toStringAsFixed(1);

        setState(() {
          _proofBytes = bytes;
          _proofFileName = file.name;
          _proofSizeKb = sizeKb;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar imagen: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Adjuntar Comprobante de Pago',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.fg,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.camera_alt_outlined, color: AppColors.accent),
                ),
                title: const Text('Tomar Foto con Cámara', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Capturá el recibo o pantalla bancaria'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.bgSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.photo_library_outlined, color: AppColors.fg),
                ),
                title: const Text('Elegir de Galería', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Seleccioná una captura de pantalla guardada'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copiado al portapapeles'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.fg,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submitWithProof() async {
    if (_proofBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor adjuntá el comprobante de tu transferencia.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final response = await _apiService.submitOrderWithProof(
        eventId: widget.event.id,
        buyerName: widget.buyerName,
        buyerEmail: widget.buyerEmail,
        buyerPhone: widget.buyerPhone,
        tier: widget.selectedTier.name,
        attendees: widget.attendees,
        proofBytes: _proofBytes!,
        proofFileName: _proofFileName ?? 'comprobante.jpg',
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (response.isCompleted) {
        // Auto-aprobado exitosamente por la IA
        List<IssuedTicket> issuedTickets = [];
        try {
          final orderDetails = await _apiService.getOrderDetails(response.orderId);
          final rawTickets = (orderDetails['tickets'] as List<dynamic>?) ?? [];
          for (int i = 0; i < widget.attendees.length; i++) {
            final att = widget.attendees[i];
            final raw = i < rawTickets.length ? rawTickets[i] : null;
            issuedTickets.add(
              IssuedTicket(
                id: raw != null && raw['id'] != null ? raw['id'].toString() : 'TKT-${response.orderId}-$i',
                orderId: response.orderId,
                eventTitle: widget.event.title,
                eventDate: widget.event.formattedDate,
                eventLocation: widget.event.location,
                tierName: widget.selectedTier.name,
                attendeeName: att.name,
                attendeeCi: att.ci,
                qrCode: raw != null && raw['qrCode'] != null ? raw['qrCode'].toString() : 'VALID-${response.orderId}-$i',
                imageUrl: raw != null ? raw['imageUrl']?.toString() : null,
                voucherId: response.orderId,
                purchasedAt: DateTime.now(),
                eventStartsAt: widget.event.startsAt,
              ),
            );
          }
        } catch (_) {
          issuedTickets = List.generate(
            widget.attendees.length,
            (i) => IssuedTicket(
              id: 'TKT-${response.orderId}-$i',
              orderId: response.orderId,
              eventTitle: widget.event.title,
              eventDate: widget.event.formattedDate,
              eventLocation: widget.event.location,
              tierName: widget.selectedTier.name,
              attendeeName: widget.attendees[i].name,
              attendeeCi: widget.attendees[i].ci,
              qrCode: 'VALID-${response.orderId}-$i',
              voucherId: response.orderId,
              purchasedAt: DateTime.now(),
              eventStartsAt: widget.event.startsAt,
            ),
          );
        }

        await _storageService.saveTickets(issuedTickets);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentSuccessScreen(
              event: widget.event,
              tickets: issuedTickets,
              voucherId: response.orderId,
            ),
          ),
        );
      } else {
        // En revisión manual por el organizador (PENDING)
        _showPendingDialog(response.orderId, response.message);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showPendingDialog(String orderId, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0x1FF59E0B),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_top_rounded, color: AppColors.warning, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Comprobante en Revisión',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.fg),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.isNotEmpty
                  ? message
                  : 'Tu comprobante fue recibido correctamente y enviado a verificación con el organizador.',
              style: const TextStyle(fontSize: 14, color: AppColors.fg),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.fgMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Orden: $orderId',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.fg),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Una vez confirmado por el organizador, tus entradas se activarán automáticamente en tu billetera y llegarán a tu correo.',
              style: TextStyle(fontSize: 12, color: AppColors.fgMuted),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.accentFg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Entendido / Volver al Inicio'),
          ),
        ],
      ),
    );
  }

  void _showEnlargedReceipt() {
    if (_proofBytes == null) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(_proofBytes!, fit: BoxFit.contain),
            ),
            IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final multiplicaQr = widget.event.multiplicaQrUrl;
    final beneficiary = widget.event.beneficiaryName ?? 'Organizador de Evento';
    final bank = widget.event.bankName ?? 'Banco de Crédito de Bolivia (BCP)';
    final account = widget.event.accountNumber;

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
          'Pago y Comprobante',
          style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.fg),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 1. Resumen de la orden
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
                    Expanded(
                      child: Text(
                        widget.event.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.fg),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accentSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${widget.selectedTier.name} x ${widget.quantity}',
                        style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total a Transferir:', style: TextStyle(color: AppColors.fgMuted, fontSize: 13)),
                    Row(
                      children: [
                        Text(
                          'Bs. ${_totalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _copyToClipboard(_totalPrice.toStringAsFixed(2), 'Monto'),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.bg,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Icon(Icons.copy, size: 14, color: AppColors.fgMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Tarjeta con QR Simple Multiplica y datos de transferencia
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.qr_code_2, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'QR Simple / Multiplica BCP',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Imagen QR
                if (multiplicaQr != null && multiplicaQr.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.white,
                      child: CachedNetworkImage(
                        imageUrl: multiplicaQr,
                        height: 210,
                        width: 210,
                        fit: BoxFit.contain,
                        placeholder: (ctx, _) => const SizedBox(
                          height: 210,
                          width: 210,
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        errorWidget: (ctx, _, __) => Container(
                          height: 210,
                          width: 210,
                          color: AppColors.bgSoft,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image_outlined, size: 40, color: AppColors.fgMuted),
                              SizedBox(height: 6),
                              Text('QR no disponible', style: TextStyle(color: AppColors.fgMuted, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 140,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.bgSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance, size: 36, color: AppColors.accent),
                        SizedBox(height: 8),
                        Text(
                          'Transferencia Bancaria Directa',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.fg),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Realizá la transferencia con los datos siguientes',
                          style: TextStyle(fontSize: 12, color: AppColors.fgMuted),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // Datos de la cuenta
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bgSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow('Banco', bank, null),
                      const SizedBox(height: 8),
                      _buildInfoRow('Titular', beneficiary, () => _copyToClipboard(beneficiary, 'Titular')),
                      if (account != null && account.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildInfoRow('Nº Cuenta', account, () => _copyToClipboard(account, 'Cuenta')),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Sección de Subida del Comprobante
          const Text(
            'Comprobante de Pago',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.fg),
          ),
          const SizedBox(height: 4),
          const Text(
            'Adjuntá la captura o foto del comprobante para que la IA verifique tu pago.',
            style: TextStyle(fontSize: 13, color: AppColors.fgMuted),
          ),
          const SizedBox(height: 12),

          if (_proofBytes == null)
            // Selector cuando aún no hay comprobante
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: Column(
                children: [
                  const Icon(Icons.cloud_upload_outlined, size: 38, color: AppColors.accent),
                  const SizedBox(height: 10),
                  const Text(
                    'Subí tu comprobante bancario',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.fg),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Formatos: JPG o PNG legibles',
                    style: TextStyle(fontSize: 12, color: AppColors.fgMuted),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined, size: 18),
                          label: const Text('Cámara'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.fg,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined, size: 18),
                          label: const Text('Galería'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentSoft,
                            foregroundColor: AppColors.accent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            // Vista previa cuando ya se eligió el comprobante
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.success, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Miniatura
                  GestureDetector(
                    onTap: _showEnlargedReceipt,
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            _proofBytes!,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.zoom_in, color: Colors.white, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.successBg,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '✓ Comprobante listo',
                                style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _proofFileName ?? 'comprobante.jpg',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.fg),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_proofSizeKb != null)
                          Text(
                            '$_proofSizeKb KB',
                            style: const TextStyle(fontSize: 11, color: AppColors.fgMuted),
                          ),
                      ],
                    ),
                  ),

                  // Botón cambiar
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppColors.fgMuted, size: 20),
                    tooltip: 'Cambiar comprobante',
                    onPressed: _showImageSourcePicker,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                    tooltip: 'Eliminar',
                    onPressed: () {
                      setState(() {
                        _proofBytes = null;
                        _proofFileName = null;
                        _proofSizeKb = null;
                      });
                    },
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // 4. Banner explicativo del Agente de IA Antifraude
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome, color: Color(0xFF16A34A), size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Auditoría con IA: El comprobante se analizará automáticamente para validar monto, número de operación y autenticidad.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF166534), height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 5. Botón de Confirmación y Auditoría con IA
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submitWithProof,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.accentFg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Auditando con Agente de IA...',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  )
                : Text(
                    'Confirmar y Auditar Pago (Bs. ${_totalPrice.toStringAsFixed(2)})',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, VoidCallback? onCopy) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.fgMuted)),
        Row(
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.fg),
            ),
            if (onCopy != null) ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: onCopy,
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.all(2.0),
                  child: Icon(Icons.copy, size: 14, color: AppColors.fgMuted),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
