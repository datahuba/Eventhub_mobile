import 'package:flutter/material.dart';
import '../models/event.dart';
import '../widgets/tier_chip.dart';
import 'checkout_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final Event event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late TicketTier? _selectedTier;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    if (widget.event.tiers.isNotEmpty) {
      _selectedTier = widget.event.tiers.first;
    } else {
      _selectedTier = null;
    }
  }

  double get _totalPrice {
    if (_selectedTier == null) return 0.0;
    return _selectedTier!.price * _quantity;
  }

  void _incrementQuantity() {
    final maxCap = _selectedTier?.capacity;
    if (maxCap != null && _quantity >= maxCap) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Capacidad máxima de ${_selectedTier!.name} alcanzada'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (_quantity < 10) {
      setState(() => _quantity++);
    }
  }

  void _decrementQuantity() {
    if (_quantity > 1) {
      setState(() => _quantity--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: CustomScrollView(
        slivers: [
          // Imagen Hero con botón atrás
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: const Color(0xFF181818),
            leading: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: event.heroImage.isNotEmpty
                  ? Image.network(
                      event.heroImage,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFF252525),
                        child: const Icon(Icons.broken_image, color: Colors.white38, size: 60),
                      ),
                    )
                  : Container(
                      color: const Color(0xFF252525),
                      child: const Icon(Icons.event, color: Colors.white38, size: 60),
                    ),
            ),
          ),

          // Contenido descriptivo y selector de tickets
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Categoría
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEC3013).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFEC3013), width: 0.8),
                    ),
                    child: Text(
                      event.category.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFFEC3013),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Título
                  Text(
                    event.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  if (event.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      event.subtitle,
                      style: const TextStyle(color: Colors.white70, fontSize: 15),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Info pills: Fecha y Ubicación
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2A2A2A)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, color: Color(0xFFEC3013), size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.formattedDate,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                  if (event.time.isNotEmpty)
                                    Text(
                                      'Hora: ${event.time}',
                                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(color: Color(0xFF2A2A2A), height: 1),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, color: Color(0xFFEC3013), size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.location.isNotEmpty ? event.location : 'Por confirmar',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                  if (event.address.isNotEmpty)
                                    Text(
                                      event.address,
                                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Descripción
                  if (event.description.isNotEmpty) ...[
                    const Text(
                      'Acerca de este evento',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    ...event.description.map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          p,
                          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Selección de Sectores (Tiers)
                  const Text(
                    'Seleccioná tu sector',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  if (event.tiers.isEmpty)
                    const Text(
                      'No hay sectores configurados para este evento.',
                      style: TextStyle(color: Colors.white54),
                    )
                  else
                    ...event.tiers.map(
                      (tier) => TierSelectorChip(
                        tier: tier,
                        isSelected: _selectedTier?.name == tier.name,
                        onTap: () {
                          setState(() {
                            _selectedTier = tier;
                            _quantity = 1;
                          });
                        },
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Selector de cantidad
                  if (_selectedTier != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2A2A2A)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Cantidad de entradas',
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: _decrementQuantity,
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.white70),
                              ),
                              Text(
                                '$_quantity',
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                onPressed: _incrementQuantity,
                                icon: const Icon(Icons.add_circle_outline, color: Color(0xFFEC3013)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 100), // Espacio para el bottom bar
                ],
              ),
            ),
          ),
        ],
      ),

      // Barra inferior fija con precio total y botón de compra
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0xFF181818),
          border: Border(top: BorderSide(color: Color(0xFF2A2A2A), width: 1)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total a pagar', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  Text(
                    'Bs. ${_totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFFEC3013),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: ElevatedButton(
                  onPressed: _selectedTier == null || event.isSoldOut
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CheckoutScreen(
                                event: event,
                                selectedTier: _selectedTier!,
                                quantity: _quantity,
                              ),
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEC3013),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white12,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Comprar Entradas',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
