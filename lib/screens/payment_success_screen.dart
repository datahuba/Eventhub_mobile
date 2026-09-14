import 'package:flutter/material.dart';
import '../models/event.dart';
import '../models/ticket.dart';
import 'tickets_screen.dart';

class PaymentSuccessScreen extends StatelessWidget {
  final Event event;
  final List<IssuedTicket> tickets;
  final String? voucherId;

  const PaymentSuccessScreen({
    super.key,
    required this.event,
    required this.tickets,
    this.voucherId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),

              // Icono de éxito
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: const Icon(Icons.check, color: Colors.green, size: 54),
              ),
              const SizedBox(height: 24),

              const Text(
                '¡Pago Acreditado!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tus entradas han sido generadas y guardadas automáticamente en tu teléfono.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              // Tarjeta informativa del pedido
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2C2C2C)),
                ),
                child: Column(
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFF2C2C2C), height: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Entradas generadas:', style: TextStyle(color: Colors.white54, fontSize: 13)),
                        Text(
                          '${tickets.length} ticket${tickets.length > 1 ? 's' : ''}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Sector:', style: TextStyle(color: Colors.white54, fontSize: 13)),
                        Text(
                          tickets.isNotEmpty ? tickets.first.tierName : 'General',
                          style: const TextStyle(color: Color(0xFFEC3013), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (voucherId != null && voucherId!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Voucher BNB:', style: TextStyle(color: Colors.white54, fontSize: 13)),
                          Text(
                            voucherId!,
                            style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const Spacer(),

              // Botón "Ver mis entradas"
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const TicketsScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEC3013),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.confirmation_number_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Ver mis entradas ahora', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Botón "Volver al inicio"
              TextButton(
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: const Text('Volver al catálogo', style: TextStyle(color: Colors.white54)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
