import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub_mobile/models/event.dart';
import 'package:eventhub_mobile/screens/events_screen.dart';
import 'package:eventhub_mobile/widgets/event_card.dart';
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

  group('Issue #35: Pull-to-refresh y reintento tras error en EventsScreen', () {
    Event buildEvent({
      required String id,
      required String title,
      String category = 'Conciertos',
      String location = 'La Paz',
    }) {
      return Event(
        id: id,
        title: title,
        subtitle: 'En vivo',
        heroImage: '',
        images: [],
        startsAt: DateTime.now().add(const Duration(days: 7)),
        time: '20:00',
        location: location,
        address: 'Av. Principal',
        description: ['Descripción de prueba'],
        category: category,
        categoryColor: '#EC3013',
        tiers: [TicketTier(name: 'General', price: 100.0)],
        pricingNotes: [],
        isSoldOut: false,
      );
    }

    testWidgets('muestra botón Reintentar tras fallo en getEvents() y carga EventCards al presionarlo', (WidgetTester tester) async {
      final secondCallCompleter = Completer<List<Event>>();
      final fakeApi = FakeApiService();
      fakeApi.getEventsHandler = () {
        if (fakeApi.getEventsCallCount == 1) {
          return Future.error(Exception('timeout'));
        }
        return secondCallCompleter.future;
      };

      await tester.pumpWidget(
        MaterialApp(
          home: EventsScreen(apiService: fakeApi),
        ),
      );

      // Resolver primera llamada con error
      await tester.pumpAndSettle();

      expect(fakeApi.getEventsCallCount, 1);
      expect(find.text('No se pudieron cargar los eventos'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);

      // Presionar Reintentar -> muestra CircularProgressIndicator mientras recarga
      await tester.tap(find.text('Reintentar'));
      await tester.pump();

      expect(fakeApi.getEventsCallCount, 2);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Completar segunda llamada con 2 eventos
      secondCallCompleter.complete([
        buildEvent(id: 'evt-1', title: 'Concierto Uno'),
        buildEvent(id: 'evt-2', title: 'Concierto Dos'),
      ]);
      await tester.pumpAndSettle();

      expect(find.byType(EventCard), findsNWidgets(2));
      expect(find.text('Concierto Uno'), findsOneWidget);
      expect(find.text('Concierto Dos'), findsOneWidget);
    });

    testWidgets('pull-to-refresh tras carga exitosa vuelve a invocar getEvents() preservando búsqueda y categoría', (WidgetTester tester) async {
      final fakeApi = FakeApiService();
      fakeApi.getEventsHandler = () async {
        if (fakeApi.getEventsCallCount == 1) {
          return [
            buildEvent(id: '1', title: 'Noche de Rock Inicial', category: 'Conciertos'),
            buildEvent(id: '2', title: 'Obra Clásica', category: 'Teatro'),
          ];
        }
        return [
          buildEvent(id: '1', title: 'Noche de Rock Actualizada', category: 'Conciertos'),
          buildEvent(id: '3', title: 'Otro Rock En Vivo', category: 'Conciertos'),
          buildEvent(id: '4', title: 'Partido Nocturno', category: 'Deportes'),
        ];
      };

      await tester.pumpWidget(
        MaterialApp(
          home: EventsScreen(apiService: fakeApi),
        ),
      );
      await tester.pumpAndSettle();

      expect(fakeApi.getEventsCallCount, 1);
      expect(find.text('Noche de Rock Inicial'), findsOneWidget);
      expect(find.text('Obra Clásica'), findsOneWidget);

      // Aplicar filtros activos: _searchQuery = 'rock' y categoría = 'Conciertos'
      await tester.enterText(find.byType(TextField), 'rock');
      await tester.pump();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Conciertos'));
      await tester.pumpAndSettle();

      expect(find.text('Noche de Rock Inicial'), findsOneWidget);
      expect(find.text('Obra Clásica'), findsNothing);

      // Ejecutar pull-to-refresh deslizando hacia abajo
      await tester.fling(find.byType(ListView).first, const Offset(0, 300), 1000);
      await tester.pumpAndSettle();

      expect(fakeApi.getEventsCallCount, 2);

      // Lista actualizada con los filtros preservados
      expect(find.text('Noche de Rock Actualizada'), findsOneWidget);
      expect(find.text('Otro Rock En Vivo'), findsOneWidget);
      expect(find.text('Partido Nocturno'), findsNothing);

      // El texto escrito en _searchController sigue mostrándose y el chip sigue seleccionado
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'rock');
      final conciertosChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Conciertos'),
      );
      expect(conciertosChip.selected, isTrue);
    });

    testWidgets('durante el pull-to-refresh el RefreshProgressIndicator nativo es visible y desaparece al resolver el Future', (WidgetTester tester) async {
      final refreshCompleter = Completer<List<Event>>();
      final fakeApi = FakeApiService();
      fakeApi.getEventsHandler = () {
        if (fakeApi.getEventsCallCount == 1) {
          return Future.value([
            buildEvent(id: '1', title: 'Evento Base'),
          ]);
        }
        return refreshCompleter.future;
      };

      await tester.pumpWidget(
        MaterialApp(
          home: EventsScreen(apiService: fakeApi),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RefreshProgressIndicator), findsNothing);

      // Iniciar gesto pull-to-refresh sin resolver aún el Completer
      await tester.fling(find.byType(ListView).first, const Offset(0, 350), 1000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(fakeApi.getEventsCallCount, 2);
      expect(find.byType(RefreshProgressIndicator), findsOneWidget);

      // Resolver el Future de recarga
      refreshCompleter.complete([
        buildEvent(id: '1', title: 'Evento Base'),
        buildEvent(id: '2', title: 'Evento Nuevo'),
      ]);
      await tester.pumpAndSettle();

      expect(find.byType(RefreshProgressIndicator), findsNothing);
      expect(find.text('Evento Nuevo'), findsOneWidget);
    });

    testWidgets('pull-to-refresh también funciona cuando el catálogo está vacío', (WidgetTester tester) async {
      final fakeApi = FakeApiService();
      fakeApi.getEventsHandler = () async {
        if (fakeApi.getEventsCallCount == 1) {
          return [];
        }
        return [
          buildEvent(id: '1', title: 'Primer Evento Publicado'),
        ];
      };

      await tester.pumpWidget(
        MaterialApp(
          home: EventsScreen(apiService: fakeApi),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No hay eventos programados en este momento.'), findsOneWidget);

      await tester.fling(find.byType(SingleChildScrollView), const Offset(0, 350), 1000);
      await tester.pumpAndSettle();

      expect(fakeApi.getEventsCallCount, 2);
      expect(find.text('Primer Evento Publicado'), findsOneWidget);
    });
  });
}
