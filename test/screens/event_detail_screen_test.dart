import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub_mobile/models/event.dart';
import 'package:eventhub_mobile/screens/event_detail_screen.dart';
import 'package:eventhub_mobile/widgets/event_bottom_purchase_bar.dart';

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

    test('EventDetailScreen.clampQuantityForTier: mantiene la cantidad si la capacidad es null o 0 (sin tope)', () {
      final tierUnlimited = TicketTier(name: 'General', price: 100.0, capacity: null);
      final tierZeroCap = TicketTier(name: 'Libre', price: 50.0, capacity: 0);

      expect(EventDetailScreen.clampQuantityForTier(7, tierUnlimited), 7);
      expect(EventDetailScreen.clampQuantityForTier(8, tierZeroCap), 8);
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
    test('EventDetailScreen.maxQuantityForTier: evalúa correctamente capacidades null, 3, 10 y 50', () {
      final tierNull = TicketTier(name: 'General', price: 100.0, capacity: null);
      final tier3 = TicketTier(name: 'VIP 3', price: 200.0, capacity: 3);
      final tier10 = TicketTier(name: 'Sector 10', price: 150.0, capacity: 10);
      final tier50 = TicketTier(name: 'Platea 50', price: 80.0, capacity: 50);

      expect(EventDetailScreen.maxQuantityForTier(tierNull), 10);
      expect(EventDetailScreen.maxQuantityForTier(tier3), 3);
      expect(EventDetailScreen.maxQuantityForTier(tier10), 10);
      expect(EventDetailScreen.maxQuantityForTier(tier50), 50);
      expect(EventDetailScreen.maxQuantityForTier(null), 10);
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

    testWidgets('Widget EventDetailScreen: sector con capacity: 50 permite superar 10 hasta llegar a 50 y muestra SnackBar', (WidgetTester tester) async {
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

      // Incrementar hasta 15 (superando el antiguo límite rígido de 10)
      for (int i = 0; i < 14; i++) {
        await tester.tap(incrementFinder);
        await tester.pump();
      }
      expect(find.text('15'), findsOneWidget);
      expect(find.text('Capacidad máxima de Platea alcanzada'), findsNothing);

      // Incrementar hasta 50 (35 veces más)
      for (int i = 0; i < 35; i++) {
        await tester.tap(incrementFinder);
        await tester.pump();
      }
      expect(find.text('50'), findsOneWidget);
      expect(find.text('Capacidad máxima de Platea alcanzada'), findsNothing);

      // Intento de superar 50 -> muestra SnackBar y se queda en 50
      await tester.tap(incrementFinder);
      await tester.pump();

      expect(find.text('50'), findsOneWidget);
      expect(find.text('Capacidad máxima de Platea alcanzada'), findsOneWidget);
    });
  });
}
