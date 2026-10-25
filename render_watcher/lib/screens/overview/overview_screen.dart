import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../motion/haptics.dart';
import '../../motion/transitions.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/responsive.dart';
import '../../theme/tokens.dart';
import '../../widgets/primitives.dart';
import '../../widgets/radar.dart';

/// Uber-style "context on top, sheet below": an ambient health radar with a
/// draggable sheet that snaps to peek / mid / full. On wide windows the
/// sheet becomes a side panel.
class OverviewScreen extends StatefulWidget {
  const OverviewScreen({
    super.key,
    required this.bottomInset,
    required this.onReplayBanner,
    required this.onOpenMandate,
    required this.onOpenLogs,
  });

  final double bottomInset;
  final VoidCallback onReplayBanner;
  final VoidCallback onOpenMandate;
  final ValueChanged<String?> onOpenLogs;

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  final _sheet = DraggableScrollableController();
  final _extent = ValueNotifier<double>(0.5);
  double? _lastSnap;

  @override
  void initState() {
    super.initState();
    // The shell loads this at bootstrap; refetch so a cold resume is current.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.read(context).refreshOverview();
    });
  }

  @override
  void dispose() {
    _sheet.dispose();
    _extent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final services = state.watchedServices;
    final loading = state.overviewLoading && services.isEmpty;
    final wide = context.screen.width >= 700;

    final header = _Header(
      services: services,
      onReplayBanner: widget.onReplayBanner,
      onOpenMandate: widget.onOpenMandate,
    );

    final content = _SheetContent(
      services: services,
      loading: loading,
      state: state,
      onOpenLogs: widget.onOpenLogs,
      onOpenMandate: widget.onOpenMandate,
    );

    if (wide) {
      return SafeArea(
        bottom: false,
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            flex: 5,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              header,
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(context.gutter, 16, context.gutter, widget.bottomInset),
                  child: ServiceRadar(services: services),
                ),
              ),
            ]),
          ),
          Expanded(
            flex: 4,
            child: Container(
              margin: EdgeInsets.fromLTRB(0, 12, context.gutter, 0),
              decoration: const BoxDecoration(
                color: AppColors.surface1,
                borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
              ),
              child: CustomScrollView(slivers: [
                SliverToBoxAdapter(child: _SheetHeader(services: services, showHandle: false)),
                ...content.slivers(context, widget.bottomInset),
              ]),
            ),
          ),
        ]),
      );
    }

    return LayoutBuilder(builder: (context, c) {
      final h = c.maxHeight;
      final top = MediaQuery.paddingOf(context).top;
      final headerH = top + (context.isShort ? 128 : 150);
      final peekPx = widget.bottomInset + 92;
      final peek = (peekPx / h).clamp(0.1, 0.4);
      final radarH = math.min(c.maxWidth * 0.78, h * 0.34);
      final mid = (1 - (headerH + radarH * 0.62) / h).clamp(peek + 0.12, 0.8);

      return Stack(children: [
        Positioned(left: 0, right: 0, top: 0, child: SafeArea(bottom: false, child: header)),
        Positioned(
          left: 0,
          right: 0,
          top: headerH,
          height: radarH,
          child: ServiceRadar(services: services),
        ),
        NotificationListener<DraggableScrollableNotification>(
          onNotification: (n) {
            _extent.value = n.extent;
            final snap = [peek, mid, 1.0].firstWhere(
                (s) => (n.extent - s).abs() < 0.004,
                orElse: () => -1);
            if (snap > 0 && snap != _lastSnap) {
              _lastSnap = snap;
              Haptics.selection();
            }
            return false;
          },
          child: DraggableScrollableSheet(
            controller: _sheet,
            initialChildSize: mid,
            minChildSize: peek,
            maxChildSize: 1,
            snap: true,
            snapSizes: [mid],
            snapAnimationDuration: Motion.transform,
            builder: (context, scroll) => ValueListenableBuilder<double>(
              valueListenable: _extent,
              builder: (context, e, child) {
                // The sheet "becomes a page" as it reaches full height.
                final r = Radii.sheet * ((1 - e) / 0.06).clamp(0.0, 1.0);
                return Material(
                  color: AppColors.surface1,
                  elevation: 12,
                  shadowColor: Colors.black,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(r)),
                  clipBehavior: Clip.antiAlias,
                  child: child,
                );
              },
              child: CustomScrollView(controller: scroll, slivers: [
                SliverToBoxAdapter(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      final target = (_extent.value - mid).abs() < 0.02 ? 1.0 : mid;
                      _sheet.animateTo(target, duration: Motion.transform, curve: Motion.standard);
                    },
                    child: _SheetHeader(services: services, showHandle: true),
                  ),
                ),
                ...content.slivers(context, widget.bottomInset),
              ]),
            ),
          ),
        ),
      ]);
    });
  }
}

