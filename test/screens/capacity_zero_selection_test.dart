import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub_mobile/models/event.dart';
import 'package:eventhub_mobile/screens/event_detail_screen.dart';
import 'package:eventhub_mobile/widgets/event_bottom_purchase_bar.dart';
import 'package:eventhub_mobile/widgets/tier_chip.dart';

void main() {
  group('Pruebas de Sector con Capacidad 0 y Manejo de Agotados', () {
    test('clampQuantityForTier retorna estrictamente 0 cuando la capacidad es 0', () {
      final tierAgotado = TicketTier(name: 'VIP Agotado', price: 200.0, capacity: 0);
      final tierNegativo = TicketTier(name: 'VIP Error', price: 200.0, capacity: -5);
      final tierNormal = TicketTier(name: 'General', price: 100.0, capacity: 5);

      expect(EventDetailScreen.clampQuantityForTier(5, tierAgotado), 0);
      expect(EventDetailScreen.clampQuantityForTier(1, tierAgotado), 0);
      expect(EventDetailScreen.clampQuantityForTier(0, tierAgotado), 0);

      expect(EventDetailScreen.clampQuantityForTier(5, tierNegativo), 0);
      expect(EventDetailScreen.clampQuantityForTier(5, tierNormal), 5);
    });

    test('maxQuantityForTier retorna 0 para sectores con capacidad 0', () {
      final tierAgotado = TicketTier(name: 'VIP', price: 150.0, capacity: 0);
      expect(EventDetailScreen.maxQuantityForTier(tierAgotado), 0);
    });

    testWidgets('TierSelectorChip muestra "Agotado" y deshabilita onTap cuando capacity es 0', (tester) async {
      bool tapped = false;
      final tierAgotado = TicketTier(name: 'Sector Palco', price: 250.0, capacity: 0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TierSelectorChip(
              tier: tierAgotado,
              isSelected: false,
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Sector Palco'), findsOneWidget);
      expect(find.text('Agotado'), findsOneWidget);

      // Al tocar un chip agotado, no debe disparar onTap
      await tester.tap(find.text('Sector Palco'));
      await tester.pumpAndSettle();

      expect(tapped, isFalse);
    });

    testWidgets('EventDetailScreen con evento donde todos los sectores tienen capacidad 0 bloquea compra', (tester) async {
      final eventoSinCupos = Event(
        id: 'evt-full',
        title: 'Festival Sin Entradas',
        subtitle: 'Todo vendido',
        heroImage: '',
        images: [],
        startsAt: DateTime.now().add(const Duration(days: 5)),
        time: '21:00',
        location: 'Estadio',
        address: 'Av. Siempre Viva 123',
        description: ['Gran festival agotado'],
        category: 'Concierto',
        categoryColor: '#FF0000',
        tiers: [
          TicketTier(name: 'VIP', price: 300.0, capacity: 0),
          TicketTier(name: 'General', price: 100.0, capacity: 0),
        ],
        pricingNotes: [],
        isSoldOut: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EventDetailScreen(event: eventoSinCupos),
        ),
      );
      await tester.pumpAndSettle();

      // Debe mostrarse el texto 'Sector Agotado' en la barra inferior
      expect(find.text('Sector Agotado'), findsOneWidget);
      expect(find.text('Agotado'), findsNWidgets(2));

      // El botón de compra en la barra inferior debe estar deshabilitado
      final botonCompra = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Sector Agotado'),
      );
      expect(botonCompra.onPressed, isNull);
    });

    testWidgets('EventBottomPurchaseBar bloquea la compra cuando isTierSoldOut es true', (tester) async {
      bool purchaseTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomSheet: EventBottomPurchaseBar(
              totalPrice: 0.0,
              isPast: false,
              isSoldOut: false,
              isTierSoldOut: true,
              hasSelectedTier: true,
              onPurchase: () {
                purchaseTriggered = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Sector Agotado'), findsOneWidget);
      expect(find.text('Bs. 0.00'), findsOneWidget);

      final boton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Sector Agotado'),
      );
      expect(boton.onPressed, isNull);

      await tester.tap(find.text('Sector Agotado'));
      await tester.pumpAndSettle();
      expect(purchaseTriggered, isFalse);
    });
  });
}
