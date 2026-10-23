import 'package:flutter/material.dart';

import '../../motion/haptics.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/responsive.dart';
import '../../theme/tokens.dart';
import '../../widgets/confirm_sheet.dart';
import '../../widgets/primitives.dart';

/// What the agent may do on its own, grouped by risk. Riskier powers stay
/// folded away and need a confirmation to grant (progressive disclosure
/// with deliberate friction). Pushed with the platform's default route, so
/// Android keeps the predictive-back peek.
class MandateScreen extends StatefulWidget {
  const MandateScreen({super.key});

  @override
  State<MandateScreen> createState() => _MandateScreenState();
}

class _MandateScreenState extends State<MandateScreen> {
  bool _restartOpen = false;

  Future<void> _grantRestart(AppState state) async {
    final ok = await showConfirmSheet(
      context,
      title: 'Let the agent restart services?',
      body: 'It will only restart when it is above your ${state.gate}% gate and the '
          'verifier agrees. You get a notification every time.',
      points: const ['At most one restart per service per hour', 'You can switch this off any time'],
      confirmLabel: 'Allow auto-restart',
      icon: Icons.gpp_maybe_outlined,
      tone: AppColors.warningText,
      heavy: true,
    );
    if (!ok || !mounted) return;
    state.update(() => state.autoRestart = true);
    state.showToast('Mandate updated', onUndo: () => state.update(() => state.autoRestart = false));
  }

  void _revokeRestart(AppState state) {
    state.update(() => state.autoRestart = false);
    state.showToast('Back to asking every time', onUndo: () => state.update(() => state.autoRestart = true));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar.large(
          leading: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Center(
              child: CircleIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
          leadingWidth: 64,
          title: const Text('Mandate', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.8)),
        ),
        SliverPadding(
          padding: centeredSliverPadding(context, maxWidth: 640,
              bottom: 40 + MediaQuery.paddingOf(context).bottom),
          sliver: SliverList.list(children: [
            Text(
              'What the agent may do without asking you. Riskier powers stay folded '
              'away until you reach for them.',
              style: t.bodyLarge?.copyWith(color: AppColors.textMuted),
            ),

            const SectionLabel('Observe'),
            const _Card(children: [
              _Row(
                title: 'Read production logs',
                subtitle: 'Required for the agent to work',
                trailing: Icon(Icons.check_rounded, color: AppColors.okText),
              ),
            ]),

            const SectionLabel('Notify'),
            _Card(children: [
              _SwitchRow(
                title: 'Push alerts',
                subtitle: 'Serious issues only, via FCM',
                value: state.pushAlerts,
                onChanged: (v) => state.update(() => state.pushAlerts = v),
              ),
              _SwitchRow(
                title: 'Verifier agent',
                subtitle: 'A second pass tries to disprove each diagnosis',
                value: state.verifier,
                onChanged: (v) => state.update(() => state.verifier = v),
              ),
              _SwitchRow(
                title: 'Group repeated lines',
                subtitle: 'Same error, one alert',
                value: state.groupLines,
                onChanged: (v) => state.update(() => state.groupLines = v),
              ),
            ]),

            const SectionLabel('Act · changes production', color: AppColors.warningText),
            _Card(children: [
              InkWell(
                onTap: () {
                  Haptics.selection();
                  setState(() => _restartOpen = !_restartOpen);
                },
                child: _Row(
                  title: 'Restart a service',
                  subtitle: state.autoRestart ? 'Agent may restart above ${state.gate}%' : 'Asks you every time',
                  trailing: AnimatedRotation(
                    turns: _restartOpen ? 0.5 : 0,
                    duration: Motion.tab,
                    curve: Motion.standard,
                    child: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted),
                  ),
                ),
              ),
              AnimatedSize(
                duration: Motion.tab,
                curve: Motion.standard,
                alignment: Alignment.topCenter,
                child: !_restartOpen
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Text(
                            "The agent could restart a crash-looping service on its own when it's "
                            'above ${state.gate}% sure and the verifier agrees. Each restart is '
                            'logged with its evidence.',
                            style: const TextStyle(fontSize: 13.5, height: 1.5, color: Color(0xFFB4B9C7)),
                          ),
                          const SizedBox(height: 12),
                          state.autoRestart
                              ? OutlinedButton(
                                  onPressed: () => _revokeRestart(state),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(48),
                                    foregroundColor: AppColors.text,
                                    side: const BorderSide(color: AppColors.outline),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.control)),
                                  ),
                                  child: const Text('Ask me every time again'),
                                )
                              : OutlinedButton(
                                  onPressed: () => _grantRestart(state),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(48),
                                    foregroundColor: const Color(0xFFE2BE6E),
                                    backgroundColor: AppColors.warning.withValues(alpha: 0.10),
                                    side: BorderSide(color: AppColors.warningText.withValues(alpha: 0.45)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.control)),
                                  ),
                                  child: const Text('Allow without asking…'),
                                ),
                        ]),
                      ),
              ),
              const Opacity(
                opacity: 0.7,
                child: _Row(
                  title: 'Roll back a deploy',
                  subtitle: "Always asks · can't be delegated",
                  trailing: Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.textMuted),
                ),
              ),
            ]),

            const SectionLabel('Confidence gate'),
            _Card(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(children: [
                  const Expanded(
                    child: Text('Alert as fact above', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                  Text('${state.gate}%',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.accentText)),
                ]),
              ),
              Slider(
                value: state.gate.toDouble(),
                min: 50,
                max: 95,
                divisions: 9,
                label: '${state.gate}%',
                onChanged: (v) {
                  if (v.round() != state.gate) Haptics.selection();
                  state.setGate(v.round());
                },
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text("Below this the agent says it's unsure and asks you to look.",
                    style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
              ),
            ]),

            const SectionLabel('Render'),
            _Card(children: [
              _Row(
                title: 'rnd_••••x7Q2',
                titleStyle: AppText.mono(size: 14, color: AppColors.text),
                subtitle: 'Encrypted on our backend · added 23 Oct',
                trailing: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.criticalText,
                    side: BorderSide(color: AppColors.critical.withValues(alpha: 0.4)),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Remove'),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface1,
      borderRadius: BorderRadius.circular(Radii.card),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
          children[i],
        ],
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.title, required this.subtitle, this.trailing, this.titleStyle});

  final String title;
  final String subtitle;
  final Widget? trailing;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: titleStyle ?? const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          ]),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ]),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.title, required this.subtitle, required this.value, required this.onChanged});

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: InkWell(
        onTap: () {
          Haptics.selection();
          onChanged(!value);
        },
        child: _Row(
          title: title,
          subtitle: subtitle,
          trailing: Switch(
            value: value,
            onChanged: (v) {
              Haptics.selection();
              onChanged(v);
            },
          ),
        ),
      ),
    );
  }
}
