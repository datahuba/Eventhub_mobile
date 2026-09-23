import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../config/theme.dart';
import '../models/ticket.dart';
import '../services/wallet_pass_service.dart';
import 'wallet_button.dart';

/// Tarjeta de entrada digital con diseño físico de pase (corte perforado, QR criptográfico y botones Wallet).
class TicketCard extends StatelessWidget {
  final IssuedTicket ticket;

  const TicketCard({
    super.key,
    required this.ticket,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Encabezado del ticket con Badge de Sector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              color: AppColors.bgSoft,
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    ticket.eventTitle,
                    style: const TextStyle(
                      color: AppColors.fg,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    ticket.tierName.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.accentFg,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                // Info del Asistente
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TITULAR',
                            style: TextStyle(
                              color: AppColors.fgMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ticket.attendeeName,
                            style: const TextStyle(
                              color: AppColors.fg,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (ticket.attendeeCi.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'C.I. / DOC',
                            style: TextStyle(
                              color: AppColors.fgMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ticket.attendeeCi,
                            style: const TextStyle(
                              color: AppColors.fg,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Fecha y Lugar
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, color: AppColors.accent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ticket.eventDate,
                        style: const TextStyle(color: AppColors.fg, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: AppColors.accent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ticket.eventLocation,
                        style: const TextStyle(color: AppColors.fgMuted, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Separador estilo ticket con líneas punteadas
                Row(
                  children: List.generate(
                    24,
                    (index) => Expanded(
                      child: Container(
                        height: 1.5,
                        color: index % 2 == 0 ? AppColors.borderDark : Colors.transparent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Código QR Criptográfico para Control de Acceso
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.bgSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      QrImageView(
                        data: ticket.qrCode,
                        version: QrVersions.auto,
                        size: 180,
                        backgroundColor: Colors.transparent,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AppColors.fg,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppColors.fg,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Código: ${ticket.qrCode}',
                        style: const TextStyle(
                          color: AppColors.fgMuted,
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Presentá este código en la puerta del evento',
                  style: TextStyle(color: AppColors.fgMuted, fontSize: 12),
                ),
                const SizedBox(height: 18),

                // Botón de integración con Billetera Nativa (Apple Wallet o Google Wallet)
                if (defaultTargetPlatform == TargetPlatform.iOS)
                  AppleWalletButton(
                    onPressed: () async {
                      final ok = await WalletPassService.addToAppleWallet(ticket);
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Generando pase Apple Wallet (.pkpass)...'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  )
                else
                  GoogleWalletButton(
                    onPressed: () async {
                      final ok = await WalletPassService.addToGoogleWallet(ticket);
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vinculando con Google Wallet...'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
