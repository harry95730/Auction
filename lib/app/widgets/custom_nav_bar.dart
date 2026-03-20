import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Bottom nav indices for [AuctionCommandShell] / [MainTab].
abstract final class MainTab {
  static const int dashboard = 0;
  static const int schedule = 1;
  static const int leaderboard = 2;
  static const int history = 3;
}

/// Rounded bottom bar: Dashboard, Schedule, Leaderboard, History. Active tab uses [AppColors.neonGreen].
class CustomNavBar extends StatelessWidget {
  const CustomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavItem(Icons.grid_view_rounded, 'DASHBOARD', MainTab.dashboard),
          _buildNavItem(Icons.calendar_month_outlined, 'SCHEDULE', MainTab.schedule),
          _buildNavItem(Icons.bar_chart_rounded, 'LEADERBOARD', MainTab.leaderboard),
          _buildNavItem(Icons.history_rounded, 'HISTORY', MainTab.history),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isActive = selectedIndex == index;
    const activeColor = AppColors.neonGreen;
    const inactiveColor = Colors.white70;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onItemSelected(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? activeColor : inactiveColor,
            size: 28,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isActive ? activeColor : inactiveColor,
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
