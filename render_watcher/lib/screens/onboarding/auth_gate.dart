import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme/responsive.dart';
import '../../theme/tokens.dart';
import '../../widgets/primitives.dart';
import '../shell/home_shell.dart';
import 'onboarding_flow.dart';

/// Decides the entry point: Firebase tells us whether there is a session,
/// `GET /me` tells us how far through setup the account is.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<User?>? _sub;
  bool _busy = true;
  StartPoint _start = StartPoint.signIn;
  String? _error;

  @override
  void initState() {
    super.initState();
    final state = AppScope.read(context);
    _sub = state.auth.authStateChanges.listen((user) {
      if (user == null) {
        if (mounted) {
          setState(() {
            _busy = false;
            _start = StartPoint.signIn;
            _error = null;
          });
        }
      } else {
        _load();
      }
    });
  }

  Future<void> _load() async {
    if (mounted) setState(() => _busy = true);
    final state = AppScope.read(context);
    final start = await state.bootstrap();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _start = start;
      _error = state.meError;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) return const _Booting();
    // Signed in but the backend is unreachable: a dead end without a retry.
    if (_error != null && AppScope.read(context).signedIn) {
      return _Unreachable(message: _error!, onRetry: _load);
    }
    return switch (_start) {
      StartPoint.home => const HomeShell(),
      StartPoint.connectRender => const OnboardingFlow(start: OnboardingStep.apiKey),
      StartPoint.pickServices => const OnboardingFlow(start: OnboardingStep.pickServices),
      StartPoint.signIn => const OnboardingFlow(start: OnboardingStep.signIn),
    };
  }
}

class _Booting extends StatelessWidget {
  const _Booting();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.accent),
        ),
      ),
    );
  }
}

class _Unreachable extends StatelessWidget {
  const _Unreachable({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.gutter),
            child: ContentWidth(
              maxWidth: 420,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.textFaint),
                const SizedBox(height: 18),
                Text("Can't reach the agent",
                    textAlign: TextAlign.center, style: t.headlineSmall),
                const SizedBox(height: 10),
                Text(message,
                    textAlign: TextAlign.center,
                    style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
                const SizedBox(height: 24),
                PrimaryButton(label: 'Try again', onPressed: onRetry),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => AppScope.read(context).signOut(),
                  child: const Text('Sign out', style: TextStyle(color: AppColors.textFaint)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
