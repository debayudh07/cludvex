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

enum OnboardingStep { signIn, apiKey, pickServices, done }

/// Sign in → API key → pick services → done, as one shared-axis journey.
/// Each step asks exactly one thing. [start] lets a returning account skip
/// the steps it has already finished.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, this.start = OnboardingStep.signIn});

  final OnboardingStep start;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  late OnboardingStep _step = widget.start;
  bool _forward = true;
  Set<String> _picked = {};

  void _go(OnboardingStep step) {
    setState(() {
      _forward = step.index > _step.index;
      _step = step;
    });
  }

  Future<void> _finish() async {
    final state = AppScope.read(context);
    // Watched services were saved by the picker; pull the first real payload
    // before the dashboard paints so it never flashes empty.
    await state.bootstrap();
    if (!mounted) return;
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
        OnboardingStep.signIn => SignInStep(
            key: const ValueKey(0),
            // AuthGate reacts to the Firebase session and routes onward, so
            // the step only has to report that it is no longer needed.
            onSignedIn: () => _go(OnboardingStep.apiKey),
          ),
        OnboardingStep.apiKey => ApiKeyStep(
            key: const ValueKey(1),
            onConnected: () => _go(OnboardingStep.pickServices),
          ),
        OnboardingStep.pickServices => PickServicesStep(
            key: const ValueKey(2),
            initial: _picked,
            onDone: (ids) {
              _picked = ids;
              _go(OnboardingStep.done);
            },
          ),
        OnboardingStep.done => DoneStep(
            key: const ValueKey(3),
            count: _picked.isEmpty ? AppScope.read(context).watched.length : _picked.length,
            onOpen: _finish,
          ),
      };

  @override
  Widget build(BuildContext context) {
    // Only steps the user can meaningfully return to from here.
    final canBack = _step == OnboardingStep.pickServices && widget.start.index < _step.index;
    return PopScope(
      canPop: !canBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && canBack) _go(OnboardingStep.apiKey);
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
                            onTap: () => _go(OnboardingStep.apiKey),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _Progress(step: _step.index)),
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
