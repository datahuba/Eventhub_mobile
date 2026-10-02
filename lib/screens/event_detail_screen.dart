import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/event.dart';
import '../widgets/tier_chip.dart';
import '../widgets/event_bottom_purchase_bar.dart';
import '../widgets/event_info_card.dart';
import '../widgets/quantity_selector.dart';
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
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (_quantity < 10) {
      setState(() => _quantity++);
    }
  }

  int _headerPhotoIndex = 0;

  void _decrementQuantity() {
    if (_quantity > 1) {
      setState(() => _quantity--);
    }
  }

  void _openFullscreenGallery(BuildContext context, List<String> photos, int initialIndex) {
    if (photos.isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, _, __) {
          int currentIndex = initialIndex;
          return StatefulBuilder(
            builder: (context, setModalState) {
              return Scaffold(
                backgroundColor: Colors.black.withValues(alpha: 0.95),
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: Text(
                    '${currentIndex + 1} de ${photos.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  centerTitle: true,
                ),
                body: PageView.builder(
                  itemCount: photos.length,
                  controller: PageController(initialPage: initialIndex),
                  onPageChanged: (index) {
                    setModalState(() {
                      currentIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return Center(
                      child: InteractiveViewer(
                        clipBehavior: Clip.none,
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: CachedNetworkImage(
                          imageUrl: photos[index],
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(color: AppColors.accent),
                          ),
                          errorWidget: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final photos = event.allPhotos;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // Imagen Hero con botón atrás y soporte multicarrusel si hay varias fotos
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: AppColors.bg,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.white.withValues(alpha: 0.9),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.fg, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: photos.isNotEmpty
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        GestureDetector(
                          onTap: () => _openFullscreenGallery(context, photos, _headerPhotoIndex),
                          child: PageView.builder(
                            itemCount: photos.length,
                            onPageChanged: (index) {
                              setState(() {
                                _headerPhotoIndex = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              return CachedNetworkImage(
                                imageUrl: photos[index],
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: AppColors.bgSoft,
                                  child: const Center(
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: AppColors.bgSoft,
                                  child: const Icon(Icons.broken_image, color: AppColors.fgLight, size: 56),
                                ),
                              );
                            },
                          ),
                        ),
                        // Gradiente inferior para legibilidad del contenido
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: 60,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.6),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Indicador de foto actual si hay más de 1
                        if (photos.length > 1)
                          Positioned(
                            bottom: 12,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.photo_library, color: Colors.white, size: 13),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${_headerPhotoIndex + 1} / ${photos.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    )
                  : Container(
                      color: AppColors.bgSoft,
                      child: const Icon(Icons.event, color: AppColors.fgLight, size: 56),
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
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.3), width: 1),
                    ),
                    child: Text(
                      event.category.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.accent,
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
                      color: AppColors.fg,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  if (event.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      event.subtitle,
                      style: const TextStyle(color: AppColors.fgMuted, fontSize: 15),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Info card: Fecha y Ubicación (modularizado)
                  EventInfoCard(event: event),
                  const SizedBox(height: 24),

                  // Descripción
                  if (event.description.isNotEmpty) ...[
                    const Text(
                      'Acerca de este evento',
                      style: TextStyle(color: AppColors.fg, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    ...event.description.map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          p,
                          style: const TextStyle(color: AppColors.fg, fontSize: 14, height: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Galería de fotos del evento
                  if (photos.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'Fotos del evento',
                          style: TextStyle(color: AppColors.fg, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${photos.length} foto${photos.length > 1 ? 's' : ''}',
                          style: const TextStyle(color: AppColors.fgMuted, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 130,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: photos.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final photoUrl = photos[index];
                          return GestureDetector(
                            onTap: () => _openFullscreenGallery(context, photos, index),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Stack(
                                children: [
                                  AspectRatio(
                                    aspectRatio: 16 / 10,
                                    child: CachedNetworkImage(
                                      imageUrl: photoUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: AppColors.bgSoft,
                                        width: 150,
                                        child: const Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        color: AppColors.bgSoft,
                                        width: 150,
                                        child: const Icon(Icons.broken_image, color: AppColors.fgLight),
                                      ),
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => _openFullscreenGallery(context, photos, index),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Selección de Sectores (Tiers)
                  const Text(
                    'Seleccioná tu sector',
                    style: TextStyle(color: AppColors.fg, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  if (event.tiers.isEmpty)
                    const Text(
                      'No hay sectores configurados para este evento.',
                      style: TextStyle(color: AppColors.fgMuted),
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

                  // Selector de cantidad (modularizado)
                  if (_selectedTier != null)
                    QuantitySelector(
                      quantity: _quantity,
                      onIncrement: _incrementQuantity,
                      onDecrement: _decrementQuantity,
                    ),
                  const SizedBox(height: 100), // Espacio para el bottom bar
                ],
              ),
            ),
          ),
        ],
      ),

      // Barra inferior fija con precio total y botón de compra (modularizada)
      bottomSheet: EventBottomPurchaseBar(
        totalPrice: _totalPrice,
        isPast: event.isPast,
        isSoldOut: event.isSoldOut,
        hasSelectedTier: _selectedTier != null,
        onPurchase: () {
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
      ),
    );
  }
}
