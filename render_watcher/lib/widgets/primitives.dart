import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../theme/tokens.dart';

/// Scales down slightly while pressed (200ms, standard easing).
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.97,
    this.borderRadius = const BorderRadius.all(Radius.circular(Radii.card)),
    this.color = Colors.transparent,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final BorderRadius borderRadius;
  final Color color;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: Motion.press,
        curve: Motion.standard,
        child: Material(
          color: widget.color,
          borderRadius: widget.borderRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: (_) => _set(true),
            onTapUp: (_) => _set(false),
            onTapCancel: () => _set(false),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Full-width primary action, 56dp tall (Uber's pinned confirm button).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.inverse = false,
    this.child,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// White fill, used for the GitHub sign-in.
  final bool inverse;

  /// Replaces the label, e.g. an AnimatedSwitcher of states.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final fg = inverse ? AppColors.bg : Colors.white;
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Pressable(
        onTap: onPressed,
        color: inverse ? AppColors.text : AppColors.accentStrong,
        borderRadius: BorderRadius.circular(Radii.control),
        child: SizedBox(
          height: 56,
          width: double.infinity,
          child: Center(
            child: DefaultTextStyle.merge(
              style: TextStyle(
                  color: fg, fontSize: 16, fontWeight: FontWeight.w600),
              child: IconTheme.merge(
                data: IconThemeData(color: fg, size: 20),
                child: child ??
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      if (icon != null) ...[Icon(icon), const SizedBox(width: 10)],
                      Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.size = 44,
    this.color = AppColors.surface2,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        semanticLabel: tooltip,
        color: color,
        borderRadius: BorderRadius.circular(size),
        scale: 0.92,
        child: SizedBox.square(
          dimension: size,
          child: Icon(icon, size: 20, color: AppColors.text),
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.label,
      {super.key, required this.color, this.background, this.icon});

  final String label;
  final Color color;
  final Color? background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
        ],
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3)),
      ]),
    );
  }
}

/// YouTube-style filter chip: selected inverts to white.
class FilterChipX extends StatelessWidget {
  const FilterChipX({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: Pressable(
        onTap: onTap,
        color: selected ? AppColors.text : AppColors.surface2,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedDefaultTextStyle(
          duration: Motion.press,
          style: TextStyle(
            color: selected ? AppColors.bg : AppColors.text,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing, this.color});

  final String text;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 20, 2, 10),
      child: Row(children: [
        Expanded(
          child: Text(text.toUpperCase(),
              style: color == null ? AppText.label : AppText.label.copyWith(color: color)),
        ),
        ?trailing,
      ]),
    );
  }
}

/// Pulsing dot for "live" / critical states. Stops pulsing under reduce motion.
class LiveDot extends StatefulWidget {
  const LiveDot({super.key, this.color = AppColors.accent, this.size = 7});

  final Color color;
  final double size;

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: s * 2.6,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = Motion.standard.transform(_c.value);
            return Stack(alignment: Alignment.center, children: [
              Container(
                width: s + s * 1.6 * t,
                height: s + s * 1.6 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.5 * (1 - t)),
                ),
              ),
              Container(
                width: s,
                height: s,
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: widget.color),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

/// Agent confidence ring. Fills with emphasized-decelerate after a short
/// delay so it lands once the container transform has settled.
class ConfidenceArc extends StatelessWidget {
  const ConfidenceArc({
    super.key,
    required this.value,
    this.size = 64,
    this.stroke = 6,
    this.animate = true,
    this.showLabel = true,
  });

  final double value;
  final double size;
  final double stroke;
  final bool animate;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final run = animate && !context.reduceMotion;
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: run ? 0 : value, end: value),
        duration: run ? const Duration(milliseconds: 1000) : Duration.zero,
        curve: const Interval(0.3, 1, curve: Easing.emphasizedDecelerate),
        builder: (context, v, _) => SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _ArcPainter(v, stroke),
            child: showLabel
                ? Center(
                    child: Text('${(value * 100).round()}%',
                        style: TextStyle(
                            fontSize: size * 0.24,
                            fontWeight: FontWeight.w700)),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.value, this.stroke);

  final double value;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final track = Paint()
      ..color = AppColors.surface3
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final arc = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, arc);
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.value != value || old.stroke != stroke;
}

/// Pulse skeleton. A sweeping shimmer is too loud on near-black.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, required this.child});

  final Widget child;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200));
  late final _opacity = Tween(begin: 1.0, end: 0.45)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _c.value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}

class Bone extends StatelessWidget {
  const Bone({super.key, this.width, this.height = 12, this.radius = 6, this.light = false});

  final double? width;
  final double height;
  final double radius;
  final bool light;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: light ? AppColors.surface3 : AppColors.surface2,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

/// Skeleton matching a two-line service row.
class RowSkeleton extends StatelessWidget {
  const RowSkeleton({super.key, this.leading = 44, this.widthFactor = 0.55});

  final double leading;
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Bone(width: leading, height: leading, radius: 12),
        const SizedBox(width: 14),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Bone(width: c.maxWidth * widthFactor, light: true),
                const SizedBox(height: 8),
                Bone(width: c.maxWidth * (widthFactor + 0.25), height: 10),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
