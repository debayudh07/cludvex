import 'package:flutter/material.dart';

/// Material window size classes.
enum SizeClass { compact, medium, expanded }

extension ResponsiveContext on BuildContext {
  Size get screen => MediaQuery.sizeOf(this);

  SizeClass get sizeClass {
    final w = screen.width;
    if (w < 600) return SizeClass.compact;
    if (w < 840) return SizeClass.medium;
    return SizeClass.expanded;
  }

  bool get isExpanded => sizeClass == SizeClass.expanded;

  /// Horizontal page gutter that grows with the window.
  double get gutter => switch (sizeClass) {
        SizeClass.compact => screen.width < 360 ? 16 : 20,
        SizeClass.medium => 32,
        SizeClass.expanded => 40,
      };

  /// Display headline size proportional to width, clamped to sane bounds.
  double displaySize(double base) {
    final scaled = base * (screen.width / 390);
    return scaled.clamp(base * 0.82, base * 1.15);
  }

  /// Short phones (e.g. SE, landscape) get tighter vertical rhythm.
  bool get isShort => screen.height < 700;

  bool get reduceMotion =>
      MediaQuery.disableAnimationsOf(this) ||
      View.of(this).platformDispatcher.accessibilityFeatures.reduceMotion;
}

/// Centers content and caps its width so lines stay readable on tablets.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = 640});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Horizontal padding that centers a sliver column at [maxWidth].
EdgeInsets centeredSliverPadding(BuildContext context,
    {double maxWidth = 720, double top = 0, double bottom = 0}) {
  final w = context.screen.width;
  final side = ((w - maxWidth) / 2).clamp(context.gutter, double.infinity);
  return EdgeInsets.fromLTRB(side, top, side, bottom);
}
