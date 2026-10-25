import 'package:flutter/material.dart';

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
class AlertDetailScreen extends StatefulWidget {
  const AlertDetailScreen({super.key, required this.alert});

  /// The list row's copy, which GET /alerts returns without evidence. The
  /// full record is fetched on open so the screen paints immediately.
  final Alert alert;

  @override
  State<AlertDetailScreen> createState() => _AlertDetailScreenState();
}

class _AlertDetailScreenState extends State<AlertDetailScreen> {
  late Alert _alert = widget.alert;
  bool _loadingEvidence = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (!_alert.hasEvidence) _loadEvidence();
  }

  Future<void> _loadEvidence() async {
    setState(() => _loadingEvidence = true);
    try {
      final full = await AppScope.read(context).alertDetail(_alert.id);
      if (mounted) setState(() => _alert = full);
    } catch (_) {
      // The summary already on screen is still useful; leave it be.
    } finally {
      if (mounted) setState(() => _loadingEvidence = false);
    }
  }

  Future<void> _restart(AppState state) async {
    final name = _serviceName(state);
    final ok = await showConfirmSheet(
      context,
      title: 'Restart $name?',
      body: state.autoRestart
          ? 'The agent is allowed to do this. You are doing it by hand now.'
          : "This is outside the agent's mandate, so it needs your tap. "
              'Render redeploys the current image.',
      points: [
        'About 30 seconds of downtime',
        'Logged to Activity with ${_alert.occurrences} evidence lines',
      ],
      confirmLabel: 'Restart now',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final error = await state.restart(_alert.id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      state.showToast(error);
      return;
    }
    Navigator.of(context).pop(DetailAction.restarted);
  }

  String _serviceName(AppState state) =>
      _alert.serviceName ?? state.serviceById(_alert.serviceId)?.name ?? _alert.serviceId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final alert = _alert;
    final serviceName = _serviceName(state);
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
              Text('$serviceName · ×${alert.occurrences} · ${alert.sinceText}',
                  style: AppText.mono()),
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
                // v1 is notify-only unless the server sets ACTIONS_ENABLED.
                if (state.actionsEnabled)
                  _Action(Icons.restart_alt_rounded, 'Restart', _busy ? null : () => _restart(state)),
                _Action(Icons.terminal_rounded, 'Logs',
                    () => Navigator.of(context).pop(DetailAction.logs)),
                _Action(Icons.notifications_off_outlined, 'Silence 1h', () {
                  Haptics.light();
                  Navigator.of(context).pop(DetailAction.silenced);
                }),
                _Action(Icons.close_rounded, 'Ignore',
                    () => Navigator.of(context).pop(DetailAction.ignored)),
              ]),

              SectionLabel('Evidence · ${alert.occurrences} lines'),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.logBg,
                  borderRadius: BorderRadius.circular(Radii.card),
                  border: Border.all(color: AppColors.divider),
                ),
                child: _loadingEvidence && alert.evidence.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Skeleton(
                          child: Column(children: [
                            Bone(height: 10, width: 260),
                            SizedBox(height: 8),
                            Bone(height: 10, width: 200),
                            SizedBox(height: 8),
                            Bone(height: 10, width: 230),
                          ]),
                        ),
                      )
                    : alert.evidence.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Text('No log lines were stored for this alert.',
                                style: AppText.mono(size: 11.5, color: AppColors.textFaint)),
                          )
                        : Column(
                            children: [for (final e in alert.evidence) _EvidenceRow(line: e)]),
              ),
              const SizedBox(height: 14),
              Text(
                !state.actionsEnabled
                    ? 'This server runs notify-only, so the agent never touches production. '
                        'Restart is unavailable until the operator enables actions.'
                    : state.autoRestart
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

  /// null while the action is in flight.
  final VoidCallback? onTap;
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
              child: Opacity(
                opacity: actions[i].onTap == null ? 0.5 : 1,
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
