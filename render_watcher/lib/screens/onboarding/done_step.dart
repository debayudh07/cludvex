import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../widgets/primitives.dart';
import 'onboarding_flow.dart';

class DoneStep extends StatelessWidget {
  const DoneStep({super.key, required this.count, required this.onOpen});

  final int count;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return StepLayout(
      content: [
        const SizedBox(height: 40),
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            builder: (context, s, child) => Transform.scale(scale: s, child: child),
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.ok.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, size: 40, color: AppColors.okText),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          "You're watching $count service${count == 1 ? '' : 's'}",
          textAlign: TextAlign.center,
          style: t.headlineMedium?.copyWith(height: 1.25),
        ),
        const SizedBox(height: 12),
        Text(
          "The agent starts in notify-only mode. It won't change anything in "
          'production until you allow it.',
          textAlign: TextAlign.center,
          style: t.bodyLarge?.copyWith(color: AppColors.textMuted),
        ),
      ],
      footer: [PrimaryButton(label: 'Open dashboard', onPressed: onOpen)],
    );
  }
}
