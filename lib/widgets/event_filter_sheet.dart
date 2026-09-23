import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Modal Bottom Sheet para filtros avanzados de eventos (mes, ciudad, rango de precio).
class EventFilterSheet extends StatefulWidget {
  final List<String> categories;
  final Map<String, String> monthTabs;
  final List<String> cities;
  final String initialCategory;
  final String initialMonth;
  final String initialCity;
  final String initialPriceRange;
  final void Function({
    required String category,
    required String month,
    required String city,
    required String priceRange,
  }) onApply;

  const EventFilterSheet({
    super.key,
    required this.categories,
    required this.monthTabs,
    required this.cities,
    required this.initialCategory,
    required this.initialMonth,
    required this.initialCity,
    required this.initialPriceRange,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required List<String> categories,
    required Map<String, String> monthTabs,
    required List<String> cities,
    required String currentCategory,
    required String currentMonth,
    required String currentCity,
    required String currentPriceRange,
    required void Function({
      required String category,
      required String month,
      required String city,
      required String priceRange,
    }) onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => EventFilterSheet(
        categories: categories,
        monthTabs: monthTabs,
        cities: cities,
        initialCategory: currentCategory,
        initialMonth: currentMonth,
        initialCity: currentCity,
        initialPriceRange: currentPriceRange,
        onApply: onApply,
      ),
    );
  }

  @override
  State<EventFilterSheet> createState() => _EventFilterSheetState();
}

class _EventFilterSheetState extends State<EventFilterSheet> {
  late String _category;
  late String _month;
  late String _city;
  late String _priceRange;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    _month = widget.initialMonth;
    _city = widget.initialCity;
    _priceRange = widget.initialPriceRange;
  }

  void _reset() {
    setState(() {
      _category = 'Todos';
      _month = 'all';
      _city = 'all';
      _priceRange = 'all';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filtros de Eventos',
                    style: TextStyle(
                      color: AppColors.fg,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  TextButton(
                    onPressed: _reset,
                    child: const Text(
                      'Restablecer',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 16),

              // Sección 1: Mes / Calendario
              const Text(
                'Fecha del Evento (Mes)',
                style: TextStyle(
                  color: AppColors.fg,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildChoiceChip(
                    label: 'Todos los meses',
                    isSelected: _month == 'all',
                    onSelected: (sel) {
                      if (sel) setState(() => _month = 'all');
                    },
                  ),
                  ...widget.monthTabs.entries.map((entry) {
                    return _buildChoiceChip(
                      label: entry.value,
                      isSelected: _month == entry.key,
                      onSelected: (sel) {
                        if (sel) setState(() => _month = entry.key);
                      },
                    );
                  }),
                ],
              ),
              const SizedBox(height: 20),

              // Sección 2: Ciudad
              const Text(
                'Ciudad / Ubicación',
                style: TextStyle(
                  color: AppColors.fg,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildChoiceChip(
                    label: 'Todas las ciudades',
                    isSelected: _city == 'all',
                    onSelected: (sel) {
                      if (sel) setState(() => _city = 'all');
                    },
                  ),
                  ...widget.cities.map((city) {
                    return _buildChoiceChip(
                      label: city,
                      isSelected: _city.toLowerCase() == city.toLowerCase(),
                      onSelected: (sel) {
                        if (sel) setState(() => _city = city);
                      },
                    );
                  }),
                ],
              ),
              const SizedBox(height: 20),

              // Sección 3: Rango de Precios
              const Text(
                'Rango de Precios',
                style: TextStyle(
                  color: AppColors.fg,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildChoiceChip(
                    label: 'Cualquier precio',
                    isSelected: _priceRange == 'all',
                    onSelected: (sel) {
                      if (sel) setState(() => _priceRange = 'all');
                    },
                  ),
                  _buildChoiceChip(
                    label: 'Gratis (Bs. 0)',
                    isSelected: _priceRange == 'free',
                    onSelected: (sel) {
                      if (sel) setState(() => _priceRange = 'free');
                    },
                  ),
                  _buildChoiceChip(
                    label: 'Hasta Bs. 100',
                    isSelected: _priceRange == 'under100',
                    onSelected: (sel) {
                      if (sel) setState(() => _priceRange = 'under100');
                    },
                  ),
                  _buildChoiceChip(
                    label: 'Más de Bs. 100',
                    isSelected: _priceRange == 'over100',
                    onSelected: (sel) {
                      if (sel) setState(() => _priceRange = 'over100');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Botón Aplicar
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(
                      category: _category,
                      month: _month,
                      city: _city,
                      priceRange: _priceRange,
                    );
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.accentFg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Aplicar Filtros',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool isSelected,
    required ValueChanged<bool> onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      showCheckmark: false,
      selectedColor: AppColors.accent,
      backgroundColor: AppColors.bgSoft,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.accentFg : AppColors.fg,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 12,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.accent : AppColors.border,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }
}
