import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../config/theme.dart';

class BnbQrContainer extends StatelessWidget {
  final Uint8List? qrBytes;
  final bool isFailed;
  final VoidCallback? onRetry;
  final bool isRetrying;
  final bool retryFailed;

  const BnbQrContainer({
    super.key,
    required this.qrBytes,
    this.isFailed = false,
    this.onRetry,
    this.isRetrying = false,
    this.retryFailed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            if (isFailed) ...[
              Container(
                width: 240,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'No pudimos generar el código QR del banco. Tocá Reintentar para volver a pedirlo.',
                      style: TextStyle(
                        color: AppColors.fg,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: isRetrying ? null : onRetry,
                      icon: isRetrying
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.refresh, size: 16),
                      label: Text(isRetrying ? 'Reintentando...' : 'Reintentar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.accentFg,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                    if (retryFailed) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Reintento fallido. Probá más tarde o contactá a soporte.',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ] else if (qrBytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  qrBytes!,
                  width: 240,
                  height: 240,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Escaneá con cualquier app bancaria',
                style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ] else ...[
              const SizedBox(
                width: 240,
                height: 240,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Escaneá con cualquier app bancaria',
                style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
