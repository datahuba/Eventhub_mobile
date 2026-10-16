import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import '../widgets/event_card.dart';
import '../widgets/event_filter_sheet.dart';
import '../widgets/event_search_bar.dart';
import '../widgets/event_status_tab_bar.dart';
import '../widgets/events_empty_state.dart';
import '../widgets/eventhub_logo.dart';
import 'event_detail_screen.dart';
import 'tickets_screen.dart';

const List<String> _monthsEs = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
];

class EventsScreen extends StatefulWidget {
  final ApiService? apiService;

  const EventsScreen({super.key, this.apiService});

  /// Helper modularizado para filtrado de eventos según pestaña y criterios de búsqueda
  static List<Event> filterEventsHelper(
    List<Event> events, {
    int selectedTab = 0,
    String searchQuery = '',
    String selectedCategory = 'Todos',
    String selectedMonth = 'all',
    String selectedCity = 'all',
    String selectedPriceRange = 'all',
  }) {
    return events.where((e) {
      // 0. Filtro por pestaña activa:
      // Tab 0: "En Cartelera" -> solo eventos vigentes (!e.isPast)
      // Tab 1: "Pasados" -> solo eventos concluidos (e.isPast)
      // Tab 2: "Agotados" -> solo eventos agotados no pasados (e.isSoldOut && !e.isPast)
      // Tab 3: "Todos los Eventos" -> todos los eventos
      if (selectedTab == 0 && e.isPast) {
        return false;
      }
      if (selectedTab == 1 && !e.isPast) {
        return false;
      }
      if (selectedTab == 2 && (!e.isSoldOut || e.isPast)) {
        return false;
      }

      // 1. Filtro por búsqueda de texto (título, subtítulo, ubicación, categoría)
      if (searchQuery.trim().isNotEmpty) {
        final query = searchQuery.trim().toLowerCase();
        final matchTitle = e.title.toLowerCase().contains(query);
        final matchSubtitle = e.subtitle.toLowerCase().contains(query);
        final matchLoc = e.location.toLowerCase().contains(query);
        final matchCat = e.category.toLowerCase().contains(query);
        if (!matchTitle && !matchSubtitle && !matchLoc && !matchCat) {
          return false;
        }
      }

      // 2. Filtro por categoría
      if (selectedCategory != 'Todos' &&
          e.category.toLowerCase() != selectedCategory.toLowerCase()) {
        return false;
      }

      // 3. Filtro por mes (YYYY-MM)
      if (selectedMonth != 'all') {
        final key = '${e.startsAt.year}-${e.startsAt.month.toString().padLeft(2, '0')}';
        if (key != selectedMonth) return false;
      }

      // 4. Filtro por ciudad
      if (selectedCity != 'all') {
        if (!e.location.toLowerCase().contains(selectedCity.toLowerCase())) {
          return false;
        }
      }

      // 5. Filtro por rango de precio
      if (selectedPriceRange != 'all') {
        final minP = e.minPrice;
        if (selectedPriceRange == 'free' && minP > 0) return false;
        if (selectedPriceRange == 'under100' && minP > 100) return false;
        if (selectedPriceRange == 'over100' && minP <= 100) return false;
      }

      return true;
    }).toList();
  }

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  late final ApiService _apiService;
  final TextEditingController _searchController = TextEditingController();

  late Future<List<Event>> _eventsFuture;

  // Filtros activos (opcionales)
  String _searchQuery = '';
  String _selectedCategory = 'Todos';
  String _selectedMonth = 'all';
  String _selectedCity = 'all';
  String _selectedPriceRange = 'all'; // 'all', 'free', 'under100', 'over100'

  // Pestaña activa: 0 = En Cartelera, 1 = Pasados
  int _selectedEventTab = 0;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _loadEvents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadEvents() {
    setState(() {
      _eventsFuture = _apiService.getEvents();
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedEventTab = 0;
      _searchController.clear();
      _searchQuery = '';
      _selectedCategory = 'Todos';
      _selectedMonth = 'all';
      _selectedCity = 'all';
      _selectedPriceRange = 'all';
    });
  }

  int get _activeFiltersCount {
    int count = 0;
    if (_selectedEventTab != 0) count++;
    if (_searchQuery.trim().isNotEmpty) count++;
    if (_selectedCategory != 'Todos') count++;
    if (_selectedMonth != 'all') count++;
    if (_selectedCity != 'all') count++;
    if (_selectedPriceRange != 'all') count++;
    return count;
  }

  bool get _isFiltered => _activeFiltersCount > 0;

