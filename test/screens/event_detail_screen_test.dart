import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub_mobile/models/event.dart';
import 'package:eventhub_mobile/screens/event_detail_screen.dart';
import 'package:eventhub_mobile/widgets/event_bottom_purchase_bar.dart';
import 'package:eventhub_mobile/widgets/tier_chip.dart';

void main() {
  group('Issue #7: Reajuste de cantidad de entradas al cambiar de sector', () {
    test('EventDetailScreen.clampQuantityForTier: reduce la cantidad al tope del sector cuando excede la capacidad', () {
      final tierVip = TicketTier(name: 'VIP', price: 250.0, capacity: 2);
      expect(EventDetailScreen.clampQuantityForTier(5, tierVip), 2);
      expect(EventDetailScreen.clampQuantityForTier(3, tierVip), 2);
    });

    test('EventDetailScreen.clampQuantityForTier: mantiene la cantidad si ya es menor o igual a la capacidad', () {
      final tierVip = TicketTier(name: 'VIP', price: 250.0, capacity: 2);
      expect(EventDetailScreen.clampQuantityForTier(2, tierVip), 2);
      expect(EventDetailScreen.clampQuantityForTier(1, tierVip), 1);
    });

    test('EventDetailScreen.clampQuantityForTier: mantiene la cantidad si la capacidad es null y ajusta a 0 si la capacidad es 0', () {
      final tierUnlimited = TicketTier(name: 'General', price: 100.0, capacity: null);
      final tierZeroCap = TicketTier(name: 'Agotado', price: 50.0, capacity: 0);
      final tierNegativeCap = TicketTier(name: 'Negativo', price: 50.0, capacity: -1);

      expect(EventDetailScreen.clampQuantityForTier(7, tierUnlimited), 7);
      expect(EventDetailScreen.clampQuantityForTier(8, tierZeroCap), 0);
      expect(EventDetailScreen.clampQuantityForTier(5, tierNegativeCap), 0);
      expect(EventDetailScreen.clampQuantityForTier(4, null), 4);
    });

    testWidgets('Widget EventDetailScreen: al cambiar a sector con menor capacidad, ajusta cantidad, actualiza precio total y muestra SnackBar', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final multiTierEvent = Event(
        id: 'evt-tier-test',
        title: 'Festival Multicapacidad',
        subtitle: 'En vivo',
        heroImage: '',
        images: [],
        startsAt: DateTime.now().add(const Duration(days: 5)),
        time: '21:00',
        location: 'Estadio Olímpico',
        address: 'Av. Libertador',
        description: ['Gran festival con múltiples sectores'],
        category: 'Música',
        categoryColor: '#EC3013',
        tiers: [
          TicketTier(name: 'General', price: 100.0, capacity: 100),
          TicketTier(name: 'VIP', price: 300.0, capacity: 2),
          TicketTier(name: 'Platino', price: 450.0, capacity: null),
        ],
        pricingNotes: [],
        isSoldOut: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EventDetailScreen(event: multiTierEvent),
        ),
      );
      await tester.pumpAndSettle();

      // Sector inicial seleccionado: General. Cantidad inicial: 1. Precio inicial: Bs. 100.00 en bottom bar
      expect(
        find.descendant(of: find.byType(EventBottomPurchaseBar), matching: find.text('Bs. 100.00')),
        findsOneWidget,
      );
      expect(find.text('1'), findsOneWidget);

      // Incrementar cantidad a 5 pulsando el botón + 4 veces
      final incrementFinder = find.byIcon(Icons.add_circle_outline);
      expect(incrementFinder, findsOneWidget);

      await tester.tap(incrementFinder);
      await tester.pump();
      await tester.tap(incrementFinder);
      await tester.pump();
      await tester.tap(incrementFinder);
      await tester.pump();
      await tester.tap(incrementFinder);
      await tester.pumpAndSettle();

      // Cantidad ahora es 5, precio total: 5 x 100 = Bs. 500.00 en bottom bar
      expect(find.text('5'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(EventBottomPurchaseBar), matching: find.text('Bs. 500.00')),
        findsOneWidget,
      );

      // Cambiar de sector a "VIP" (capacity = 2)
      await tester.tap(find.text('VIP'));
      await tester.pump(); // Inicia animación y muestra SnackBar

      // Cantidad debe haberse reajustado a 2
      expect(find.text('2'), findsOneWidget);
      // Precio total debe reflejarse al instante con el nuevo sector y la nueva cantidad: 2 x 300 = Bs. 600.00
      expect(
        find.descendant(of: find.byType(EventBottomPurchaseBar), matching: find.text('Bs. 600.00')),
        findsOneWidget,
      );

      // Debe mostrar el SnackBar informativo
      expect(find.text('Ajustamos la cantidad a 2 por la capacidad de VIP'), findsOneWidget);

      await tester.pumpAndSettle();

      // Cambiar nuevamente a "General" (capacity = 100).
      // Como 2 <= 100, la cantidad se mantiene en 2 y NO debe mostrarse nuevo SnackBar de ajuste.
      await tester.tap(find.text('General'));
      await tester.pump();

      expect(find.text('2'), findsOneWidget);
      // Precio total: 2 x 100 = Bs. 200.00
      expect(
        find.descendant(of: find.byType(EventBottomPurchaseBar), matching: find.text('Bs. 200.00')),
        findsOneWidget,
      );
      // SnackBar de ajuste ya no debe mostrarse para General
      expect(find.text('Ajustamos la cantidad a 2 por la capacidad de General'), findsNothing);

      // Cambiar a "Platino" (capacity = null, sin tope).
      // Cantidad debe mantenerse en 2 sin error ni SnackBar de ajuste.
      await tester.tap(find.text('Platino'));
      await tester.pump();

      expect(find.text('2'), findsOneWidget);
      // Precio total: 2 x 450 = Bs. 900.00
      expect(
        find.descendant(of: find.byType(EventBottomPurchaseBar), matching: find.text('Bs. 900.00')),
        findsOneWidget,
      );
      expect(find.text('Ajustamos la cantidad a 2 por la capacidad de Platino'), findsNothing);
    });
  });

  group('Issue #8: Tope de entradas según capacidad del sector y fallback global de 10', () {
    test('EventDetailScreen.maxQuantityForTier: evalúa correctamente capacidades aplicando min(10, capacity)', () {
      final tierNull = TicketTier(name: 'General', price: 100.0, capacity: null);
      final tier0 = TicketTier(name: 'Agotado', price: 50.0, capacity: 0);
      final tier3 = TicketTier(name: 'VIP 3', price: 200.0, capacity: 3);
      final tier10 = TicketTier(name: 'Sector 10', price: 150.0, capacity: 10);
      final tier50 = TicketTier(name: 'Platea 50', price: 80.0, capacity: 50);

      expect(EventDetailScreen.maxQuantityForTier(tierNull), 10);
      expect(EventDetailScreen.maxQuantityForTier(tier0), 0);
      expect(EventDetailScreen.maxQuantityForTier(tier3), 3);
      expect(EventDetailScreen.maxQuantityForTier(tier10), 10);
      expect(EventDetailScreen.maxQuantityForTier(tier50), 10); // min(10, 50) == 10
      expect(EventDetailScreen.maxQuantityForTier(null), 10);
    });

    test('EventDetailScreen.clampQuantityForTier: aplica min(10, capacity) incluso al cambiar a sector sin capacidad', () {
      final tierNull = TicketTier(name: 'General', price: 100.0, capacity: null);
      final tier50 = TicketTier(name: 'Platea 50', price: 80.0, capacity: 50);
      final tier3 = TicketTier(name: 'VIP 3', price: 200.0, capacity: 3);
      final tier0 = TicketTier(name: 'Agotado', price: 50.0, capacity: 0);

      // Si la cantidad previa era mayor a 10 y se cambia a sector sin capacidad (null), se topa a 10
      expect(EventDetailScreen.clampQuantityForTier(15, tierNull), 10);

      // Si la cantidad previa era mayor a 10 y se cambia a sector con capacidad > 10, se topa a 10
      expect(EventDetailScreen.clampQuantityForTier(20, tier50), 10);

      // Si se cambia a sector con capacidad 3, se topa a 3
      expect(EventDetailScreen.clampQuantityForTier(7, tier3), 3);

      // Si se cambia a sector agotado (0), pasa a 0
      expect(EventDetailScreen.clampQuantityForTier(5, tier0), 0);

      // Cantidades normales se mantienen
      expect(EventDetailScreen.clampQuantityForTier(4, tierNull), 4);
      expect(EventDetailScreen.clampQuantityForTier(2, tier3), 2);
    });

    testWidgets('Widget EventDetailScreen: sector con capacity: 3 permite máximo 3 y muestra SnackBar al intentar superar', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final event = Event(
        id: 'evt-cap-3',
        title: 'Show Intimo',
        subtitle: 'Acústico',
        heroImage: '',
        images: [],
        startsAt: DateTime.now().add(const Duration(days: 3)),
        time: '20:00',
        location: 'Club de Jazz',
        address: 'Calle 10',
        description: ['Show'],
        category: 'Música',
        categoryColor: '#EC3013',
        tiers: [
          TicketTier(name: 'VIP', price: 150.0, capacity: 3),
        ],
        pricingNotes: [],
        isSoldOut: false,
      );

      await tester.pumpWidget(MaterialApp(home: EventDetailScreen(event: event)));
      await tester.pumpAndSettle();

      final incrementFinder = find.byIcon(Icons.add_circle_outline);

      // Inicia en 1
      expect(find.text('1'), findsOneWidget);

      // 1 -> 2
      await tester.tap(incrementFinder);
      await tester.pump();
      expect(find.text('2'), findsOneWidget);

      // 2 -> 3
      await tester.tap(incrementFinder);
      await tester.pump();
      expect(find.text('3'), findsOneWidget);

      // Intento de superar 3 -> No incrementa y muestra SnackBar de error
      await tester.tap(incrementFinder);
      await tester.pump();

      expect(find.text('3'), findsOneWidget);
      expect(find.text('Capacidad máxima de VIP alcanzada'), findsOneWidget);
    });

    testWidgets('Widget EventDetailScreen: sector General sin capacity definida tiene tope de 10 y muestra SnackBar', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final event = Event(
        id: 'evt-cap-null',
        title: 'Concierto Masivo',
        subtitle: '',
        heroImage: '',
        images: [],
        startsAt: DateTime.now().add(const Duration(days: 4)),
        time: '19:00',
        location: 'Estadio',
        address: 'Av. Principal',
        description: ['General sin tope explícito'],
        category: 'Música',
        categoryColor: '#EC3013',
        tiers: [
          TicketTier(name: 'General', price: 80.0, capacity: null),
        ],
        pricingNotes: [],
        isSoldOut: false,
      );

      await tester.pumpWidget(MaterialApp(home: EventDetailScreen(event: event)));
      await tester.pumpAndSettle();

      final incrementFinder = find.byIcon(Icons.add_circle_outline);

      // Incrementar 9 veces hasta llegar a 10
      for (int i = 0; i < 9; i++) {
        await tester.tap(incrementFinder);
        await tester.pump();
      }
      expect(find.text('10'), findsOneWidget);
      expect(find.text('Capacidad máxima de General alcanzada'), findsNothing);

      // Intento de superar 10 -> muestra SnackBar y se queda en 10
      await tester.tap(incrementFinder);
      await tester.pump();

      expect(find.text('10'), findsOneWidget);
      expect(find.text('Capacidad máxima de General alcanzada'), findsOneWidget);
    });

    testWidgets('Widget EventDetailScreen: sector con capacity: 50 respeta tope global de 10 (min(10, 50)) y no permite superar 10', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final event = Event(
        id: 'evt-cap-50',
        title: 'Festival Grande',
        subtitle: '',
        heroImage: '',
        images: [],
        startsAt: DateTime.now().add(const Duration(days: 10)),
        time: '18:00',
        location: 'Parque Central',
        address: 'Zona Sur',
        description: ['Platea amplia'],
        category: 'Festivales',
        categoryColor: '#EC3013',
        tiers: [
          TicketTier(name: 'Platea', price: 50.0, capacity: 50),
        ],
        pricingNotes: [],
        isSoldOut: false,
      );

      await tester.pumpWidget(MaterialApp(home: EventDetailScreen(event: event)));
      await tester.pumpAndSettle();

      final incrementFinder = find.byIcon(Icons.add_circle_outline);

      // Incrementar hasta 10 (tope global máximo: min(10, 50))
      for (int i = 0; i < 9; i++) {
        await tester.tap(incrementFinder);
        await tester.pump();
      }
      expect(find.text('10'), findsOneWidget);
      expect(find.text('Capacidad máxima de Platea alcanzada'), findsNothing);

      // Intento de superar 10 -> muestra SnackBar y se queda en 10
      await tester.tap(incrementFinder);
      await tester.pump();

      expect(find.text('10'), findsOneWidget);
      expect(find.text('Capacidad máxima de Platea alcanzada'), findsOneWidget);
    });

    testWidgets('Widget EventDetailScreen: al cambiar entre sectores respeta min(10, capacity) y ajusta cantidad', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final event = Event(
        id: 'evt-multi-tiers',
        title: 'Concierto Mixto',
        subtitle: '',
        heroImage: '',
        images: [],
        startsAt: DateTime.now().add(const Duration(days: 10)),
        time: '18:00',
        location: 'Estadio',
        address: 'Centro',
        description: ['Varios sectores'],
        category: 'Música',
        categoryColor: '#EC3013',
        tiers: [
          TicketTier(name: 'General', price: 50.0, capacity: null),
          TicketTier(name: 'VIP', price: 150.0, capacity: 3),
        ],
        pricingNotes: [],
        isSoldOut: false,
      );

      await tester.pumpWidget(MaterialApp(home: EventDetailScreen(event: event)));
      await tester.pumpAndSettle();

      final incrementFinder = find.byIcon(Icons.add_circle_outline);

      // Inicia en General (capacity: null). Incrementar hasta 5
      for (int i = 0; i < 4; i++) {
        await tester.tap(incrementFinder);
        await tester.pump();
      }
      expect(find.text('5'), findsOneWidget);

      // Cambiar a VIP (capacity: 3) -> debe clamplear de 5 a 3
      await tester.tap(find.text('VIP'));
      await tester.pump();

      expect(find.text('3'), findsOneWidget);
      expect(find.text('Ajustamos la cantidad a 3 por la capacidad de VIP'), findsOneWidget);
    });
  });

  group('Issue #36: Selección de TicketTier con nombres duplicados', () {
    test('TicketTier parsea id String/int/null y resuelve isSameTier con fallback a identical', () {
      final tierStringId = TicketTier.fromMap({
        'id': 'tier-day-1',
        'name': 'General',
        'price': 100,
        'capacity': 50,
      });
      final tierIntId = TicketTier.fromMap({
        'id': 2,
        'name': 'General',
        'price': 150,
        'capacity': 20,
      });
      final tierDuplicateSameId = TicketTier.fromMap({
        'id': 'tier-day-1',
        'name': 'General',
        'price': 100,
      });
      final tierNoIdA = TicketTier(name: 'General', price: 100.0);
      final tierNoIdB = TicketTier(name: 'General', price: 100.0);

      expect(tierStringId.id, 'tier-day-1');
      expect(tierIntId.id, '2');
      expect(tierNoIdA.id, isNull);

      expect(tierStringId.isSameTier(tierStringId), isTrue);
      expect(tierStringId.isSameTier(tierDuplicateSameId), isTrue);
      expect(tierStringId.isSameTier(tierIntId), isFalse);
      expect(tierNoIdA.isSameTier(tierNoIdA), isTrue);
      expect(tierNoIdA.isSameTier(tierNoIdB), isFalse);

      final parsedEvent = Event.fromJson({
        'id': 'evt-json-tiers',
        'title': 'Festival 2 Días',
        'startsAt': DateTime.now().add(const Duration(days: 5)).toIso8601String(),
        'ticketTypes': [
          {'id': 1, 'name': 'General', 'price': 100, 'capacity': 10},
          {'id': 'tier-2', 'name': 'General', 'price': 150, 'capacity': 3},
        ],
      });
      expect(parsedEvent.tiers.length, 2);
      expect(parsedEvent.tiers[0].id, '1');
      expect(parsedEvent.tiers[0].price, 100.0);
      expect(parsedEvent.tiers[1].id, 'tier-2');
      expect(parsedEvent.tiers[1].price, 150.0);
    });

    testWidgets('permite seleccionar entre dos TicketTier con mismo name (price 100 y 150) y actualiza subtotal en EventBottomPurchaseBar', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final duplicateNameEvent = Event(
        id: 'evt-dup-names',
        title: 'Concierto Dos Fechas',
        subtitle: 'Día 1 y Día 2',
        heroImage: '',
        images: [],
        startsAt: DateTime.now().add(const Duration(days: 5)),
        time: '20:00',
        location: 'Teatro al Aire Libre',
        address: 'Av. del Poeta',
        description: ['Dos fechas disponibles'],
        category: 'Música',
        categoryColor: '#EC3013',
        tiers: [
          TicketTier(name: 'General', price: 100.0, capacity: 10),
          TicketTier(name: 'General', price: 150.0, capacity: 8),
        ],
        pricingNotes: [],
        isSoldOut: false,
      );

      await tester.pumpWidget(
        MaterialApp(home: EventDetailScreen(event: duplicateNameEvent)),
      );
      await tester.pumpAndSettle();

      // Incrementar cantidad a 2 -> subtotal inicial 2 * 100 = Bs. 200.00
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(EventBottomPurchaseBar),
          matching: find.text('Bs. 200.00'),
        ),
        findsOneWidget,
      );

      // Tocar el segundo card ('General' de Bs. 150.00)
      await tester.tap(find.text('Bs. 150.00'));
      await tester.pumpAndSettle();

      // Subtotal actualizado a 2 * 150 = Bs. 300.00
      expect(
        find.descendant(
          of: find.byType(EventBottomPurchaseBar),
          matching: find.text('Bs. 300.00'),
        ),
        findsOneWidget,
      );

      // Solo el segundo TierSelectorChip debe estar seleccionado
      final chips = tester.widgetList<TierSelectorChip>(find.byType(TierSelectorChip)).toList();
      expect(chips.length, 2);
      expect(chips[0].isSelected, isFalse);
      expect(chips[1].isSelected, isTrue);
    });

    testWidgets('dos taps consecutivos al mismo objeto TicketTier no disparan cambios ni SnackBar duplicado de ajuste', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final event = Event(
        id: 'evt-same-tap',
        title: 'Show Doble',
        subtitle: '',
        heroImage: '',
        images: [],
        startsAt: DateTime.now().add(const Duration(days: 5)),
        time: '20:00',
        location: 'Coliseo',
        address: 'Centro',
        description: ['Desc'],
        category: 'Música',
        categoryColor: '#EC3013',
        tiers: [
          TicketTier(name: 'General', price: 100.0, capacity: 10),
          TicketTier(name: 'General', price: 150.0, capacity: 2),
        ],
        pricingNotes: [],
        isSoldOut: false,
      );

      await tester.pumpWidget(MaterialApp(home: EventDetailScreen(event: event)));
      await tester.pumpAndSettle();

      // Subir cantidad a 4 en el primer tier
      final inc = find.byIcon(Icons.add_circle_outline);
      await tester.tap(inc);
      await tester.tap(inc);
      await tester.tap(inc);
      await tester.pumpAndSettle();
      expect(find.text('4'), findsOneWidget);

      // 1er tap al segundo tier (capacity: 2) -> ajusta cantidad a 2 y muestra 1 SnackBar
      await tester.tap(find.text('Bs. 150.00'));
      await tester.pump();
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Ajustamos la cantidad a 2 por la capacidad de General'), findsOneWidget);

      // Esperar a que complete la animación de entrada, expire el SnackBar (3s) y salga
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);

      // 2do tap consecutivo sobre el MISMO objeto TicketTier -> no muestra SnackBar ni altera estado
      await tester.tap(find.text('Bs. 150.00'));
      await tester.pump();
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('2'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(EventBottomPurchaseBar),
          matching: find.text('Bs. 300.00'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('cambiar a otro tier con mismo name actualiza la capacity usada por _incrementQuantity y _decrementQuantity', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final event = Event(
        id: 'evt-cap-dup',
        title: 'Festival Por Días',
        subtitle: '',
        heroImage: '',
        images: [],
        startsAt: DateTime.now().add(const Duration(days: 5)),
        time: '19:00',
        location: 'Estadio',
        address: 'Av. Principal',
        description: ['Desc'],
        category: 'Música',
        categoryColor: '#EC3013',
        tiers: [
          TicketTier(id: 'day-1', name: 'General', price: 100.0, capacity: 5),
          TicketTier(id: 'day-2', name: 'General', price: 150.0, capacity: 2),
        ],
        pricingNotes: [],
        isSoldOut: false,
      );

      await tester.pumpWidget(MaterialApp(home: EventDetailScreen(event: event)));
      await tester.pumpAndSettle();

      // Seleccionar el segundo tier ('General', price: 150, capacity: 2)
      await tester.tap(find.text('Bs. 150.00'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(EventBottomPurchaseBar),
          matching: find.text('Bs. 150.00'),
        ),
        findsOneWidget,
      );

      final inc = find.byIcon(Icons.add_circle_outline);
      final dec = find.byIcon(Icons.remove_circle_outline);

      // Incrementar a 2 (permitido por capacity: 2)
      await tester.tap(inc);
      await tester.pump();
      expect(find.text('2'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(EventBottomPurchaseBar),
          matching: find.text('Bs. 300.00'),
        ),
        findsOneWidget,
      );

      // Intentar incrementar a 3 -> bloqueado por capacity: 2 del segundo tier
      await tester.tap(inc);
      await tester.pump();
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Capacidad máxima de General alcanzada'), findsOneWidget);

      // Decrementar a 1 -> subtotal regresa a Bs. 150.00
      await tester.tap(dec);
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(EventBottomPurchaseBar),
          matching: find.text('Bs. 150.00'),
        ),
        findsOneWidget,
      );

      // Volver al primer tier ('General', price: 100, capacity: 5) -> permite subir a 3
      await tester.tap(find.text('Bs. 100.00'));
      await tester.pumpAndSettle();
      await tester.tap(inc);
      await tester.tap(inc);
      await tester.pump();
      expect(find.text('3'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(EventBottomPurchaseBar),
          matching: find.text('Bs. 300.00'),
        ),
        findsOneWidget,
      );
    });
  });
}
