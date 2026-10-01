import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Logotipo oficial de EventHub unificado con la versión web (EventHub_frontend).
/// Tipografía geométrica en dos tonos: "Event" en AppColors.fg y "Hub" en AppColors.accent.
class EventHubLogo extends StatelessWidget {
  final double fontSize;

  const EventHubLogo({
    super.key,
    this.fontSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: 'Event',
        style: TextStyle(
          color: AppColors.fg,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.8,
        ),
        children: [
          TextSpan(
            text: 'Hub',
            style: TextStyle(
              color: AppColors.accent,
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
        ],
      ),
    );
  }
}
