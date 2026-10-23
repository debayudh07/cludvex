import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/responsive.dart';
import '../../theme/tokens.dart';
import '../../widgets/primitives.dart';
import 'onboarding_flow.dart';

class SignInStep extends StatelessWidget {
  const SignInStep({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final mark = context.isShort ? 88.0 : 120.0;
    return StepLayout(
      content: [
        Align(alignment: Alignment.centerLeft, child: _AgentMark(size: mark)),
        SizedBox(height: context.isShort ? 24 : 40),
        Text(
          'Never watch logs all day again.',
          style: t.displaySmall?.copyWith(
            fontSize: context.displaySize(36),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'An agent reads your Render logs, tells you what looks wrong, and asks '
          'before it touches anything.',
          style: t.bodyLarge?.copyWith(color: AppColors.textMuted),
        ),
      ],
      footer: [
        PrimaryButton(
          label: 'Continue with GitHub',
          icon: Icons.code_rounded,
          inverse: true,
          onPressed: onContinue,
        ),
        const SizedBox(height: 14),
        Text(
          'GitHub is only for sign-in. Render comes next.',
          textAlign: TextAlign.center,
          style: t.bodySmall?.copyWith(color: AppColors.textFaint),
        ),
      ],
    );
  }
}

/// Idle "agent eye": rings, a sweep and an expanding ping.
class _AgentMark extends StatefulWidget {
  const _AgentMark({required this.size});

  final double size;

  @override
  State<_AgentMark> createState() => _AgentMarkState();
}

class _AgentMarkState extends State<_AgentMark> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 5));

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
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: widget.size,
          child: CustomPaint(painter: _MarkPainter(_c)),
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.t) : super(repaint: t);

  final Animation<double> t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final ping = (t.value * 2) % 1;
    canvas.drawCircle(
      c,
      r * (0.6 + 0.4 * ping),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = AppColors.accent.withValues(alpha: 0.6 * (1 - ping)),
    );
    canvas.drawCircle(c, r * 0.93, Paint()..color = AppColors.surface1);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFF1E2230);
    canvas.drawCircle(c, r * 0.93, ring);
    canvas.drawCircle(c, r * 0.6, ring);
    canvas.drawCircle(c, r * 0.27, ring..color = const Color(0xFF262A36));
    final a = t.value * math.pi * 2 - math.pi / 2;
    canvas.drawLine(
      c,
      c + Offset(math.cos(a), math.sin(a)) * r * 0.9,
      Paint()
        ..color = AppColors.accent
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(c, r * 0.08, Paint()..color = AppColors.accent);
    canvas.drawCircle(c + Offset(r * 0.4, -r * 0.33), r * 0.065, Paint()..color = AppColors.critical);
    canvas.drawCircle(c + Offset(-r * 0.37, r * 0.3), r * 0.058, Paint()..color = AppColors.ok);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => false;
}
