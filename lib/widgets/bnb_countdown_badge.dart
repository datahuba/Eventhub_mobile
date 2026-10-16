import 'package:flutter/material.dart';
import '../config/theme.dart';

class BnbCountdownBadge extends StatelessWidget {
  final int secondsRemaining;
  final String formattedTime;

  const BnbCountdownBadge({
    super.key,
    required this.secondsRemaining,
    required this.formattedTime,
  });

  @override
  Widget build(BuildContext context) {
    final isUrgent = secondsRemaining < 120;

    return Center(
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
              color: isUrgent ? AppColors.error : AppColors.fgMuted,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              'Tiempo restante: $formattedTime',
              style: TextStyle(
                color: isUrgent ? AppColors.error : AppColors.fg,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
