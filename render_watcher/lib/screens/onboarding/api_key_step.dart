import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/api_client.dart';
import '../../motion/haptics.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/primitives.dart';
import 'onboarding_flow.dart';

enum _KeyState { idle, checking, connected }

class ApiKeyStep extends StatefulWidget {
  const ApiKeyStep({super.key, required this.onConnected});

  final VoidCallback onConnected;

  @override
  State<ApiKeyStep> createState() => _ApiKeyStepState();
}

class _ApiKeyStepState extends State<ApiKeyStep> with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  late final _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  _KeyState _state = _KeyState.idle;
  bool _invalid = false;
  String? _serverError;
  int _found = 0;
  Timer? _timer;

  static final _pattern = RegExp(r'^rnd_[A-Za-z0-9]{8,}$');

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shake.dispose();
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      setState(() => _serverError = 'Nothing on the clipboard to paste.');
      return;
    }
    _controller.text = text;
    setState(() {
      _invalid = false;
      _serverError = null;
    });
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _state = _KeyState.idle;
      _serverError = message;
    });
    _shake.forward(from: 0);
    Haptics.error();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final key = _controller.text.trim();
    if (!_pattern.hasMatch(key)) {
      setState(() {
        _invalid = true;
        _serverError = null;
      });
      _shake.forward(from: 0);
      Haptics.error();
      return;
    }
    setState(() {
      _invalid = false;
      _serverError = null;
      _state = _KeyState.checking;
    });

    // The backend validates the key against Render, encrypts it and lists the
    // workspaces' services; the phone never stores it.
    final state = AppScope.read(context);
    try {
      final services = await state.connectRender(key);
      if (!mounted) return;
      setState(() {
        _found = services.length;
        _state = _KeyState.connected;
      });
      Haptics.success();
      _timer = Timer(const Duration(milliseconds: 650), () {
        if (mounted) widget.onConnected();
      });
    } on ApiException catch (e) {
      _fail(e.message);
    } catch (e) {
      _fail('Something went wrong connecting Render.');
    }
  }

  Color get _borderColor {
    if (_invalid || _serverError != null) return AppColors.critical;
    if (_state == _KeyState.connected) return AppColors.ok;
    if (_focus.hasFocus) return AppColors.accent;
    return AppColors.outline;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final help = _invalid
        ? "That doesn't look like a Render key. It starts with rnd_."
        : _serverError != null
            ? _serverError!
            : _state == _KeyState.connected
                ? 'Key works. Found $_found service${_found == 1 ? '' : 's'}.'
                : 'Tip: copy it in Render, then tap Paste.';
    final helpColor = _invalid || _serverError != null
        ? AppColors.criticalText
        : _state == _KeyState.connected
            ? AppColors.okText
            : AppColors.textFaint;

    return StepLayout(
      content: [
        Text('Paste your Render API key', style: t.headlineMedium?.copyWith(height: 1.2)),
        const SizedBox(height: 12),
        Text(
          'Render → Account Settings → API Keys. We store it encrypted on our '
          'server, never on this phone.',
          style: t.bodyLarge?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 28),
        const Text('API KEY', style: AppText.label),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) => Transform.translate(
            offset: Offset(math.sin(_shake.value * math.pi * 6) * 7 * (1 - _shake.value), 0),
            child: child,
          ),
          child: AnimatedContainer(
            duration: Motion.press,
            height: 56,
            padding: const EdgeInsets.only(left: 16, right: 8),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(Radii.control),
              border: Border.all(color: _borderColor, width: 1.5),
            ),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  enabled: _state == _KeyState.idle,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  onChanged: (_) {
                    if (_invalid || _serverError != null) {
                      setState(() {
                        _invalid = false;
                        _serverError = null;
                      });
                    }
                  },
                  style: AppText.mono(size: 15, color: AppColors.text),
                  decoration: const InputDecoration(
                    hintText: 'rnd_…',
                    isCollapsed: true,
                  ),
                ),
              ),
              TextButton(
                onPressed: _state == _KeyState.idle ? _paste : null,
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.surface3,
                  foregroundColor: AppColors.text,
                  minimumSize: const Size(64, 36),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Paste', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedDefaultTextStyle(
          duration: Motion.press,
          style: TextStyle(fontSize: 13, color: helpColor),
          child: Text(help, key: ValueKey(help)),
        ),
      ],
      footer: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(Radii.control),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.shield_outlined, size: 18, color: AppColors.warningText),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "A Render key reaches every workspace you're in. Revoke it in Render any time.",
                style: t.bodySmall?.copyWith(color: AppColors.textMuted, height: 1.45),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Connect',
          onPressed: _state == _KeyState.idle ? _submit : null,
          child: AnimatedSwitcher(
            duration: Motion.press,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(a), child: child),
            ),
            child: switch (_state) {
              _KeyState.idle => const Text('Connect', key: ValueKey('idle')),
              _KeyState.checking => const Row(
                  key: ValueKey('busy'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    ),
                    SizedBox(width: 10),
                    Text('Checking key'),
                  ],
                ),
              _KeyState.connected => const Row(
                  key: ValueKey('done'),
                  mainAxisSize: MainAxisSize.min,
                  children: [Icon(Icons.check_rounded), SizedBox(width: 8), Text('Connected')],
                ),
            },
          ),
        ),
      ],
    );
  }
}
