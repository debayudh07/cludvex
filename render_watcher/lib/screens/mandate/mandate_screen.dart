import 'package:flutter/material.dart';

import '../../motion/haptics.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/responsive.dart';
import '../../theme/tokens.dart';
import '../../widgets/confirm_sheet.dart';
import '../onboarding/onboarding_flow.dart';
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

  @override
  void initState() {
    super.initState();
    // The shell loads this at bootstrap; refetch so a change made on another
    // device shows up.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => AppScope.read(context).refreshMandate());
  }

  void _setRestart(AppState state, bool on) {
    state.editMandate(state.mandate.copyWith(autoRestart: on), immediate: true);
  }

  Future<void> _grantRestart(AppState state) async {
    if (!state.actionsEnabled) {
      state.showToast('This server runs notify-only (ACTIONS_ENABLED is off)');
      return;
    }
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
    _setRestart(state, true);
    state.showToast('Mandate updated', onUndo: () => _setRestart(state, false));
  }

  void _revokeRestart(AppState state) {
    _setRestart(state, false);
    state.showToast('Back to asking every time', onUndo: () => _grantRestart(state));
  }

  Future<void> _disconnectRender(AppState state) async {
    final ok = await showConfirmSheet(
      context,
      title: 'Remove the Render key?',
      body: 'The agent stops watching every service straight away. '
          'You can paste a new key any time.',
      points: const ['Alerts already raised stay in your history'],
      confirmLabel: 'Remove key',
      icon: Icons.key_off_rounded,
      tone: AppColors.criticalText,
      heavy: true,
    );
    if (!ok || !mounted) return;
    try {
      await state.repo.disconnectRender();
      if (!mounted) return;
      // Still signed in, just without Render: send them back to the key step
      // rather than all the way out.
      await state.bootstrap();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (_) => const OnboardingFlow(start: OnboardingStep.apiKey)),
        (route) => false,
      );
    } catch (e) {
      if (mounted) state.showToast('$e');
    }
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
                onChanged: (v) =>
                    state.editMandate(state.mandate.copyWith(pushAlerts: v), immediate: true),
              ),
              _SwitchRow(
                title: 'Verifier agent',
                subtitle: 'A second pass tries to disprove each diagnosis',
                value: state.verifier,
                onChanged: (v) =>
                    state.editMandate(state.mandate.copyWith(verifier: v), immediate: true),
              ),
              _SwitchRow(
                title: 'Group repeated lines',
                subtitle: 'Same error, one alert',
                value: state.groupLines,
                onChanged: (v) =>
                    state.editMandate(state.mandate.copyWith(groupLines: v), immediate: true),
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
                  subtitle: !state.actionsEnabled
                      ? 'Notify-only on this server'
                      : state.autoRestart
                          ? 'Agent may restart above ${state.gate}%'
                          : 'Asks you every time',
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
                            'logged with its evidence.'
                            '${state.actionsEnabled ? '' : ' This server is running notify-only, '
                                'so the power cannot be granted yet.'}',
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
                                  onPressed:
                                      state.actionsEnabled ? () => _grantRestart(state) : null,
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
                onChangeEnd: (v) =>
                    state.editMandate(state.mandate.copyWith(gate: v.round()), immediate: true),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text("Below this the agent says it's unsure and asks you to look.",
                    style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
              ),
            ]),

            const SectionLabel('Noise limit'),
            _Card(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(children: [
                  const Expanded(
                    child: Text('At most, per hour',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                  Text('${state.mandate.maxAlertsPerHour}',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.accentText)),
                ]),
              ),
              Slider(
                value: state.mandate.maxAlertsPerHour.toDouble(),
                min: 1,
                max: 20,
                divisions: 19,
                label: '${state.mandate.maxAlertsPerHour}',
                onChanged: (v) {
                  if (v.round() != state.mandate.maxAlertsPerHour) Haptics.selection();
                  state.editMandate(state.mandate.copyWith(maxAlertsPerHour: v.round()));
                },
                onChangeEnd: (v) => state.editMandate(
                    state.mandate.copyWith(maxAlertsPerHour: v.round()),
                    immediate: true),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  'Beyond this the agent holds alerts back and notes it in Activity.'
                  '${state.mandate.quietStart != null && state.mandate.quietEnd != null ? ' '
                      'Quiet hours ${state.mandate.quietStart}–${state.mandate.quietEnd} '
                      '(${state.mandate.timezone}); critical still gets through.' : ''}',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                ),
              ),
            ]),

            const SectionLabel('Render'),
            _Card(children: [
              _Row(
                title: state.me?.keyLast4 != null
                    ? 'rnd_••••${state.me!.keyLast4}'
                    : 'No key connected',
                titleStyle: AppText.mono(size: 14, color: AppColors.text),
                subtitle: state.me?.renderConnected == true
                    ? 'Encrypted on the backend · never on this phone'
                    : 'Paste a Render key to start watching',
                trailing: OutlinedButton(
                  onPressed: state.me?.renderConnected == true
                      ? () => _disconnectRender(state)
                      : null,
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
