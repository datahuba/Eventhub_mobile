import 'package:flutter/material.dart';
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
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFEC3013).withOpacity(0.12)
              : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFEC3013)
                : (isExhausted ? Colors.white12 : const Color(0xFF333333)),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            // Indicador de selección
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFFEC3013) : Colors.white38,
                  width: 2,
                ),
                color: isSelected ? const Color(0xFFEC3013) : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),

            // Nombre y capacidad
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tier.name,
                    style: TextStyle(
                      color: isExhausted ? Colors.white38 : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (hasCapacity) ...[
                    const SizedBox(height: 3),
                    Text(
                      isExhausted ? 'Agotado' : '${tier.capacity} cupos disponibles',
                      style: TextStyle(
                        color: isExhausted ? Colors.redAccent : Colors.white54,
                        fontSize: 12,
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
                color: isSelected ? const Color(0xFFEC3013) : Colors.white,
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
