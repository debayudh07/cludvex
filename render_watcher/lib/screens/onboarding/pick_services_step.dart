import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../data/models.dart';
import '../../motion/haptics.dart';
import '../../motion/transitions.dart';
import '../../theme/app_theme.dart';
import '../../theme/responsive.dart';
import '../../state/app_state.dart';
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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _picked.addAll(AppScope.read(context).watched);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final state = AppScope.read(context);
    await state.loadAllServices();
    if (!mounted) return;
    // Already-watched services come back flagged, so a returning account
    // sees its current selection ticked.
    setState(() {
      for (final s in state.allServices) {
        if (s.watched) _picked.add(s.id);
      }
    });
  }

  void _toggle(String id, int maxWatched) {
    if (!_picked.contains(id) && _picked.length >= maxWatched) {
      Haptics.error();
      AppScope.read(context)
          .showToast('You can watch up to $maxWatched services');
      return;
    }
    Haptics.selection();
    setState(() => _picked.contains(id) ? _picked.remove(id) : _picked.add(id));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final state = AppScope.read(context);
    try {
      await state.setWatched(_picked);
      if (mounted) widget.onDone(_picked);
    } on ApiException catch (e) {
      if (mounted) state.showToast(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final state = AppScope.of(context);
    final services = state.allServices;
    final loading = state.servicesLoading && services.isEmpty;
    final n = _picked.length;
    final showCta = !loading && n > 0;
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
                  _subtitle(state, loading, services.length),
                  key: ValueKey('$loading-${services.length}-${state.servicesError}'),
                  style: t.bodyLarge?.copyWith(
                    color: state.servicesError != null
                        ? AppColors.criticalText
                        : AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: Motion.tab,
                child: loading
                    ? const Skeleton(
                        key: ValueKey('skel'),
                        child: Column(children: [
                          RowSkeleton(leading: 24, widthFactor: 0.5),
                          RowSkeleton(leading: 24, widthFactor: 0.4),
                          RowSkeleton(leading: 24, widthFactor: 0.48),
                          RowSkeleton(leading: 24, widthFactor: 0.38),
                        ]),
                      )
                    : services.isEmpty
                        ? _EmptyServices(key: const ValueKey('empty'), onRetry: _load)
                        : Column(key: const ValueKey('list'), children: [
                            for (var i = 0; i < services.length; i++)
                              FadeSlideIn(
                                delay: Duration(milliseconds: 40 * i),
                                offset: 10,
                                child: _ServiceChoice(
                                  service: services[i],
                                  selected: _picked.contains(services[i].id),
                                  onTap: () => _toggle(services[i].id, state.maxWatched),
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
                onPressed: showCta && !_saving ? _save : null,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Colors.white),
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

String _subtitle(AppState state, bool loading, int count) {
  if (loading) return 'Looking up your services on Render…';
  if (state.servicesError != null) return state.servicesError!;
  if (count == 0) return 'No services on this Render key yet.';
  return 'Found $count. Start with the ones that wake you up at night. '
      'Up to ${state.maxWatched}.';
}

class _EmptyServices extends StatelessWidget {
  const _EmptyServices({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: TextButton(
          onPressed: onRetry,
          child: const Text('Try again', style: TextStyle(color: AppColors.accentText)),
        ),
      ),
    );
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
                Text('${service.kind.label} · ${service.regionLabel}',
                    style: AppText.mono(size: 11.5)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
