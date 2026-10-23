import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../motion/transitions.dart';
import '../../theme/app_theme.dart';
import '../../theme/responsive.dart';
import '../../theme/tokens.dart';
import '../shell/home_shell.dart';

/// Audit log as one timeline, like Uber's Activity hub: every observation,
/// decision and action with the evidence behind it.
class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key, required this.bottomInset, required this.onChromeHidden});

  final double bottomInset;
  final ValueChanged<bool> onChromeHidden;

  @override
  Widget build(BuildContext context) {
    final g = context.gutter;
    const entries = MockData.activity;
    return NotificationListener<UserScrollNotification>(
      onNotification: (n) => handleChromeScroll(n, onChromeHidden),
      child: CustomScrollView(slivers: [
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
              child: TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.ios_share_rounded, size: 16),
                label: const Text('Export'),
                style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
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
          padding: centeredSliverPadding(context, top: 12, bottom: bottomInset),
          sliver: SliverList.builder(
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final row = _TimelineRow(entry: entries[i], last: i == entries.length - 1);
              // Only the first screenful staggers in; later rows just appear.
              return i < 7 ? FadeSlideIn(delay: Duration(milliseconds: 45 * i), child: row) : row;
            },
          ),
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
