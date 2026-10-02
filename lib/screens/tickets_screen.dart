import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/ticket.dart';
import '../services/storage_service.dart';
import '../widgets/ticket_card.dart';

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  final StorageService _storageService = StorageService();
  late Future<List<IssuedTicket>> _ticketsFuture;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  void _loadTickets() {
    setState(() {
      _ticketsFuture = _storageService.getTickets();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<IssuedTicket>>(
      future: _ticketsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppColors.bg,
            appBar: AppBar(
              backgroundColor: AppColors.bg,
              elevation: 0,
              title: const Text(
                'Mis Entradas',
                style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.fg),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
          );
        }

        final allTickets = snapshot.data ?? [];
        final upcomingTickets = allTickets.where((t) => !t.isPast).toList();
        final pastTickets = allTickets.where((t) => t.isPast).toList();

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: AppColors.bg,
            appBar: AppBar(
              backgroundColor: AppColors.bg,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: const Text(
                'Mis Entradas',
                style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.fg),
                onPressed: () => Navigator.pop(context),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(49),
                child: Column(
                  children: [
                    TabBar(
                      indicatorColor: AppColors.accent,
                      indicatorWeight: 3,
                      labelColor: AppColors.fg,
                      unselectedLabelColor: AppColors.fgMuted,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      tabs: [
                        Tab(text: 'Próximas (${upcomingTickets.length})'),
                        Tab(text: 'Historial (${pastTickets.length})'),
                      ],
                    ),
                    const Divider(height: 1, color: AppColors.border),
                  ],
                ),
              ),
            ),
            body: TabBarView(
              children: [
                _buildTicketsTab(
                  tickets: upcomingTickets,
                  isUpcoming: true,
                ),
                _buildTicketsTab(
                  tickets: pastTickets,
                  isUpcoming: false,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTicketsTab({
    required List<IssuedTicket> tickets,
    required bool isUpcoming,
  }) {
    if (tickets.isEmpty) {
      return RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.bgSoft,
        onRefresh: () async {
          _loadTickets();
          await _ticketsFuture;
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.65,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isUpcoming
                      ? Icons.confirmation_number_outlined
                      : Icons.history_toggle_off,
                  color: AppColors.fgLight,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  isUpcoming
                      ? 'No tenés entradas próximas'
                      : 'Sin historial de eventos pasados',
                  style: const TextStyle(
                    color: AppColors.fg,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  isUpcoming
                      ? 'Tus entradas para eventos activos y futuros aparecerán acá listas para presentar en la puerta.'
                      : 'Las entradas de eventos a los que ya asististe se archivarán automáticamente acá.',
                  style: const TextStyle(color: AppColors.fgMuted, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                if (isUpcoming) ...[
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.accentFg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Explorar Eventos'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.bgSoft,
      onRefresh: () async {
        _loadTickets();
        await _ticketsFuture;
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: tickets.length,
        itemBuilder: (context, index) {
          final ticket = tickets[index];
          if (!isUpcoming) {
            // En la pestaña de historial, atenuar ligeramente para dar contexto de evento concluido
            return Opacity(
              opacity: 0.82,
              child: TicketCard(ticket: ticket),
            );
          }
          return TicketCard(ticket: ticket);
        },
      ),
    );
  }
}
