import 'package:flutter/material.dart';
import '../config/theme.dart';

class AppleWalletButton extends StatelessWidget {
  final VoidCallback onPressed;

  const AppleWalletButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Colors.black),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wallet, color: Colors.white, size: 22),
            SizedBox(width: 10),
            Text(
              'Añadir a Apple Wallet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GoogleWalletButton extends StatelessWidget {
  final VoidCallback onPressed;

  const GoogleWalletButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.bg,
          foregroundColor: AppColors.fg,
          elevation: 0,
          side: const BorderSide(color: AppColors.border, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet, color: Color(0xFF4285F4), size: 22),
            SizedBox(width: 10),
            Text(
              'Añadir a Google Wallet',
              style: TextStyle(
                color: AppColors.fg,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