/// Two letters for the account chip, from the GitHub login or email.
String _initialsFor(Me? me) {
  final source = me?.githubLogin ?? me?.email ?? '';
  final letters = source.replaceAll(RegExp(r'[^A-Za-z]'), '');
  if (letters.isEmpty) return 'RW';
  return letters.substring(0, letters.length >= 2 ? 2 : 1).toUpperCase();
}

class _Header extends StatelessWidget {
  const _Header({required this.services, required this.onReplayBanner, required this.onOpenMandate});

  final List<RenderService> services;
  final VoidCallback onReplayBanner;
  final VoidCallback onOpenMandate;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final initials = _initialsFor(AppScope.of(context).me);
    final down = services.where((s) => s.health == ServiceHealth.down).toList();
    final headline = services.isEmpty
        ? 'Nothing watched yet'
        : down.isEmpty
            ? 'All services healthy'
            : '${down.length} service${down.length == 1 ? ' is' : 's are'} down';
    final sub = services.isEmpty
        ? 'Pick the services the agent should watch'
        : down.isEmpty
            ? 'The agent is watching ${services.length} '
                'service${services.length == 1 ? '' : 's'}'
            : '${down.first.name} needs you · ${services.length - down.length} others look fine';

    return Padding(
      padding: EdgeInsets.fromLTRB(context.gutter, 8, context.gutter, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: 48,
          child: Row(children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: AppColors.accentStrong, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.radar_rounded, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Render Watcher',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            Pressable(
              onTap: onReplayBanner,
              semanticLabel: 'Watching ${services.length} services',
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(Radii.pill),
              child: Container(
                height: 34,
                padding: const EdgeInsets.only(left: 6, right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Radii.pill),
                  border: Border.all(color: const Color(0xFF262A36)),
                ),
                child: const Row(children: [
                  LiveDot(size: 6),
                  Text('Watching', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Mandate and account',
              child: Pressable(
                onTap: onOpenMandate,
                semanticLabel: 'Mandate and account',
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(40),
                child: SizedBox.square(
                  dimension: 40,
                  child: Center(
                    child: Text(initials,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ),
          ]),
        ),
        SizedBox(height: context.isShort ? 10 : 18),
        Text(headline,
            style: t.headlineMedium?.copyWith(fontSize: context.displaySize(32), height: 1.2)),
        const SizedBox(height: 6),
        Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyMedium),
      ]),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.services, required this.showHandle});

  final List<RenderService> services;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    final counts = <ServiceHealth, int>{};
    for (final s in services) {
      counts[s.health] = (counts[s.health] ?? 0) + 1;
    }
    final summary = [
      for (final h in ServiceHealth.values)
        if ((counts[h] ?? 0) > 0) '${counts[h]} ${h.label.toLowerCase()}',
    ].join(' · ');

    return Padding(
      padding: EdgeInsets.fromLTRB(context.gutter, showHandle ? 10 : 20, context.gutter, 6),
      child: Column(children: [
        if (showHandle) ...[
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(color: AppColors.handle, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(height: 14),
        ],
        Row(children: [
          Expanded(
            child: Text(summary,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          ),
        ]),
      ]),
    );
  }
}

class _SheetContent {
  const _SheetContent({
    required this.services,
    required this.loading,
    required this.state,
    required this.onOpenLogs,
    required this.onOpenMandate,
  });

  final List<RenderService> services;
  final bool loading;
  final AppState state;
  final ValueChanged<String?> onOpenLogs;
  final VoidCallback onOpenMandate;

  List<Widget> slivers(BuildContext context, double bottomInset) {
    final g = context.gutter;
    return [
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: g),
        sliver: SliverList.list(children: [
          SectionLabel('Watched',
              trailing: Pressable(
                onTap: onOpenMandate,
                borderRadius: BorderRadius.circular(Radii.pill),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text('Edit',
                      style: TextStyle(
                          color: AppColors.accentText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              )),
          AnimatedSwitcher(
            duration: Motion.tab,
            switchInCurve: Motion.decelerate,
            child: loading
                ? const Skeleton(
                    key: ValueKey('skel'),
                    child: Column(children: [RowSkeleton(), RowSkeleton(), RowSkeleton()]),
                  )
                : services.isEmpty
                    ? Padding(
                        key: const ValueKey('empty'),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          state.overviewError ??
                              'No services watched. Open Mandate to pick some.',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: state.overviewError != null
                                ? AppColors.criticalText
                                : AppColors.textMuted,
                          ),
                        ),
                      )
                    : Column(key: const ValueKey('rows'), children: [
                        for (var i = 0; i < services.length; i++)
                          FadeSlideIn(
                            delay: Duration(milliseconds: 40 * i),
                            offset: 8,
                            child: _ServiceRow(
                              service: services[i],
                              last: i == services.length - 1,
                              onTap: () => onOpenLogs(services[i].id),
                            ),
                          ),
                      ]),
          ),
          const SizedBox(height: 18),
          Pressable(
            onTap: onOpenMandate,
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(Radii.card),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.verified_user_outlined, size: 18, color: AppColors.accentText),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                        state.autoRestart && state.actionsEnabled
                            ? 'Notify + auto-restart'
                            : 'Notify-only mode',
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                        'Gate ${state.gate}% · verifier ${state.verifier ? 'on' : 'off'} · '
                        '${state.mandate.maxAlertsPerHour} alerts/h max',
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textFaint),
              ]),
            ),
          ),
          const SectionLabel('Today'),
          if (state.recentActivity.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                loading ? 'Loading…' : 'Nothing yet today.',
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            )
          else
            for (final e in state.recentActivity) _TodayRow(entry: e),
          SizedBox(height: bottomInset + 16),
        ]),
      ),
    ];
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.service, required this.last, required this.onTap});

  final RenderService service;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      borderRadius: BorderRadius.zero,
      semanticLabel: '${service.name}, ${service.health.label}. Open live logs.',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: last ? null : const Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
            child: Icon(service.kind.icon, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(service.name, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500)),
              const SizedBox(height: 3),
              Text(service.vitals,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.mono(size: 11.5)),
            ]),
          ),
          const SizedBox(width: 8),
          Pill(service.health.label, color: service.health.text),
        ]),
      ),
    );
  }
}

class _TodayRow extends StatelessWidget {
  const _TodayRow({required this.entry});

  final ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    final dot = switch (entry.actor) {
      Actor.agent => AppColors.accent,
      Actor.verifier => AppColors.ok,
      Actor.you => const Color(0xFF4A4F5E),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(TextSpan(children: [
            TextSpan(text: '${entry.action}  ', style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: entry.detail, style: const TextStyle(color: AppColors.textMuted)),
          ]), style: const TextStyle(fontSize: 14, height: 1.45)),
        ),
        const SizedBox(width: 8),
        Text(entry.time, style: AppText.mono(size: 11.5, color: AppColors.textFaint)),
      ]),
    );
  }
}