  String _getMonthYearKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}';

  String _getMonthYearLabel(DateTime dt) =>
      '${_monthsEs[dt.month - 1]} ${dt.year}';

  List<Event> _filterEvents(List<Event> events, {int? tab}) {
    return EventsScreen.filterEventsHelper(
      events,
      selectedTab: tab ?? _selectedEventTab,
      searchQuery: _searchQuery,
      selectedCategory: _selectedCategory,
      selectedMonth: _selectedMonth,
      selectedCity: _selectedCity,
      selectedPriceRange: _selectedPriceRange,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
        title: const EventHubLogo(fontSize: 22),
        actions: [
          IconButton(
            icon: const Icon(Icons.confirmation_number_outlined, color: AppColors.fg),
            tooltip: 'Mis Entradas',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TicketsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.bg,
        onRefresh: () async => _loadEvents(),
        child: FutureBuilder<List<Event>>(
          future: _eventsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off_outlined, color: AppColors.fgLight, size: 56),
                      const SizedBox(height: 16),
                      Text(
                        'No se pudieron cargar los eventos',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.fg,
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}',
                        style: const TextStyle(color: AppColors.fgMuted, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _loadEvents,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Reintentar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.accentFg,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final events = snapshot.data ?? [];
            if (events.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_busy, color: AppColors.fgLight, size: 56),
                    SizedBox(height: 16),
                    Text(
                      'No hay eventos programados en este momento.',
                      style: TextStyle(color: AppColors.fgMuted, fontSize: 15),
                    ),
                  ],
                ),
              );
            }

            // Extraer categorías dinámicas
            final categorySet = <String>{};
            for (final e in events) {
              if (e.category.isNotEmpty) categorySet.add(e.category);
            }
            final categories = ['Todos', ...(categorySet.toList()..sort())];

            // Extraer ciudades dinámicas
            final citySet = <String>{};
            for (final e in events) {
              if (e.location.isNotEmpty) {
                final parts = e.location.split(RegExp(r'[,-]'));
                final city = parts.last.trim();
                citySet.add(city.isNotEmpty ? city : e.location);
              }
            }
            final cities = citySet.toList()..sort();

            // Extraer meses dinámicos
            final Map<String, String> monthTabs = {};
            for (final e in events) {
              final key = _getMonthYearKey(e.startsAt);
              monthTabs[key] = _getMonthYearLabel(e.startsAt);
            }

            // Aplicar filtros en memoria
            final filteredEvents = _filterEvents(events);

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                // 1. Barra de Búsqueda y Selector de Categorías modularizado
                EventSearchBar(
                  controller: _searchController,
                  searchQuery: _searchQuery,
                  activeFiltersCount: _activeFiltersCount,
                  isFiltered: _isFiltered,
                  onSearchChanged: (val) => setState(() => _searchQuery = val),
                  onClearSearch: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  onFilterTap: () {
                    EventFilterSheet.show(
                      context,
                      categories: categories,
                      monthTabs: monthTabs,
                      cities: cities,
                      currentCategory: _selectedCategory,
                      currentMonth: _selectedMonth,
                      currentCity: _selectedCity,
                      currentPriceRange: _selectedPriceRange,
                      onApply: ({
                        required category,
                        required month,
                        required city,
                        required priceRange,
                      }) {
                        setState(() {
                          _selectedCategory = category;
                          _selectedMonth = month;
                          _selectedCity = city;
                          _selectedPriceRange = priceRange;
                        });
                      },
                    );
                  },
                  categories: categories,
                  selectedCategory: _selectedCategory,
                  onCategorySelected: (cat) => setState(() => _selectedCategory = cat),
                ),
                const SizedBox(height: 14),

                // 2. Selector de Pestañas: [ En Cartelera ] [ Pasados ] [ Agotados ] [ Todos los Eventos ]
                Builder(
                  builder: (context) {
                    final activeEvents = _filterEvents(events, tab: 0);
                    final pastEvents = _filterEvents(events, tab: 1);
                    final soldOutEvents = _filterEvents(events, tab: 2);
                    final allEvents = _filterEvents(events, tab: 3);

                    final currentTabEvents = _filterEvents(events);

                    final tabSuffix = _selectedEventTab == 0
                        ? 'activo'
                        : _selectedEventTab == 1
                            ? 'pasado'
                            : _selectedEventTab == 2
                                ? 'agotado'
                                : 'en total';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        EventStatusTabBar(
                          selectedTab: _selectedEventTab,
                          activeCount: activeEvents.length,
                          concludedCount: pastEvents.length,
                          soldOutCount: soldOutEvents.length,
                          allCount: allEvents.length,
                          onTabChanged: (index) => setState(() => _selectedEventTab = index),
                        ),

                        // 3. Indicador de resultados y acción para limpiar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${currentTabEvents.length} evento${currentTabEvents.length == 1 ? '' : 's'} $tabSuffix${currentTabEvents.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                color: AppColors.fgMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_isFiltered)
                              GestureDetector(
                                onTap: _clearAllFilters,
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.close, size: 14, color: AppColors.accent),
                                    SizedBox(width: 4),
                                    Text(
                                      'Limpiar filtros',
                                      style: TextStyle(
                                        color: AppColors.accent,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // 4. Listado de Eventos de la Pestaña o Estado Vacío (modularizado)
                        if (currentTabEvents.isEmpty)
                          EventsEmptyState(
                            selectedTab: _selectedEventTab,
                            isFiltered: _isFiltered,
                            onClearFilters: _clearAllFilters,
                          )
                        else
                          ...currentTabEvents.map(
                            (event) => EventCard(
                              event: event,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EventDetailScreen(event: event),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
