import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../theme/tokens.dart';
import 'primitives.dart';

/// Ambient health backdrop: rings, a slow violet sweep and one node per
/// watched service, placed on fixed angles so the layout is stable.
class ServiceRadar extends StatefulWidget {
  const ServiceRadar({super.key, required this.services});

  final List<RenderService> services;

  @override
  State<ServiceRadar> createState() => _ServiceRadarState();
}

class _ServiceRadarState extends State<ServiceRadar>
    with SingleTickerProviderStateMixin {
  late final _sweep =
      AnimationController(vsync: this, duration: const Duration(seconds: 6));

  static const _slots = [(-2.2, 0.62), (-0.75, 0.78), (0.45, 0.55), (2.6, 0.7), (1.6, 0.85)];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _sweep.stop();
    } else if (!_sweep.isAnimating) {
      _sweep.repeat();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: LayoutBuilder(builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final center = size.center(Offset.zero);
        final r = math.min(size.width, size.height) / 2 - 4;
        return Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _RadarPainter(_sweep, r)),
            ),
          ),
          for (var i = 0; i < widget.services.length && i < _slots.length; i++)
            _node(widget.services[i], center, r, _slots[i]),
        ]);
      }),
    );
  }

  Widget _node(RenderService s, Offset center, double r, (double, double) slot) {
    final p = center + Offset(math.cos(slot.$1), math.sin(slot.$1)) * r * slot.$2;
    final down = s.health == ServiceHealth.down;
    return Positioned(
      left: p.dx - 12,
      top: p.dy - 12,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox.square(
          dimension: 24,
          child: Center(
            child: down
                ? LiveDot(color: s.health.color, size: 10)
                : Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(color: s.health.color, shape: BoxShape.circle),
                  ),
          ),
        ),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: down
              ? BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.outline),
                )
              : null,
          child: Text(down ? s.name : s.shortName,
              style: AppText.mono(
                  size: 11.5,
                  color: down ? AppColors.text : AppColors.textSecondary)),
        ),
      ]),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.sweep, this.radius) : super(repaint: sweep);

  final Animation<double> sweep;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFF1A1D27);
    for (final f in [0.33, 0.66, 1.0]) {
      canvas.drawCircle(c, radius * f, ring);
    }
    final cross = Paint()..color = const Color(0xFF13161E);
    canvas.drawLine(c - Offset(radius, 0), c + Offset(radius, 0), cross);
    canvas.drawLine(c - Offset(0, radius), c + Offset(0, radius), cross);

    final a = sweep.value * math.pi * 2 - math.pi / 2;
    final wedge = Paint()
      ..shader = SweepGradient(
        startAngle: a - 0.6,
        endAngle: a,
        colors: [AppColors.accent.withValues(alpha: 0), AppColors.accent.withValues(alpha: 0.14)],
        tileMode: TileMode.clamp,
      ).createShader(Rect.fromCircle(center: c, radius: radius));
    canvas.drawCircle(c, radius, wedge);
    canvas.drawLine(
      c,
      c + Offset(math.cos(a), math.sin(a)) * radius,
      Paint()
        ..color = AppColors.accent.withValues(alpha: 0.6)
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(c, 4, Paint()..color = AppColors.accent);
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.radius != radius;
}
