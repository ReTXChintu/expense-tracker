import 'package:flutter/material.dart';
import 'today.dart';
import 'dashboard.dart';
import 'profile/profile_screen.dart';
import '../theme.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _destinations = [
    (icon: Icons.calendar_today_outlined, selected: Icons.calendar_today, label: 'Today'),
    (icon: Icons.bar_chart_outlined, selected: Icons.bar_chart, label: 'Analytics'),
    (icon: Icons.person_outline, selected: Icons.person, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScaffoldBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final offset = Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(animation);
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: offset, child: child),
            );
          },
          child: switch (_index) {
            0 => const TodayScreen(key: ValueKey('today')),
            1 => const DashboardScreen(key: ValueKey('dashboard')),
            _ => const ProfileScreen(key: ValueKey('profile')),
          },
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                height: 64,
                destinations: [
                  for (final d in _destinations)
                    NavigationDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selected),
                      label: d.label,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
