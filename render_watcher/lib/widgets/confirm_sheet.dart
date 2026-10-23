import 'package:flutter/material.dart';

import '../motion/haptics.dart';
import '../theme/responsive.dart';
import '../theme/tokens.dart';
import 'primitives.dart';

/// Uber-style confirmation for costly actions: icon, title, consequences,
/// one full-width primary and a quiet cancel. Resolves to true on confirm.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  required String body,
  required List<String> points,
  required String confirmLabel,
  IconData icon = Icons.restart_alt_rounded,
  Color tone = AppColors.accentText,
  bool heavy = false,
}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 560),
    sheetAnimationStyle: const AnimationStyle(
      duration: Motion.enter,
      reverseDuration: Motion.exit,
      curve: Motion.decelerate,
      reverseCurve: Motion.accelerate,
    ),
    builder: (context) => _ConfirmSheet(
      title: title,
      body: body,
      points: points,
      confirmLabel: confirmLabel,
      icon: icon,
      tone: tone,
    ),
  );
  if (ok == true) heavy ? Haptics.heavy() : Haptics.light();
  return ok ?? false;
}

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.title,
    required this.body,
    required this.points,
    required this.confirmLabel,
    required this.icon,
    required this.tone,
  });

  final String title;
  final String body;
  final List<String> points;
  final String confirmLabel;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(context.gutter, 0, context.gutter, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: tone),
            ),
          ),
          const SizedBox(height: 16),
          Text(title, style: t.headlineSmall),
          const SizedBox(height: 10),
          Text(body,
              style: t.bodyLarge?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          for (final p in points)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.check_rounded, size: 16, color: AppColors.okText),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(p, style: t.bodyMedium)),
              ]),
            ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: confirmLabel,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              minimumSize: const Size.fromHeight(48),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
