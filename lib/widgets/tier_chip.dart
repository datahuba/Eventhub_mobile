import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/event.dart';

class TierSelectorChip extends StatelessWidget {
  final TicketTier tier;
  final bool isSelected;
  final VoidCallback onTap;

  const TierSelectorChip({
    super.key,
    required this.tier,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasCapacity = tier.capacity != null;
    final isExhausted = hasCapacity && tier.capacity! <= 0;

    return GestureDetector(
      onTap: isExhausted ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentSoft
              : (isExhausted ? AppColors.bgSoft.withValues(alpha: 0.6) : AppColors.bg),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.accent
                : (isExhausted ? AppColors.border.withValues(alpha: 0.5) : AppColors.border),
            width: isSelected ? 1.6 : 1,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Indicador de selección (radio button estilo limpio)
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.accent
                      : (isExhausted ? AppColors.fgLight : AppColors.borderDark),
                  width: 2,
                ),
                color: isSelected ? AppColors.accent : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),

            // Nombre y capacidad disponible
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tier.name,
                    style: TextStyle(
                      color: isExhausted ? AppColors.fgLight : AppColors.fg,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (hasCapacity) ...[
                    const SizedBox(height: 2),
                    Text(
                      isExhausted ? 'Agotado' : '${tier.capacity} entradas disponibles',
                      style: TextStyle(
                        color: isExhausted ? AppColors.error : AppColors.fgMuted,
                        fontSize: 12,
                        fontWeight: isExhausted ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Precio
            Text(
              'Bs. ${tier.price.toStringAsFixed(2)}',
              style: TextStyle(
                color: isSelected
                    ? AppColors.accent
                    : (isExhausted ? AppColors.fgLight : AppColors.fg),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
