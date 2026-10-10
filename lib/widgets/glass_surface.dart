import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'app_ui.dart';

/// A bounded translucent surface for navigation and search, not regular cards.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final double radius;
  final bool highlighted;
  const GlassSurface(
      {super.key,
      required this.child,
      this.radius = 24,
      this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    final contrast = MediaQuery.highContrastOf(context);
    final content = ColoredBox(
        color: contrast ? Colors.white : Colors.white.withValues(alpha: .84),
        child: child);
    return AnimatedContainer(
      duration: AppMotion.duration(context, 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
            color: highlighted
                ? contrast
                    ? AppTheme.primary
                    : AppTheme.primary.withValues(alpha: .6)
                : contrast
                    ? AppTheme.muted
                    : Colors.white.withValues(alpha: .8),
            width: highlighted ? 1.5 : 1),
        boxShadow: [
          BoxShadow(
              color: highlighted
                  ? AppTheme.accent.withValues(alpha: .12)
                  : AppTheme.ink.withValues(alpha: .055),
              blurRadius: highlighted ? 18 : 24,
              offset: const Offset(0, 8))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: contrast
            ? content
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: content),
      ),
    );
  }
}
