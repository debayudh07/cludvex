import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../motion/transitions.dart';
import '../../state/app_state.dart';
import '../../theme/responsive.dart';
import '../../theme/tokens.dart';
import '../../widgets/primitives.dart';
import '../shell/home_shell.dart';
import 'api_key_step.dart';
import 'done_step.dart';
import 'pick_services_step.dart';
import 'sign_in_step.dart';

/// Sign in → API key → pick services → done, as one shared-axis journey.
/// Each step asks exactly one thing.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  int _step = 0;
  bool _forward = true;
  Set<String> _picked = {'billing', 'api'};

  void _go(int step) {
    setState(() {
      _forward = step > _step;
      _step = step;
    });
  }

  void _finish() {
    AppScope.read(context).setWatched(_picked);
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: Motion.transform,
      pageBuilder: (_, _, _) => const HomeShell(),
      transitionsBuilder: (_, a, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Motion.decelerate),
        child: child,
      ),
    ));
  }

  Widget _stepView() => switch (_step) {
        0 => SignInStep(key: const ValueKey(0), onContinue: () => _go(1)),
        1 => ApiKeyStep(key: const ValueKey(1), onConnected: () => _go(2)),
        2 => PickServicesStep(
            key: const ValueKey(2),
            initial: _picked,
            onDone: (ids) {
              _picked = ids;
              _go(3);
            },
          ),
        _ => DoneStep(
            key: const ValueKey(3),
            count: _picked.length,
            onOpen: _finish,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final canBack = _step == 1 || _step == 2;
    return PopScope(
      canPop: !canBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && canBack) _go(_step - 1);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          body: SafeArea(
            child: Column(children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.gutter - 4),
                child: ContentWidth(
                  maxWidth: 560,
                  child: SizedBox(
                    height: 60,
                    child: Row(children: [
                      AnimatedOpacity(
                        opacity: canBack ? 1 : 0,
                        duration: Motion.press,
                        child: IgnorePointer(
                          ignoring: !canBack,
                          child: CircleIconButton(
                            icon: Icons.arrow_back_rounded,
                            tooltip: 'Back',
                            onTap: () => _go(_step - 1),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _Progress(step: _step)),
                      const SizedBox(width: 12),
                    ]),
                  ),
                ),
              ),
              Expanded(
                child: SharedAxisSwitcher(
                  forward: _forward,
                  child: KeyedSubtree(key: ValueKey(_step), child: _stepView()),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step ${step.clamp(0, 2) + 1} of 3',
      child: Row(children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                height: 4,
                child: Stack(children: [
                  const Positioned.fill(child: ColoredBox(color: AppColors.divider)),
                  AnimatedFractionallySizedBox(
                    duration: Motion.transform,
                    curve: Motion.standard,
                    widthFactor: step > i ? 1 : (step == i ? 0.5 : 0),
                    child: const ColoredBox(color: AppColors.accent, child: SizedBox.expand()),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

/// Shared step layout: content scrolls on short screens, the action stays
/// at the bottom on tall ones, and width is capped on tablets.
class StepLayout extends StatelessWidget {
  const StepLayout({
    super.key,
    required this.content,
    this.footer = const [],
  });

  final List<Widget> content;
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      return SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: context.gutter),
        child: ContentWidth(
          maxWidth: 520,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: context.isShort ? 12 : 28),
                  ...content,
                  const Spacer(),
                  const SizedBox(height: 24),
                  ...footer,
                  SizedBox(height: context.isShort ? 16 : 24),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
