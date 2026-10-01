import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Barra de búsqueda en vivo y selector horizontal de categorías para el catálogo de eventos.
class EventSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String searchQuery;
  final int activeFiltersCount;
  final bool isFiltered;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onFilterTap;
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  const EventSearchBar({
    super.key,
    required this.controller,
    required this.searchQuery,
    required this.activeFiltersCount,
    required this.isFiltered,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onFilterTap,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Campo de Búsqueda y Botón de Filtros
        Row(
          children: [
            Expanded(
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.bgSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: controller,
                  onChanged: onSearchChanged,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(color: AppColors.fg, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Buscar evento, lugar o artista...',
                    hintStyle: const TextStyle(color: AppColors.fgMuted, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: AppColors.fgMuted, size: 20),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppColors.fgMuted, size: 18),
                            onPressed: onClearSearch,
                          )
                        : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Botón de filtros con badge
            Stack(
              children: [
                Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    color: isFiltered ? AppColors.accentSoft : AppColors.bgSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isFiltered ? AppColors.accent : AppColors.border,
                      width: isFiltered ? 1.5 : 1,
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.tune,
                      color: isFiltered ? AppColors.accent : AppColors.fg,
                      size: 20,
                    ),
                    tooltip: 'Filtros avanzados',
                    onPressed: onFilterTap,
                  ),
                ),
                if (activeFiltersCount > 0)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '$activeFiltersCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 2. Chips Rápidos de Categorías
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = cat.toLowerCase() == selectedCategory.toLowerCase();
              return ChoiceChip(
                label: Text(cat),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    onCategorySelected(cat);
                  }
                },
                selectedColor: AppColors.accent,
                backgroundColor: AppColors.bgSoft,
                showCheckmark: false,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.accentFg : AppColors.fg,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
                side: BorderSide(
                  color: isSelected ? AppColors.accent : AppColors.border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              );
            },
          ),
        ),
      ],
    );
  }
}
