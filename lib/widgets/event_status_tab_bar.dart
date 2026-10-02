import 'package:flutter/material.dart';
import '../config/theme.dart';

class EventStatusTabBar extends StatelessWidget {
  final int selectedTab; // 0: En Cartelera, 1: Concluidos, 2: Agotados, 3: Todos los Eventos
  final int activeCount;
  final int concludedCount;
  final int soldOutCount;
  final int allCount;
  final ValueChanged<int> onTabChanged;

  const EventStatusTabBar({
    super.key,
    required this.selectedTab,
    required this.activeCount,
    required this.concludedCount,
    required this.soldOutCount,
    required this.allCount,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _TabItem(title: 'En Cartelera', count: activeCount),
      _TabItem(title: 'Concluidos', count: concludedCount),
      _TabItem(title: 'Agotados', count: soldOutCount),
      _TabItem(title: 'Todos los Eventos', count: allCount),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final isSelected = selectedTab == index;
            final isFirst = index == 0;
            final isLast = index == items.length - 1;

            return Padding(
              padding: EdgeInsets.only(
                left: isFirst ? 0 : 4,
                right: isLast ? 0 : 4,
              ),
              child: _TabPill(
                title: item.title,
                count: item.count,
                isSelected: isSelected,
                onTap: () => onTabChanged(index),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _TabItem {
  final String title;
  final int count;

  const _TabItem({required this.title, required this.count});
}

class _TabPill extends StatelessWidget {
  final String title;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabPill({
    required this.title,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent : AppColors.bgSoft,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? AppColors.accent : AppColors.border,
              width: 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? AppColors.accentFg : AppColors.fg,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.black.withValues(alpha: 0.25)
                      : AppColors.bg,
                  borderRadius: BorderRadius.circular(10),
                  border: isSelected
                      ? null
                      : Border.all(color: AppColors.border, width: 0.8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? AppColors.accentFg : AppColors.fgMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
