import 'package:flutter/material.dart';

import 'app_colors.dart';

/// SnackBars aligned with the app shell: **dark surface** + **neon green** (success) or **amber** (info / errors).
abstract final class AppSnackBars {
  AppSnackBars._();

  static const Color _amberText = Color(0xFFFFE082);

  /// Confirmations and positive outcomes.
  static SnackBar success(String message) => _bar(message, AppColors.neonGreen);

  /// Validation messages, failures, locks, and cautions.
  static SnackBar warning(String message) => _bar(message, _amberText);

  static SnackBar _bar(String message, Color foreground) {
    return SnackBar(
      backgroundColor: AppColors.cardDark,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: foreground.withValues(alpha: 0.42), width: 1),
      ),
      content: Text(
        message,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w600,
          fontSize: 14,
          height: 1.3,
        ),
      ),
    );
  }
}
