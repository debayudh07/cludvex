import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../motion/transitions.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/responsive.dart';
import '../../theme/tokens.dart';
import '../../widgets/primitives.dart';
import '../shell/home_shell.dart';

/// Audit log as one timeline, like Uber's Activity hub: every observation,
/// decision and action with the evidence behind it.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key, required this.bottomInset, required this.onChromeHidden});

  final double bottomInset;
  final ValueChanged<bool> onChromeHidden;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => AppScope.read(context).refreshActivity());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// `GET /activity` pages with a `before` timestamp cursor.
  void _maybeLoadMore() {
    if (!_scroll.hasClients) return;
    final left = _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (left < 600) AppScope.read(context).loadMoreActivity();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.gutter;
    final state = AppScope.of(context);
    final entries = state.activity;
    final loading = state.activityLoading && entries.isEmpty;
    return NotificationListener<UserScrollNotification>(
      onNotification: (n) => handleChromeScroll(n, widget.onChromeHidden),
      child: RefreshIndicator(
        onRefresh: state.refreshActivity,
        backgroundColor: AppColors.surface2,
        color: AppColors.accentText,
        child: CustomScrollView(controller: _scroll, slivers: [
        SliverAppBar(
          floating: true,
          snap: true,
          toolbarHeight: 60,
          titleSpacing: g,
          automaticallyImplyLeading: false,
          title: Text('Activity',
              style: TextStyle(fontSize: context.displaySize(26), fontWeight: FontWeight.w700, letterSpacing: -0.8)),
          actions: [
            Padding(
              padding: EdgeInsets.only(right: g - 8),
              child: IconButton(
                onPressed: state.refreshActivity,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: 'Refresh',
                color: AppColors.textSecondary,
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(32),
            child: Padding(
              padding: EdgeInsets.fromLTRB(g, 0, g, 12),
              child: const Align(
                alignment: Alignment.centerLeft,
                child: Text('Every alert and action, with the evidence behind it.',
                    style: TextStyle(fontSize: 13.5, color: AppColors.textMuted)),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: centeredSliverPadding(context, top: 12, bottom: widget.bottomInset),
          sliver: loading
              ? const SliverToBoxAdapter(
                  child: Skeleton(
                    child: Column(children: [
                      RowSkeleton(leading: 36, widthFactor: 0.6),
                      RowSkeleton(leading: 36, widthFactor: 0.45),
                      RowSkeleton(leading: 36, widthFactor: 0.52),
                      RowSkeleton(leading: 36, widthFactor: 0.4),
                    ]),
                  ),
                )
              : entries.isEmpty
                  ? SliverToBoxAdapter(child: _EmptyActivity(error: state.activityError))
                  : SliverList.builder(
                      itemCount: entries.length + (state.activityHasMore ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i >= entries.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.2, color: AppColors.textFaint),
                              ),
                            ),
                          );
                        }
                        final row = _TimelineRow(
                          entry: entries[i],
                          last: i == entries.length - 1 && !state.activityHasMore,
                        );
                        // Only the first screenful staggers in.
                        return i < 7
                            ? FadeSlideIn(delay: Duration(milliseconds: 45 * i), child: row)
                            : row;
                      },
                    ),
        ),
      ]),
      ),
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    final failed = error != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(children: [
        Icon(failed ? Icons.cloud_off_rounded : Icons.history_rounded,
            size: 32, color: AppColors.textFaint),
        const SizedBox(height: 12),
        Text(failed ? "Couldn't load activity" : 'Nothing logged yet',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(
          error ?? 'Every observation, decision and action will appear here.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted),
        ),
      ]),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.entry, required this.last});

  final ActivityEntry entry;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = switch (entry.actor) {
      Actor.agent => ('AI', AppColors.accentText, AppColors.accent.withValues(alpha: 0.16)),
      Actor.verifier => ('V', AppColors.okText, AppColors.ok.withValues(alpha: 0.14)),
      Actor.you => ('You', AppColors.textSecondary, AppColors.surface2),
    };
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 36,
          child: Column(children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
            if (!last)
              Expanded(
                child: Container(
                  width: 2,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(1)),
                ),
              ),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 22, top: 2),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Expanded(
                  child: Text(entry.action, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                Text(entry.time, style: AppText.mono(size: 11.5, color: AppColors.textFaint)),
              ]),
              const SizedBox(height: 4),
              Text(entry.detail, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(entry.meta, style: AppText.mono(size: 11, color: const Color(0xFF7A8196))),
            ]),
          ),
        ),
      ]),
    );
  }
}
