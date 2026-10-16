import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../config/theme.dart';

class BnbQrContainer extends StatelessWidget {
  final Uint8List? qrBytes;

  const BnbQrContainer({
    super.key,
    required this.qrBytes,
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
            if (qrBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  qrBytes!,
                  width: 240,
                  height: 240,
                  fit: BoxFit.contain,
                ),
              )
            else
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
        ),
      ),
    );
  }
}
