import 'package:flutter/material.dart';
import '../config/theme.dart';

class EventStatusTabBar extends StatelessWidget {
  final int selectedTab; // 0: En Cartelera, 1: Pasados
  final int activeCount;
  final int pastCount;
  final ValueChanged<int> onTabChanged;

  const EventStatusTabBar({
    super.key,
    required this.selectedTab,
    required this.activeCount,
    required this.pastCount,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bgSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              title: 'En Cartelera ($activeCount)',
              isSelected: selectedTab == 0,
              onTap: () => onTabChanged(0),
            ),
          ),
          Expanded(
            child: _TabButton(
              title: 'Pasados ($pastCount)',
              isSelected: selectedTab == 1,
              onTap: () => onTabChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppColors.accentFg : AppColors.fgMuted,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
