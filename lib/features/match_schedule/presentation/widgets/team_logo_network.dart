import 'package:flutter/material.dart';

/// Network team logo: **PNG / JPEG / WebP / GIF** decode reliably via [Image.network].
///
/// **SVG URLs** are not decoded by Flutter's image codec — they will hit [errorBuilder]
/// (use a **raster** URL in Firestore `logo`, or host a simplified SVG converted to PNG).
class TeamLogoNetwork extends StatelessWidget {
  const TeamLogoNetwork({
    super.key,
    required this.url,
    this.size = 80,
    this.fit = BoxFit.contain,
    this.borderRadius = 12,
    this.fallbackColor,
    this.fallbackLabel = '',
  });

  final String? url;
  final double size;
  final BoxFit fit;
  final double borderRadius;
  final Color? fallbackColor;
  final String fallbackLabel;

  @override
  Widget build(BuildContext context) {
    final u = url?.trim();
    if (u == null || u.isEmpty) {
      return _fallbackBox();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Material(
        color: Colors.white.withValues(alpha: 0.06),
        child: Image.network(
          u,
          width: size,
          height: size,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _fallbackBox(),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return SizedBox(
              width: size,
              height: size,
              child: Center(
                child: SizedBox(
                  width: size * 0.35,
                  height: size * 0.35,
                  child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _fallbackBox() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fallbackColor ?? Colors.white24,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: Text(
        fallbackLabel.isEmpty ? '?' : fallbackLabel,
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Full-bleed low-opacity logo behind a team block (raster URLs only; SVG fails silently).
class TeamLogoBackdrop extends StatelessWidget {
  const TeamLogoBackdrop({
    super.key,
    required this.url,
    this.opacity = 0.14,
  });

  final String? url;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final u = url?.trim();
    if (u == null || u.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        return Opacity(
          opacity: opacity,
          child: Image.network(
            u,
            width: w,
            height: h,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
