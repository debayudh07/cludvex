import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../theme/tokens.dart';
import '../../widgets/primitives.dart';

/// Foreground stand-in for the push notification, ranked by glance
/// priority: severity + service, then the finding, then confidence/time.
class IncomingBanner extends StatelessWidget {
  const IncomingBanner({super.key, required this.alert, required this.onTap, required this.onDismiss});

  final Alert alert;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final service = MockData.service(alert.serviceId);
    return Dismissible(
      key: const ValueKey('banner'),
      direction: DismissDirection.up,
      onDismissed: (_) => onDismiss(),
      confirmDismiss: (_) async {
        onDismiss();
        return false;
      },
      child: Semantics(
        liveRegion: true,
        child: Pressable(
          onTap: onTap,
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(Radii.panel),
          semanticLabel: '${alert.severity.label} alert on ${service.name}: ${alert.title}. Open.',
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 12, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.panel),
              border: Border.all(color: const Color(0xFF2E3340)),
            ),
            child: Row(children: [
              LiveDot(color: alert.severity.bar, size: 9),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${alert.severity.label} · ${service.name}',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: alert.severity.text)),
                  const SizedBox(height: 3),
                  Text('Crash loop, likely OOM from v2.14.0',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('Agent ${(alert.confidence * 100).round()}% sure · verifier agrees · now',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textFaint),
            ]),
          ),
        ),
      ),
    );
  }
}
