import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../motion/haptics.dart';
import '../../motion/transitions.dart';
import '../../theme/app_theme.dart';
import '../../theme/responsive.dart';
import '../../theme/tokens.dart';
import '../../widgets/primitives.dart';

class PickServicesStep extends StatefulWidget {
  const PickServicesStep({super.key, required this.initial, required this.onDone});

  final Set<String> initial;
  final ValueChanged<Set<String>> onDone;

  @override
  State<PickServicesStep> createState() => _PickServicesStepState();
}

class _PickServicesStepState extends State<PickServicesStep> {
  late final Set<String> _picked = {...widget.initial};
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // TODO: replace with the backend's list of services from Render.
    _timer = Timer(const Duration(milliseconds: 1300), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggle(String id) {
    Haptics.selection();
    setState(() => _picked.contains(id) ? _picked.remove(id) : _picked.add(id));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final n = _picked.length;
    final showCta = !_loading && n > 0;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Stack(children: [
      ListView(
        padding: EdgeInsets.fromLTRB(context.gutter, context.isShort ? 12 : 28,
            context.gutter, 120 + bottomSafe),
        children: [
          ContentWidth(
            maxWidth: 520,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('What should we watch?', style: t.headlineMedium?.copyWith(height: 1.2)),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: Motion.press,
                child: Text(
                  _loading
                      ? 'Looking up your services on Render…'
                      : 'Found ${MockData.services.length}. Start with the ones that wake you up at night.',
                  key: ValueKey(_loading),
                  style: t.bodyLarge?.copyWith(color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: Motion.tab,
                child: _loading
                    ? const Skeleton(
                        key: ValueKey('skel'),
                        child: Column(children: [
                          RowSkeleton(leading: 24, widthFactor: 0.5),
                          RowSkeleton(leading: 24, widthFactor: 0.4),
                          RowSkeleton(leading: 24, widthFactor: 0.48),
                          RowSkeleton(leading: 24, widthFactor: 0.38),
                        ]),
                      )
                    : Column(key: const ValueKey('list'), children: [
                        for (var i = 0; i < MockData.services.length; i++)
                          FadeSlideIn(
                            delay: Duration(milliseconds: 40 * i),
                            offset: 10,
                            child: _ServiceChoice(
                              service: MockData.services[i],
                              selected: _picked.contains(MockData.services[i].id),
                              onTap: () => _toggle(MockData.services[i].id),
                            ),
                          ),
                      ]),
              ),
            ]),
          ),
        ],
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: AnimatedSlide(
          offset: showCta ? Offset.zero : const Offset(0, 1.2),
          duration: Motion.enter,
          curve: showCta ? Motion.decelerate : Motion.accelerate,
          child: Container(
            padding: EdgeInsets.fromLTRB(context.gutter, 16, context.gutter, 16 + bottomSafe),
            decoration: const BoxDecoration(
              color: AppColors.bg,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: ContentWidth(
              maxWidth: 520,
              child: PrimaryButton(
                label: 'Watch $n service${n == 1 ? '' : 's'}',
                onPressed: showCta ? () => widget.onDone(_picked) : null,
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _ServiceChoice extends StatelessWidget {
  const _ServiceChoice({required this.service, required this.selected, required this.onTap});

  final RenderService service;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: selected,
      child: Pressable(
        onTap: onTap,
        scale: 0.98,
        borderRadius: BorderRadius.circular(Radii.control),
        child: AnimatedContainer(
          duration: Motion.press,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          color: selected ? AppColors.accent.withValues(alpha: 0.10) : Colors.transparent,
          child: Row(children: [
            AnimatedContainer(
              duration: Motion.press,
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: selected ? AppColors.accentStrong : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: selected ? AppColors.accentStrong : const Color(0xFF4A4F5E), width: 1.5),
              ),
              child: AnimatedScale(
                scale: selected ? 1 : 0,
                duration: Motion.press,
                curve: Motion.playful,
                child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(service.name,
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500)),
                const SizedBox(height: 3),
                Text('${service.kind.label} · ${service.region}',
                    style: AppText.mono(size: 11.5)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
