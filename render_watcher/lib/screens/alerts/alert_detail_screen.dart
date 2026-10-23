import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../motion/haptics.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/responsive.dart';
import '../../theme/tokens.dart';
import '../../widgets/confirm_sheet.dart';
import '../../widgets/primitives.dart';

/// What the user chose; the shell turns it into a toast or a navigation.
enum DetailAction { ignored, silenced, restarted, logs }

/// Opened with a container transform from its alert card. Laid out like
/// Uber's trip-status sheet: status headline, the agent's read, grouped
/// actions, then evidence.
class AlertDetailScreen extends StatelessWidget {
  const AlertDetailScreen({super.key, required this.alert});

  final Alert alert;

  Future<void> _restart(BuildContext context, AppState state) async {
    final service = MockData.service(alert.serviceId);
    final ok = await showConfirmSheet(
      context,
      title: 'Restart ${service.name}?',
      body: state.autoRestart
          ? 'The agent is allowed to do this. You are doing it by hand now.'
          : "This is outside the agent's mandate, so it needs your tap. "
              'Render redeploys the current image.',
      points: ['About 30 seconds of downtime', 'Logged to Activity with ${alert.occurrences} evidence lines'],
      confirmLabel: 'Restart now',
    );
    if (ok && context.mounted) Navigator.of(context).pop(DetailAction.restarted);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final service = MockData.service(alert.serviceId);
    final t = Theme.of(context).textTheme;
    final aboveGate = alert.confidence * 100 >= state.gate;
    final g = context.gutter;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(slivers: [
          SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: false,
            toolbarHeight: 60,
            titleSpacing: g - 8,
            title: CircleIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back',
              onTap: () => Navigator.of(context).maybePop(),
            ),
            actions: [
              Padding(
                padding: EdgeInsets.only(right: g),
                child: Center(child: Text(alert.code, style: AppText.mono(color: AppColors.textFaint))),
              ),
            ],
          ),
          SliverPadding(
            padding: centeredSliverPadding(context, maxWidth: 680, top: 4,
                bottom: 32 + MediaQuery.paddingOf(context).bottom),
            sliver: SliverList.list(children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                Pill(alert.severity.label, color: alert.severity.text),
                if (alert.verified)
                  const Pill('Verifier agrees', color: AppColors.okText, icon: Icons.check_rounded),
              ]),
              const SizedBox(height: 12),
              Text(alert.headline,
                  style: t.headlineSmall?.copyWith(fontSize: context.displaySize(28), height: 1.2)),
              const SizedBox(height: 8),
              Text('${service.name} · ×${alert.occurrences} · ${alert.since}', style: AppText.mono()),
              const SizedBox(height: 20),

              // Agent's read
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: BorderRadius.circular(Radii.panel),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    ConfidenceArc(value: alert.confidence),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.accentText),
                          const SizedBox(width: 6),
                          Text("AGENT'S READ", style: AppText.label.copyWith(color: AppColors.accentText)),
                        ]),
                        const SizedBox(height: 4),
                        Text(
                          aboveGate
                              ? 'Above your ${state.gate}% gate, so it alerted you directly.'
                              : 'Under your ${state.gate}% gate, so it is asking, not telling.',
                          style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
                        ),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Text(alert.cause,
                      style: t.bodyLarge?.copyWith(fontSize: 15, color: const Color(0xFFDADDE6))),
                  const SizedBox(height: 8),
                  Text(alert.suggestion, style: t.bodyMedium),
                ]),
              ),
              const SizedBox(height: 14),

              _ActionGroup(actions: [
                _Action(Icons.restart_alt_rounded, 'Restart', () => _restart(context, state)),
                _Action(Icons.terminal_rounded, 'Logs', () => Navigator.of(context).pop(DetailAction.logs)),
                _Action(Icons.notifications_off_outlined, 'Silence 1h', () {
                  Haptics.light();
                  Navigator.of(context).pop(DetailAction.silenced);
                }),
                _Action(Icons.close_rounded, 'Ignore', () => Navigator.of(context).pop(DetailAction.ignored)),
              ]),

              SectionLabel('Evidence · ${alert.occurrences} lines'),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.logBg,
                  borderRadius: BorderRadius.circular(Radii.card),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(children: [for (final e in alert.evidence) _EvidenceRow(line: e)]),
              ),
              const SizedBox(height: 14),
              Text(
                state.autoRestart
                    ? 'Auto-restart is on in your mandate. The agent would act on its own above ${state.gate}%.'
                    : 'Restart is outside your mandate, so it asks you first. Change this in Mandate.',
                style: const TextStyle(fontSize: 12.5, color: AppColors.textFaint, height: 1.5),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Action {
  const _Action(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// YouTube's 2025 grouped pill: related actions in one rounded container.
class _ActionGroup extends StatelessWidget {
  const _ActionGroup({required this.actions});

  final List<_Action> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const VerticalDivider(width: 1, indent: 14, endIndent: 14, color: Color(0xFF262A36)),
            Expanded(
              child: Pressable(
                onTap: actions[i].onTap,
                borderRadius: BorderRadius.zero,
                semanticLabel: actions[i].label,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 68),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(actions[i].icon, size: 21),
                    const SizedBox(height: 5),
                    Text(actions[i].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({required this.line});

  final EvidenceLine line;

  @override
  Widget build(BuildContext context) {
    final base = AppText.mono(size: 11.5, color: AppColors.textSecondary, height: 1.5);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Text.rich(
        TextSpan(style: base, children: [
          TextSpan(text: '${line.time}  ', style: base.copyWith(color: AppColors.textGhost)),
          TextSpan(text: '${line.level.label}  ', style: base.copyWith(color: line.level.color, fontWeight: FontWeight.w600)),
          TextSpan(text: line.before),
          TextSpan(
            text: line.highlight,
            style: base.copyWith(
              color: const Color(0xFFE4DAFF),
              background: Paint()..color = AppColors.accent.withValues(alpha: 0.22),
            ),
          ),
          TextSpan(text: line.after),
        ]),
      ),
    );
  }
}
