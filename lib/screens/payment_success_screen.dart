import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/event.dart';
import '../models/ticket.dart';
import 'tickets_screen.dart';

class PaymentSuccessScreen extends StatelessWidget {
  final Event event;
  final List<IssuedTicket> tickets;
  final String? voucherId;

  const PaymentSuccessScreen({
    super.key,
    required this.event,
    required this.tickets,
    this.voucherId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),

              // Icono de éxito
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.successBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.success, width: 2),
                ),
                child: const Icon(Icons.check, color: AppColors.success, size: 50),
              ),
              const SizedBox(height: 24),

              const Text(
                '¡Pago Acreditado!',
                style: TextStyle(
                  color: AppColors.fg,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tus entradas han sido generadas y guardadas automáticamente en tu teléfono.',
                style: TextStyle(color: AppColors.fgMuted, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              // Tarjeta informativa del pedido
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.bgSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        color: AppColors.fg,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: AppColors.border, height: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Entradas generadas:', style: TextStyle(color: AppColors.fgMuted, fontSize: 13)),
                        Text(
                          '${tickets.length} ticket${tickets.length > 1 ? 's' : ''}',
                          style: const TextStyle(color: AppColors.fg, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Sector:', style: TextStyle(color: AppColors.fgMuted, fontSize: 13)),
                        Text(
                          tickets.isNotEmpty ? tickets.first.tierName : 'General',
                          style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (voucherId != null && voucherId!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Voucher BNB:', style: TextStyle(color: AppColors.fgMuted, fontSize: 13)),
                          Text(
                            voucherId!,
                            style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const Spacer(),

              // Botón "Ver mis entradas"
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const TicketsScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.accentFg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.confirmation_number_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Ver mis entradas ahora', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Botón "Volver al catálogo"
              TextButton(
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: const Text('Volver al catálogo', style: TextStyle(color: AppColors.fgMuted, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
