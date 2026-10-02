import 'package:flutter/material.dart';
import '../config/theme.dart';

class EventsEmptyState extends StatelessWidget {
  final int selectedTab;
  final bool isFiltered;
  final VoidCallback onClearFilters;

  const EventsEmptyState({
    super.key,
    required this.selectedTab,
    required this.isFiltered,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    String title;
    String description;

    switch (selectedTab) {
      case 1:
        icon = Icons.history_toggle_off;
        title = 'Sin eventos concluidos';
        description = 'Los eventos que ya finalizaron se archivarán automáticamente en esta sección.';
        break;
      case 2:
        icon = Icons.confirmation_number_outlined;
        title = 'No hay eventos agotados';
        description = 'Los eventos que hayan vendido todas sus entradas aparecerán acá.';
        break;
      case 3:
        icon = Icons.event_busy_outlined;
        title = 'No se encontraron eventos';
        description = isFiltered
            ? 'Probá buscando con otros términos o restablecé los filtros aplicados.'
            : 'No hay eventos registrados en el catálogo.';
        break;
      case 0:
      default:
        icon = Icons.event_available_outlined;
        title = 'No hay eventos activos en cartelera';
        description = isFiltered
            ? 'Probá buscando con otros términos o restablecé los filtros aplicados.'
            : 'Los próximos eventos programados aparecerán acá.';
        break;
    }

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
          Icon(icon, color: AppColors.fgLight, size: 56),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.fg,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            description,
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
