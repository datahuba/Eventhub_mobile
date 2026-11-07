class BnbQrResponse {
  final bool success;
  final String orderId;
  final String? token;
  final String qrId;
  final String qrBase64;
  final double totalAmount;
  final String currency;
  final String eventTitle;
  final String tier;
  final int quantity;
  final String? expiresAt;

  String? get orderToken => token;
  String get qrImageBase64 => qrBase64;

  BnbQrResponse({
    required this.success,
    required this.orderId,
    this.token,
    required this.qrId,
    required this.qrBase64,
    required this.totalAmount,
    required this.currency,
    required this.eventTitle,
    required this.tier,
    required this.quantity,
    this.expiresAt,
  });

  factory BnbQrResponse.fromJson(Map<String, dynamic> json) {
    double parsedAmount = 0.0;
    final rawAmount = json['totalAmount'] ?? json['amount'];
    if (rawAmount is num) {
      parsedAmount = rawAmount.toDouble();
    } else if (rawAmount is String) {
      parsedAmount = double.tryParse(rawAmount) ?? 0.0;
    }

    final parsedToken = (json['orderToken'] ?? json['token'])?.toString();
    final parsedQrBase64 = (json['qrImageBase64'] ?? json['qrBase64'] ?? json['qrImage'])?.toString() ?? '';

    return BnbQrResponse(
      success: json['success'] == true || (json['orderId'] != null && parsedQrBase64.isNotEmpty),
      orderId: json['orderId']?.toString() ?? '',
      token: parsedToken,
      qrId: json['qrId']?.toString() ?? '',
      qrBase64: parsedQrBase64,
      totalAmount: parsedAmount,
      currency: json['currency']?.toString() ?? 'BOB',
      eventTitle: json['eventTitle']?.toString() ?? '',
      tier: json['tier']?.toString() ?? '',
      quantity: json['quantity'] is int ? json['quantity'] : 1,
      expiresAt: json['expiresAt']?.toString(),
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
  final String? expiresAt;
  final String? paidAt;
  final bool? ticketsReady;

  BnbStatusResponse({
    required this.status,
    required this.orderId,
    this.voucherId,
    required this.message,
    this.attendeesRaw,
    this.expiresAt,
    this.paidAt,
    this.ticketsReady,
  });

  factory BnbStatusResponse.fromJson(Map<String, dynamic> json, {String? fallbackOrderId}) {
    final statusStr = (json['status']?.toString() ?? json['paymentStatus']?.toString() ?? '').toUpperCase();
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
      orderId: json['orderId']?.toString() ?? fallbackOrderId ?? '',
      voucherId: json['voucherId']?.toString(),
      message: json['message']?.toString() ?? '',
      attendeesRaw: json['attendees'] is List ? json['attendees'] : null,
      expiresAt: json['expiresAt']?.toString(),
      paidAt: json['paidAt']?.toString(),
      ticketsReady: json['ticketsReady'] is bool ? json['ticketsReady'] as bool : null,
    );
  }
}
