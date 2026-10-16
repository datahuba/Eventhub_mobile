import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/order.dart';

class BnbExpiredView extends StatelessWidget {
  final BnbQrResponse bnbResponse;
  final VoidCallback onBack;

  const BnbExpiredView({
    super.key,
    required this.bnbResponse,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
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
                    bnbResponse.orderId,
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
                      bnbResponse.eventTitle,
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
                    'Bs. ${bnbResponse.totalAmount.toStringAsFixed(2)}',
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
          onPressed: onBack,
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
}
