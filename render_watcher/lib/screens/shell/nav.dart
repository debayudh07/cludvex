import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

enum ShellTab { overview, alerts, activity, logs }

extension ShellTabInfo on ShellTab {
  String get label => switch (this) {
        ShellTab.overview => 'Home',
        ShellTab.alerts => 'Alerts',
        ShellTab.logs => 'Logs',
        ShellTab.activity => 'Activity',
      };

  IconData get icon => switch (this) {
        ShellTab.overview => Icons.home_outlined,
        ShellTab.alerts => Icons.notifications_none_rounded,
        ShellTab.logs => Icons.terminal_rounded,
        ShellTab.activity => Icons.history_rounded,
      };

  IconData get selectedIcon => switch (this) {
        ShellTab.overview => Icons.home_rounded,
        ShellTab.alerts => Icons.notifications_rounded,
        ShellTab.logs => Icons.terminal_rounded,
        ShellTab.activity => Icons.history_rounded,
      };
}

/// Display order in the nav.
const navOrder = [ShellTab.overview, ShellTab.alerts, ShellTab.logs, ShellTab.activity];

/// Phone nav: four tabs with a sliding violet indicator.
class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.selected,
    required this.badge,
    required this.badgeBump,
    required this.onSelect,
  });

  final ShellTab selected;
  final int badge;
  final int badgeBump;
  final ValueChanged<ShellTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final i = navOrder.indexOf(selected);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface1,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Stack(children: [
            AnimatedAlign(
              alignment: Alignment(-1 + i * 2 / (navOrder.length - 1), -1),
              duration: const Duration(milliseconds: 350),
              curve: Motion.playful,
              child: FractionallySizedBox(
                widthFactor: 1 / navOrder.length,
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 60,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
            Row(children: [
              for (final tab in navOrder)
                Expanded(
                  child: _NavItem(
                    tab: tab,
                    selected: tab == selected,
                    badge: tab == ShellTab.alerts ? badge : 0,
                    badgeBump: badgeBump,
                    onTap: () => onSelect(tab),
                  ),
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.badge,
    required this.badgeBump,
    required this.onTap,
  });

  final ShellTab tab;
  final bool selected;
  final int badge;
  final int badgeBump;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.text : AppColors.textFaint;
    return Semantics(
      selected: selected,
      button: true,
      label: badge > 0 ? '${tab.label}, $badge open' : tab.label,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: ExcludeSemantics(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(
              height: 32,
              child: Badge(
                isLabelVisible: badge > 0,
                backgroundColor: AppColors.critical,
                offset: const Offset(8, -2),
                label: TweenAnimationBuilder<double>(
                  key: ValueKey(badgeBump),
                  tween: Tween(begin: 1.4, end: 1),
                  duration: const Duration(milliseconds: 450),
                  curve: Motion.standard,
                  builder: (_, s, child) => Transform.scale(scale: s, child: child),
                  child: Text('$badge'),
                ),
                child: Icon(selected ? tab.selectedIcon : tab.icon,
                    size: 24, color: selected ? AppColors.accentText : color),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: Motion.press,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color),
              child: Text(tab.label),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Tablet / desktop nav.
class SideRail extends StatelessWidget {
  const SideRail({super.key, required this.selected, required this.badge, required this.onSelect});

  final ShellTab selected;
  final int badge;
  final ValueChanged<ShellTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      backgroundColor: AppColors.surface1,
      indicatorColor: AppColors.accent.withValues(alpha: 0.22),
      selectedIndex: navOrder.indexOf(selected),
      onDestinationSelected: (i) => onSelect(navOrder[i]),
      labelType: NavigationRailLabelType.all,
      groupAlignment: -0.85,
      selectedIconTheme: const IconThemeData(color: AppColors.accentText),
      unselectedIconTheme: const IconThemeData(color: AppColors.textFaint),
      selectedLabelTextStyle: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600, fontSize: 12),
      unselectedLabelTextStyle: const TextStyle(color: AppColors.textFaint, fontWeight: FontWeight.w600, fontSize: 12),
      leading: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 20),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: AppColors.accentStrong, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.radar_rounded, color: Colors.white),
        ),
      ),
      destinations: [
        for (final tab in navOrder)
          NavigationRailDestination(
            icon: Badge(
              isLabelVisible: tab == ShellTab.alerts && badge > 0,
              backgroundColor: AppColors.critical,
              label: Text('$badge'),
              child: Icon(tab.icon),
            ),
            selectedIcon: Icon(tab.selectedIcon),
            label: Text(tab.label),
          ),
      ],
    );
  }
}
