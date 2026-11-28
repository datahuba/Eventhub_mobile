class BnbQrResponse {
  final bool success;
  final String orderId;
  final String qrId;
  final String qrBase64;
  final double totalAmount;
  final String currency;
  final String eventTitle;
  final String tier;
  final int quantity;
  final DateTime? expiresAt;
  final int? expiresInSeconds;

  BnbQrResponse({
    required this.success,
    required this.orderId,
    required this.qrId,
    required this.qrBase64,
    required this.totalAmount,
    required this.currency,
    required this.eventTitle,
    required this.tier,
    required this.quantity,
    this.expiresAt,
    this.expiresInSeconds,
  });

  /// Calcula los segundos restantes para la vigencia de la orden BNB.
  int resolveRemainingSeconds({int defaultSeconds = 15 * 60}) {
    if (expiresAt != null) {
      final diffMs = expiresAt!.difference(DateTime.now()).inMilliseconds;
      return diffMs <= 0 ? 0 : (diffMs / 1000).ceil();
    }
    if (expiresInSeconds != null) {
      return expiresInSeconds! <= 0 ? 0 : expiresInSeconds!;
    }
    return defaultSeconds;
  }

  factory BnbQrResponse.fromJson(Map<String, dynamic> json) {
    double parsedAmount = 0.0;
    if (json['totalAmount'] is num) {
      parsedAmount = (json['totalAmount'] as num).toDouble();
    } else if (json['totalAmount'] is String) {
      parsedAmount = double.tryParse(json['totalAmount']) ?? 0.0;
    }

    DateTime? parsedExpiresAt;
    if (json['expiresAt'] != null) {
      parsedExpiresAt = DateTime.tryParse(json['expiresAt'].toString());
    }

    int? parsedExpiresIn;
    final rawTtl = json['expiresInSeconds'] ?? json['ttlSeconds'];
    if (rawTtl is int) {
      parsedExpiresIn = rawTtl;
    } else if (rawTtl is num) {
      parsedExpiresIn = rawTtl.toInt();
    } else if (rawTtl is String) {
      parsedExpiresIn = int.tryParse(rawTtl);
    }

    return BnbQrResponse(
      success: json['success'] == true,
      orderId: json['orderId']?.toString() ?? '',
      qrId: json['qrId']?.toString() ?? '',
      qrBase64: json['qrBase64']?.toString() ?? '',
      totalAmount: parsedAmount,
      currency: json['currency']?.toString() ?? 'BOB',
      eventTitle: json['eventTitle']?.toString() ?? '',
      tier: json['tier']?.toString() ?? '',
      quantity: json['quantity'] is int ? json['quantity'] : 1,
      expiresAt: parsedExpiresAt,
      expiresInSeconds: parsedExpiresIn,
    );
  }
}

enum PaymentVerificationStatus {
  pending,
  completed,
  expired,
  failed,
}

class BnbStatusResponse {
  final PaymentVerificationStatus status;
  final String orderId;
  final String? voucherId;
  final String message;
  final List<dynamic>? attendeesRaw;

  BnbStatusResponse({
    required this.status,
    required this.orderId,
    this.voucherId,
    required this.message,
    this.attendeesRaw,
  });

  factory BnbStatusResponse.fromJson(Map<String, dynamic> json) {
    final statusStr = (json['status']?.toString() ?? '').toUpperCase();
    PaymentVerificationStatus parsedStatus = PaymentVerificationStatus.failed;

    if (statusStr == 'COMPLETED') {
      parsedStatus = PaymentVerificationStatus.completed;
    } else if (statusStr == 'PENDING') {
      parsedStatus = PaymentVerificationStatus.pending;
    } else if (statusStr == 'EXPIRED') {
      parsedStatus = PaymentVerificationStatus.expired;
    }

    return BnbStatusResponse(
      status: parsedStatus,
      orderId: json['orderId']?.toString() ?? '',
      voucherId: json['voucherId']?.toString(),
      message: json['message']?.toString() ?? '',
      attendeesRaw: json['attendees'] is List ? json['attendees'] : null,
    );
  }
}
