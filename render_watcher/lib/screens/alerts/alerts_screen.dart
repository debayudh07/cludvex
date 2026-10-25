import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../motion/haptics.dart';
import '../../motion/transitions.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/responsive.dart';
import '../../theme/tokens.dart';
import '../../widgets/primitives.dart';
import '../shell/home_shell.dart';

/// YouTube-feed pattern: a floating app bar with filter chips that hides on
/// scroll down and snaps back on scroll up. Chip changes fade through.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({
    super.key,
    required this.bottomInset,
    required this.onOpen,
    required this.onChromeHidden,
  });

  final double bottomInset;
  final void Function(Alert alert, Rect source) onOpen;
  final ValueChanged<bool> onChromeHidden;

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(vsync: this, duration: Motion.tab, value: 1);
  late final _fadeCurve = CurvedAnimation(parent: _fade, curve: Motion.decelerate);

  @override
  void dispose() {
    _fadeCurve.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => AppScope.read(context).refreshAlerts());
  }

  void _pick(AppState state, AlertFilter f) {
    if (f == state.filter) return;
    Haptics.selection();
    state.setFilter(f);
    if (!context.reduceMotion) _fade.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final alerts = state.filteredAlerts;
    final loading = state.alertsLoading && alerts.isEmpty;
    final g = context.gutter;

    return NotificationListener<UserScrollNotification>(
      onNotification: (n) => handleChromeScroll(n, widget.onChromeHidden),
      child: RefreshIndicator(
          onRefresh: () => Future.wait([state.refreshAlerts(), state.refreshOverview()]),
          backgroundColor: AppColors.surface2,
          color: AppColors.accentText,
          child: CustomScrollView(slivers: [
        SliverAppBar(
          floating: true,
          snap: true,
          pinned: context.isExpanded,
          toolbarHeight: 60,
          titleSpacing: g,
          automaticallyImplyLeading: false,
          title: Text('Alerts',
              style: TextStyle(fontSize: context.displaySize(26), fontWeight: FontWeight.w700, letterSpacing: -0.8)),
          actions: [
            Padding(
              padding: EdgeInsets.only(right: g),
              child: Center(
                child: Text(
                    '${state.evidenceLineCount} lines → ${state.openAlertCount} alerts',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.fromLTRB(g, 4, g, 12),
                itemCount: AlertFilter.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final f = AlertFilter.values[i];
                  return FilterChipX(
                    label: f.label,
                    selected: state.filter == f,
                    onTap: () => _pick(state, f),
                  );
                },
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: centeredSliverPadding(context, top: 8, bottom: widget.bottomInset),
          sliver: SliverFadeTransition(
            opacity: _fadeCurve,
            sliver: loading
                ? const SliverToBoxAdapter(child: _LoadingList())
                : alerts.isEmpty
                    ? SliverToBoxAdapter(child: _EmptyState(error: state.alertsError))
                    : SliverList.separated(
                        itemCount: alerts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) => AlertCard(
                          alert: alerts[i],
                          gate: state.gate,
                          serviceName: alerts[i].serviceName ??
                              state.serviceById(alerts[i].serviceId)?.name ??
                              alerts[i].serviceId,
                          onOpen: widget.onOpen,
                        ),
                      ),
          ),
        ),
      ])),
    );
  }
}

class AlertCard extends StatelessWidget {
  const AlertCard({
    super.key,
    required this.alert,
    required this.gate,
    required this.onOpen,
    this.serviceName,
  });

  final Alert alert;
  final int gate;
  final void Function(Alert alert, Rect source) onOpen;
  final String? serviceName;

  @override
  Widget build(BuildContext context) {
    final name = serviceName ?? alert.serviceName ?? alert.serviceId;
    // The backend already decided this (gate + verifier); fall back to the
    // local gate only when the field is absent.
    final yourCall = alert.needsReview || (alert.isOpen && alert.confidence * 100 < gate);
    return Builder(builder: (cardContext) {
      return Opacity(
        opacity: alert.isOpen ? 1 : 0.62,
        child: Pressable(
          onTap: () => onOpen(alert, rectOf(cardContext)),
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(Radii.card),
          semanticLabel: '${alert.severity.label}: ${alert.title} on $name. '
              'Agent ${(alert.confidence * 100).round()} percent sure.',
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(width: 3, color: alert.severity.bar),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(15, 14, 14, 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Pill(alert.severity.label, color: alert.severity.text),
                      if (yourCall) ...[
                        const SizedBox(width: 6),
                        const Pill('YOUR CALL', color: AppColors.accentText),
                      ],
                      const Spacer(),
                      Text(alert.timeAgoLabel,
                          style: AppText.mono(size: 11.5, color: AppColors.textFaint)),
                    ]),
                    const SizedBox(height: 8),
                    Text(alert.title,
                        style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, letterSpacing: -0.2)),
                    const SizedBox(height: 4),
                    Text(alert.summary, style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 10),
                    Row(children: [
                      Flexible(
                        child: Text(name,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.mono(size: 11.5, color: AppColors.textSecondary)),
                      ),
                      Text('  ·  ×${alert.occurrences}', style: AppText.mono(size: 11.5)),
                      const Spacer(),
                      ConfidenceArc(value: alert.confidence, size: 18, stroke: 2.5, animate: false, showLabel: false),
                      const SizedBox(width: 6),
                      Text('${(alert.confidence * 100).round()}%',
                          style: AppText.mono(size: 11.5, color: AppColors.accentText, weight: FontWeight.w600)),
                    ]),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      );
    });
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return const Skeleton(
      child: Column(children: [
        RowSkeleton(widthFactor: 0.62),
        RowSkeleton(widthFactor: 0.48),
        RowSkeleton(widthFactor: 0.56),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    final failed = error != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(children: [
        Icon(failed ? Icons.cloud_off_rounded : Icons.inbox_outlined,
            size: 32, color: AppColors.textFaint),
        const SizedBox(height: 12),
        Text(failed ? "Couldn't load alerts" : 'Nothing here',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(error ?? "The agent hasn't flagged anything in this filter.",
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted)),
      ]),
    );
  }
}
