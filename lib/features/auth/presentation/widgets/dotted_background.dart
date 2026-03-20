import 'package:flutter/material.dart';

/// Full-bleed dot grid behind auth screens.
class DottedBackground extends StatelessWidget {
  const DottedBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: const _DottedBackgroundPainter(),
        );
      },
    );
  }
}

class _DottedBackgroundPainter extends CustomPainter {
  const _DottedBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.05);
    for (var i = 0.0; i < size.width; i += 20) {
      for (var j = 0.0; j < size.height; j += 20) {
        canvas.drawCircle(Offset(i, j), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
