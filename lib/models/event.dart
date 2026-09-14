import 'package:intl/intl.dart';

class TicketTier {
  final String name;
  final double price;
  final int? capacity;

  TicketTier({
    required this.name,
    required this.price,
    this.capacity,
  });

  factory TicketTier.fromJson(String name, dynamic priceValue, dynamic capacityValue) {
    double price = 0.0;
    if (priceValue is num) {
      price = priceValue.toDouble();
    } else if (priceValue is String) {
      price = double.tryParse(priceValue) ?? 0.0;
    }

    int? capacity;
    if (capacityValue is int) {
      capacity = capacityValue;
    }

    return TicketTier(
      name: name,
      price: price,
      capacity: capacity,
    );
  }
}

class Event {
  final String id;
  final String title;
  final String subtitle;
  final String heroImage;
  final List<String> images;
  final DateTime startsAt;
  final String time;
  final String location;
  final String address;
  final List<String> description;
  final String category;
  final String categoryColor;
  final List<TicketTier> tiers;
  final List<String> pricingNotes;
  final bool isSoldOut;

  Event({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.heroImage,
    required this.images,
    required this.startsAt,
    required this.time,
    required this.location,
    required this.address,
    required this.description,
    required this.category,
    required this.categoryColor,
    required this.tiers,
    required this.pricingNotes,
    required this.isSoldOut,
  });

  /// Retorna el precio mínimo entre los sectores disponibles
  double get minPrice {
    if (tiers.isEmpty) return 0.0;
    return tiers.map((t) => t.price).reduce((a, b) => a < b ? a : b);
  }

  /// Fecha formateada amigable (ej: "25 de Octubre, 2026")
  String get formattedDate {
    try {
      final formatter = DateFormat("d 'de' MMMM, y", 'es');
      return formatter.format(startsAt);
    } catch (_) {
      return '${startsAt.day}/${startsAt.month}/${startsAt.year}';
    }
  }

  /// Fecha corta (ej: "25 OCT")
  String get shortDate {
    try {
      final day = startsAt.day.toString().padLeft(2, '0');
      final month = DateFormat('MMM', 'es').format(startsAt).toUpperCase().replaceAll('.', '');
      return '$day $month';
    } catch (_) {
      return '${startsAt.day}/${startsAt.month}';
    }
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    DateTime parsedStartsAt;
    try {
      parsedStartsAt = DateTime.parse(json['startsAt'] ?? DateTime.now().toIso8601String());
    } catch (_) {
      parsedStartsAt = DateTime.now();
    }

    final rawImages = json['images'];
    final List<String> imagesList = rawImages is List
        ? rawImages.map((e) => e.toString()).toList()
        : [];

    final rawDesc = json['description'];
    final List<String> descList = rawDesc is List
        ? rawDesc.map((e) => e.toString()).toList()
        : (rawDesc is String ? [rawDesc] : []);

    final rawNotes = json['pricingNotes'];
    final List<String> notesList = rawNotes is List
        ? rawNotes.map((e) => e.toString()).toList()
        : [];

    // Mapear pricingTiers y tierCapacities
    final List<TicketTier> parsedTiers = [];
    final rawPricingTiers = json['pricingTiers'];
    final rawTierCapacities = json['tierCapacities'];

    if (rawPricingTiers is Map<String, dynamic>) {
      rawPricingTiers.forEach((tierName, priceVal) {
        dynamic capVal;
        if (rawTierCapacities is Map<String, dynamic>) {
          capVal = rawTierCapacities[tierName];
        }
        parsedTiers.add(TicketTier.fromJson(tierName, priceVal, capVal));
      });
    }

    return Event(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Sin título',
      subtitle: json['subtitle']?.toString() ?? '',
      heroImage: json['heroImage']?.toString() ?? '',
      images: imagesList,
      startsAt: parsedStartsAt,
      time: json['time']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      description: descList,
      category: json['category']?.toString() ?? 'General',
      categoryColor: json['categoryColor']?.toString() ?? '#EC3013',
      tiers: parsedTiers,
      pricingNotes: notesList,
      isSoldOut: json['soldOut'] == true,
    );
  }
}
