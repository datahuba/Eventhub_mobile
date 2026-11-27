import 'package:intl/intl.dart';
import '../config/api_config.dart';

class TicketTier {
  final String? id;
  final String name;
  final double price;
  final int? capacity;

  TicketTier({
    this.id,
    required this.name,
    required this.price,
    this.capacity,
  });

  /// Indica si ambos objetos representan el mismo sector/tier.
  /// Compara por [id] cuando ambos están presentes y usa [identical] como fallback.
  bool isSameTier(TicketTier other) {
    if (identical(this, other)) return true;
    final currentId = id?.trim();
    final otherId = other.id?.trim();
    if (currentId != null &&
        currentId.isNotEmpty &&
        otherId != null &&
        otherId.isNotEmpty) {
      return currentId == otherId;
    }
    return false;
  }

  static double _parsePrice(dynamic priceValue) {
    if (priceValue is num) {
      return priceValue.toDouble();
    }
    if (priceValue is String) {
      return double.tryParse(priceValue) ?? 0.0;
    }
    return 0.0;
  }

  static int? _parseCapacity(dynamic capacityValue) {
    if (capacityValue is int) return capacityValue;
    if (capacityValue is num) return capacityValue.toInt();
    if (capacityValue is String) return int.tryParse(capacityValue);
    return null;
  }

  static String? _parseId(dynamic idValue) {
    final raw = idValue?.toString().trim();
    return (raw != null && raw.isNotEmpty) ? raw : null;
  }

  factory TicketTier.fromJson(
    String name,
    dynamic priceValue,
    dynamic capacityValue, {
    dynamic idValue,
  }) {
    return TicketTier(
      id: _parseId(idValue),
      name: name,
      price: _parsePrice(priceValue),
      capacity: _parseCapacity(capacityValue),
    );
  }

  factory TicketTier.fromMap(Map<String, dynamic> map) {
    return TicketTier(
      id: _parseId(map['id']),
      name: map['name']?.toString() ?? 'General',
      price: _parsePrice(map['price']),
      capacity: _parseCapacity(map['capacity']),
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

  /// Indica si el evento ya concluyó (más de 6 horas transcurridas desde startsAt)
  bool get isPast => DateTime.now().isAfter(startsAt.add(const Duration(hours: 6)));

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

  /// Normaliza URLs relativas (/images/...) a URLs absolutas alcanzables por la app
  static String resolveUrl(String? rawUrl) {
    if (rawUrl == null) return '';
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) {
      if (trimmed.startsWith('/images/')) {
        return '${ApiConfig.webBaseUrl}$trimmed';
      }
      return '${ApiConfig.backendHost}$trimmed';
    }
    return trimmed;
  }

  /// Retorna la imagen de cabecera normalizada o la primera foto de la galería como fallback
  String get displayHeroImage {
    final resolvedHero = resolveUrl(heroImage);
    if (resolvedHero.isNotEmpty) return resolvedHero;
    for (final img in images) {
      final resolved = resolveUrl(img);
      if (resolved.isNotEmpty) return resolved;
    }
    return '';
  }

  /// Retorna la lista de fotos de la galería normalizadas
  List<String> get displayImages {
    final list = <String>[];
    for (final img in images) {
      final resolved = resolveUrl(img);
      if (resolved.isNotEmpty && !list.contains(resolved)) {
        list.add(resolved);
      }
    }
    return list;
  }

  /// Retorna todas las fotos del evento (Hero + Galería) sin duplicados
  List<String> get allPhotos {
    final list = <String>[];
    final hero = displayHeroImage;
    if (hero.isNotEmpty) {
      list.add(hero);
    }
    for (final img in displayImages) {
      if (!list.contains(img)) {
        list.add(img);
      }
    }
    return list;
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

    // Mapear ticketTypes (lista con id explícito) o pricingTiers + tierCapacities
    final List<TicketTier> parsedTiers = [];
    final rawTicketTypes = json['ticketTypes'] ?? json['tiers'];
    if (rawTicketTypes is List) {
      for (final item in rawTicketTypes) {
        if (item is Map<String, dynamic>) {
          parsedTiers.add(TicketTier.fromMap(item));
        }
      }
    }

    final rawPricingTiers = json['pricingTiers'];
    final rawTierCapacities = json['tierCapacities'];
    final rawTierIds = json['tierIds'];

    if (parsedTiers.isEmpty && rawPricingTiers is Map<String, dynamic>) {
      rawPricingTiers.forEach((tierName, priceVal) {
        dynamic capVal;
        if (rawTierCapacities is Map<String, dynamic>) {
          capVal = rawTierCapacities[tierName];
        }
        dynamic idVal;
        if (rawTierIds is Map<String, dynamic>) {
          idVal = rawTierIds[tierName];
        }
        parsedTiers.add(
          TicketTier.fromJson(tierName, priceVal, capVal, idValue: idVal),
        );
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
