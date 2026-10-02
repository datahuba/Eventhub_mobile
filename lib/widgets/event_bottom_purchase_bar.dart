import 'package:flutter/material.dart';
import '../config/theme.dart';

class EventBottomPurchaseBar extends StatelessWidget {
  final double totalPrice;
  final bool isPast;
  final bool isSoldOut;
  final bool hasSelectedTier;
  final VoidCallback? onPurchase;

  const EventBottomPurchaseBar({
    super.key,
    required this.totalPrice,
    required this.isPast,
    required this.isSoldOut,
    required this.hasSelectedTier,
    required this.onPurchase,
  });

  bool get _isButtonDisabled => isPast || !hasSelectedTier || isSoldOut || onPurchase == null;

  String get _buttonText {
    if (isPast) return 'Evento Concluido';
    if (isSoldOut) return 'Entradas Agotadas';
    return 'Comprar Entradas';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total a pagar',
                  style: TextStyle(color: AppColors.fgMuted, fontSize: 12),
                ),
                Text(
                  'Bs. ${totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: ElevatedButton(
                onPressed: _isButtonDisabled ? null : onPurchase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.accentFg,
                  disabledBackgroundColor: AppColors.border,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                child: Text(
                  _buttonText,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
