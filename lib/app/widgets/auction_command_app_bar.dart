import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Shared app bar: bolt + **AUCTION COMMAND** styling (match schedule), optional back, profile menu with **Log out**.
class AuctionCommandAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AuctionCommandAppBar({
    super.key,
    this.title = 'AUCTION COMMAND',
    this.backgroundColor = Colors.transparent,
    this.accentColor = AppColors.neonGreen,
    this.elevation = 0,
  });

  final String title;
  final Color backgroundColor;
  final Color accentColor;
  final double elevation;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return AppBar(
      backgroundColor: backgroundColor,
      elevation: elevation,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      leading: canPop
          ? IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: accentColor, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            )
          : null,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, color: accentColor, size: 22),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: accentColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              fontSize: 14,
            ),
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          offset: const Offset(0, 44),
          color: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: const Padding(
            padding: EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.chipInactive,
              child: Icon(Icons.person, size: 18, color: Colors.white70),
            ),
          ),
          onSelected: (value) async {
            if (value == 'logout') await _logout();
          },
          itemBuilder: (context) => const [
            PopupMenuItem<String>(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, color: Colors.white70, size: 20),
                  SizedBox(width: 10),
                  Text('Log out', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
