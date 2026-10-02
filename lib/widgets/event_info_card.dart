import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/event.dart';

class EventInfoCard extends StatelessWidget {
  final Event event;

  const EventInfoCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                color: AppColors.accent,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.formattedDate,
                      style: const TextStyle(
                        color: AppColors.fg,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (event.time.isNotEmpty)
                      Text(
                        'Hora: ${event.time}',
                        style: const TextStyle(
                          color: AppColors.fgMuted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: AppColors.border, height: 1),
          ),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: AppColors.accent,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.location.isNotEmpty ? event.location : 'Por confirmar',
                      style: const TextStyle(
                        color: AppColors.fg,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (event.address.isNotEmpty)
                      Text(
                        event.address,
                        style: const TextStyle(
                          color: AppColors.fgMuted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
