import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ticket.dart';

class StorageService {
  static const String _ticketsKey = 'eventhub_stored_tickets';

  /// Guarda nuevos tickets emitidos en la billetera local del dispositivo
  Future<void> saveTickets(List<IssuedTicket> newTickets) async {
    final prefs = await SharedPreferences.getInstance();
    final existingTickets = await getTickets();

    // Evitar duplicados por ID de entrada
    final existingIds = existingTickets.map((t) => t.id).toSet();
    final toAdd = newTickets.where((t) => !existingIds.contains(t.id)).toList();

    final updated = [...toAdd, ...existingTickets];
    final encoded = updated.map((t) => jsonEncode(t.toJson())).toList();

    await prefs.setStringList(_ticketsKey, encoded);
  }

  /// Recupera todas las entradas guardadas en la billetera offline
  Future<List<IssuedTicket>> getTickets() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_ticketsKey);

    if (rawList == null || rawList.isEmpty) {
      return [];
    }

    final List<IssuedTicket> tickets = [];
    for (final raw in rawList) {
      try {
        final decoded = jsonDecode(raw);
        tickets.add(IssuedTicket.fromJson(decoded as Map<String, dynamic>));
      } catch (e) {
        // Ignorar entradas corruptas
      }
    }

    // Ordenar de más reciente a más antigua
    tickets.sort((a, b) => b.purchasedAt.compareTo(a.purchasedAt));
    return tickets;
  }

  /// Limpia la billetera (útil para pruebas)
  Future<void> clearAllTickets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ticketsKey);
  }
}
