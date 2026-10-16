import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub_mobile/main.dart';
import 'package:eventhub_mobile/widgets/eventhub_logo.dart';

void main() {
  testWidgets('EventHubApp smoke test - renders logo and initial view', (WidgetTester tester) async {
    // Construir la app y disparar un frame inicial
    await tester.pumpWidget(const EventHubApp());

    // Verificar que el nuevo logotipo EventHubLogo se renderiza en la cabecera
    expect(find.byType(EventHubLogo), findsOneWidget);

    // Verificar que el botón de Mis Entradas está presente en la barra superior
    expect(find.byIcon(Icons.confirmation_number_outlined), findsOneWidget);
  });

  testWidgets('EventHubLogo widget test - renders correctly with dual color branding', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EventHubLogo(fontSize: 24),
        ),
      ),
    );

    expect(find.byType(EventHubLogo), findsOneWidget);
    expect(find.byType(RichText), findsOneWidget);
  });
}
