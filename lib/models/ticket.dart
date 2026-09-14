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
  });

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
    };
  }

  factory IssuedTicket.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['purchasedAt'] ?? DateTime.now().toIso8601String());
    } catch (_) {
      parsedDate = DateTime.now();
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
    );
  }
}
