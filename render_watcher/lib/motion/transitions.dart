import 'package:flutter/material.dart';

import '../theme/responsive.dart';
import '../theme/tokens.dart';

/// Material shared-axis (X) between steps of one flow. The incoming child
/// slides in from the direction of travel while the outgoing one leaves
/// the opposite way.
class SharedAxisSwitcher extends StatelessWidget {
  const SharedAxisSwitcher({
    super.key,
    required this.child,
    required this.forward,
  });

  final Widget child;
  final bool forward;

  @override
  Widget build(BuildContext context) {
    final reduce = context.reduceMotion;
    return AnimatedSwitcher(
      duration: reduce ? Motion.fadeIn : Motion.enter,
      reverseDuration: reduce ? Motion.fadeOut : Motion.exit,
      switchInCurve: Motion.decelerate,
      switchOutCurve: Motion.accelerate,
      layoutBuilder: (current, previous) =>
          Stack(fit: StackFit.expand, children: [...previous, ?current]),
      transitionBuilder: (child, animation) {
        final incoming = child.key == this.child.key;
        final dir = forward ? 1.0 : -1.0;
        final dx = reduce ? 0.0 : (incoming ? 30.0 * dir : -30.0 * dir);
        return AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) => Opacity(
            opacity: animation.value,
            child: Transform.translate(
              offset: Offset(dx * (1 - animation.value), 0),
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// One-shot fade + rise used for staggered list entrances.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 12,
    this.duration = Motion.enter,
  });

  final Widget child;
  final Duration delay;
  final double offset;
  final Duration duration;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.duration);
  late final _curve = CurvedAnimation(parent: _c, curve: Motion.decelerate);

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) _c.value = 1;
  }

  @override
  void dispose() {
    _curve.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - _curve.value)),
          child: child,
        ),
      ),
    );
  }
}

/// Container transform: grows a card from [sourceRect] into a full page,
/// cross-fading the content (Material's card → detail pattern). The colors
/// are explicit so nothing flashes white on the dark theme.
class ContainerTransformRoute<T> extends PageRoute<T> {
  ContainerTransformRoute({
    required this.sourceRect,
    required this.builder,
    this.closedColor = AppColors.surface1,
    this.openColor = AppColors.bg,
    this.closedRadius = Radii.card,
  });

  final Rect sourceRect;
  final WidgetBuilder builder;
  final Color closedColor;
  final Color openColor;
  final double closedRadius;

  @override
  bool get opaque => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => Motion.transform;

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 400);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation) =>
      builder(context);

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    if (context.reduceMotion) {
      return FadeTransition(opacity: animation, child: child);
    }
    final geometry = CurvedAnimation(
      parent: animation,
      curve: Easing.standard,
      reverseCurve: Easing.standard.flipped,
    );
    final contentFade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.3, 1, curve: Curves.linear),
      reverseCurve: const Interval(0.5, 1, curve: Curves.linear),
    );
    return LayoutBuilder(builder: (context, constraints) {
      final full = Offset.zero & constraints.biggest;
      return AnimatedBuilder(
        animation: geometry,
        child: child,
        builder: (context, child) {
          final t = geometry.value;
          final rect = Rect.lerp(sourceRect, full, t)!;
          return Stack(children: [
            Positioned.fromRect(
              rect: rect,
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(closedRadius * (1 - t)),
                child: ColoredBox(
                  color: Color.lerp(closedColor, openColor, t)!,
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    minWidth: full.width,
                    maxWidth: full.width,
                    minHeight: full.height,
                    maxHeight: full.height,
                    child: FadeTransition(opacity: contentFade, child: child),
                  ),
                ),
              ),
            ),
          ]);
        },
      );
    });
  }
}

/// Returns the global rect of the widget that owns [context].
Rect rectOf(BuildContext context) {
  final box = context.findRenderObject()! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}
