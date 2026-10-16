import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub_mobile/models/event.dart';
import 'package:eventhub_mobile/screens/events_screen.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('Issue #6: Filtrado por pestaña Pasados / En Cartelera', () {
    final pastEvent1 = Event(
      id: 'past-1',
      title: 'Festival Pasado Rock',
      subtitle: 'Concluido',
      heroImage: '',
      images: [],
      startsAt: DateTime.now().subtract(const Duration(days: 10)),
      time: '18:00',
      location: 'La Paz',
      address: 'Calle 1',
      description: ['Desc'],
      category: 'Música',
      categoryColor: '#EC3013',
      tiers: [TicketTier(name: 'General', price: 50.0)],
      pricingNotes: [],
      isSoldOut: false,
    );

    final pastEvent2 = Event(
      id: 'past-2',
      title: 'Obra Teatral Pasada',
      subtitle: 'Concluido',
      heroImage: '',
      images: [],
      startsAt: DateTime.now().subtract(const Duration(days: 20)),
      time: '19:00',
      location: 'Cochabamba',
      address: 'Calle 2',
      description: ['Desc'],
      category: 'Teatro',
      categoryColor: '#EC3013',
      tiers: [TicketTier(name: 'General', price: 80.0)],
      pricingNotes: [],
      isSoldOut: false,
    );

    final futureEvent1 = Event(
      id: 'future-1',
      title: 'Concierto Futuro Pop',
      subtitle: 'Próximamente',
      heroImage: '',
      images: [],
      startsAt: DateTime.now().add(const Duration(days: 10)),
      time: '20:00',
      location: 'La Paz',
      address: 'Calle 3',
      description: ['Desc'],
      category: 'Música',
      categoryColor: '#EC3013',
      tiers: [TicketTier(name: 'General', price: 120.0)],
      pricingNotes: [],
      isSoldOut: false,
    );

    final futureEvent2 = Event(
      id: 'future-2',
      title: 'Torneo Deportivo Futuro',
      subtitle: 'Próximamente',
      heroImage: '',
      images: [],
      startsAt: DateTime.now().add(const Duration(days: 15)),
      time: '16:00',
      location: 'Santa Cruz',
      address: 'Calle 4',
      description: ['Desc'],
      category: 'Deportes',
      categoryColor: '#EC3013',
      tiers: [TicketTier(name: 'General', price: 40.0)],
      pricingNotes: [],
      isSoldOut: false,
    );

    final mixedEvents = [pastEvent1, pastEvent2, futureEvent1, futureEvent2];

    test('Helper de filtrado: pestaña 0 ("En Cartelera") retorna solo eventos vigentes (isPast == false)', () {
      final results = EventsScreen.filterEventsHelper(mixedEvents, selectedTab: 0);

      expect(results.length, 2);
      expect(results.every((e) => !e.isPast), isTrue);
      expect(results.map((e) => e.id), containsAll(['future-1', 'future-2']));
      expect(results.map((e) => e.id), isNot(contains('past-1')));
    });

    test('Helper de filtrado: pestaña 1 ("Pasados") retorna solo eventos ya concluidos (isPast == true)', () {
      final results = EventsScreen.filterEventsHelper(mixedEvents, selectedTab: 1);

      expect(results.length, 2);
      expect(results.every((e) => e.isPast), isTrue);
      expect(results.map((e) => e.id), containsAll(['past-1', 'past-2']));
      expect(results.map((e) => e.id), isNot(contains('future-1')));
    });

    test('Helper de filtrado: combina pestaña "Pasados" con categoría aplicando lógica AND', () {
      final resultsMusic = EventsScreen.filterEventsHelper(
        mixedEvents,
        selectedTab: 1,
        selectedCategory: 'Música',
      );

      expect(resultsMusic.length, 1);
      expect(resultsMusic.first.id, 'past-1');

      final resultsTheater = EventsScreen.filterEventsHelper(
        mixedEvents,
        selectedTab: 1,
        selectedCategory: 'Teatro',
      );

      expect(resultsTheater.length, 1);
      expect(resultsTheater.first.id, 'past-2');
    });

    test('Helper de filtrado: combina pestaña "Pasados" con búsqueda de texto aplicando lógica AND', () {
      final results = EventsScreen.filterEventsHelper(
        mixedEvents,
        selectedTab: 1,
        searchQuery: 'Rock',
      );

      expect(results.length, 1);
      expect(results.first.id, 'past-1');
    });

    testWidgets('Widget EventsScreen: cambia contenido al alternar entre En Cartelera y Pasados', (WidgetTester tester) async {
      final fakeApi = FakeApiService(eventsToReturn: mixedEvents);

      await tester.pumpWidget(
        MaterialApp(
          home: EventsScreen(apiService: fakeApi),
        ),
      );

      // Esperar carga de FutureBuilder
      await tester.pumpAndSettle();

      // Pestaña inicial: 0 ("En Cartelera") -> solo futuros visibles
      expect(find.text('Concierto Futuro Pop'), findsOneWidget);
      expect(find.text('Torneo Deportivo Futuro'), findsOneWidget);
      expect(find.text('Festival Pasado Rock'), findsNothing);
      expect(find.text('Obra Teatral Pasada'), findsNothing);

      // Tocar pestaña "Pasados"
      await tester.tap(find.text('Pasados'));
      await tester.pumpAndSettle();

      // Ahora solo deben estar visibles los eventos pasados
      expect(find.text('Festival Pasado Rock'), findsOneWidget);
      expect(find.text('Obra Teatral Pasada'), findsOneWidget);
      expect(find.text('Concierto Futuro Pop'), findsNothing);
      expect(find.text('Torneo Deportivo Futuro'), findsNothing);

      // Debe mostrar el contador de filtros activos (botón Limpiar filtros visible)
      expect(find.text('Limpiar filtros'), findsOneWidget);

      // Tocar nuevamente "En Cartelera"
      await tester.tap(find.text('En Cartelera'));
      await tester.pumpAndSettle();

      // Vuelven los eventos vigentes
      expect(find.text('Concierto Futuro Pop'), findsOneWidget);
      expect(find.text('Torneo Deportivo Futuro'), findsOneWidget);
      expect(find.text('Festival Pasado Rock'), findsNothing);
    });
  });
}
