class IssuedTicket {
  final String id;
  final String orderId;
  final String eventTitle;
  final String eventDate;
  final String eventLocation;
  final String tierName;
  final String attendeeName;
  final String attendeeCi;
  final String qrCode;
  final String? imageUrl;
  final String? voucherId;
  final DateTime purchasedAt;
  final DateTime? eventStartsAt;

  IssuedTicket({
    required this.id,
    required this.orderId,
    required this.eventTitle,
    required this.eventDate,
    required this.eventLocation,
    required this.tierName,
    required this.attendeeName,
    required this.attendeeCi,
    required this.qrCode,
    this.imageUrl,
    this.voucherId,
    required this.purchasedAt,
    this.eventStartsAt,
  });

  bool get isPast {
    if (eventStartsAt != null) {
      // Se considera evento pasado si ya transcurrieron 6 horas desde la hora de inicio
      return DateTime.now().isAfter(eventStartsAt!.add(const Duration(hours: 6)));
    }
    // Fallback para entradas antiguas sin eventStartsAt: activas por 7 días tras la compra
    return DateTime.now().difference(purchasedAt).inDays > 7;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderId': orderId,
      'eventTitle': eventTitle,
      'eventDate': eventDate,
      'eventLocation': eventLocation,
      'tierName': tierName,
      'attendeeName': attendeeName,
      'attendeeCi': attendeeCi,
      'qrCode': qrCode,
      'imageUrl': imageUrl,
      'voucherId': voucherId,
      'purchasedAt': purchasedAt.toIso8601String(),
      'eventStartsAt': eventStartsAt?.toIso8601String(),
    };
  }

  factory IssuedTicket.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['purchasedAt'] ?? DateTime.now().toIso8601String());
    } catch (_) {
      parsedDate = DateTime.now();
    }

    DateTime? parsedStartsAt;
    if (json['eventStartsAt'] != null) {
      try {
        parsedStartsAt = DateTime.parse(json['eventStartsAt']);
      } catch (_) {}
    }

    return IssuedTicket(
      id: json['id']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      eventTitle: json['eventTitle']?.toString() ?? 'Evento',
      eventDate: json['eventDate']?.toString() ?? '',
      eventLocation: json['eventLocation']?.toString() ?? '',
      tierName: json['tierName']?.toString() ?? 'General',
      attendeeName: json['attendeeName']?.toString() ?? 'Asistente',
      attendeeCi: json['attendeeCi']?.toString() ?? '',
      qrCode: json['qrCode']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString(),
      voucherId: json['voucherId']?.toString(),
      purchasedAt: parsedDate,
      eventStartsAt: parsedStartsAt,
    );
  }
}
