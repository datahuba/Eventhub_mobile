import 'package:flutter/material.dart';
import '../config/theme.dart';

class EventsEmptyState extends StatelessWidget {
  final bool isPastTab;
  final bool isFiltered;
  final VoidCallback onClearFilters;

  const EventsEmptyState({
    super.key,
    required this.isPastTab,
    required this.isFiltered,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.bgSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isPastTab ? Icons.history_toggle_off : Icons.event_available_outlined,
            color: AppColors.fgLight,
            size: 56,
          ),
          const SizedBox(height: 16),
          Text(
            isPastTab
                ? 'Sin eventos pasados registrados'
                : 'No hay eventos activos en cartelera',
            style: const TextStyle(
              color: AppColors.fg,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            isPastTab
                ? 'Los eventos que ya concluyeron se archivarán automáticamente en esta sección.'
                : (isFiltered
                    ? 'Probá buscando con otros términos o restablecé los filtros aplicados.'
                    : 'Los próximos eventos programados aparecerán acá.'),
            style: const TextStyle(color: AppColors.fgMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          if (isFiltered) ...[
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onClearFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.accentFg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                elevation: 0,
              ),
              child: const Text('Restablecer Filtros'),
            ),
          ],
        ],
      ),
    );
  }
}
