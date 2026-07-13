import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:padel/features/auth/presentation/bloc/auth_state.dart';

class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final isAdmin = authState is AuthAuthenticated && authState.user.hasAdminAccess;

        return Scaffold(
          body: navigationShell,
          bottomNavigationBar: _BottomNav(
            isAdmin: isAdmin,
            currentIndex: navigationShell.currentIndex,
            onTap: (i) => navigationShell.goBranch(
              i,
              initialLocation: i == navigationShell.currentIndex,
            ),
          ),
        );
      },
    );
  }
}

// Branch indices, fixed by the StatefulShellRoute order in app_router.dart.
const _kVenuesBranch = 0;
const _kMatchesBranch = 1;
const _kTournamentsBranch = 2;
const _kMarketBranch = 3;
const _kAdminBranch = 4;
const _kProfileBranch = 5;

class _BottomNav extends StatelessWidget {
  final bool isAdmin;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.isAdmin, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Admins only ever manage their venue/courts — no player-facing browsing
    // tabs (Home, Matches, Tournaments, Market).
    final items = isAdmin
        ? [
            _NavItem(
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard_rounded,
              label: 'Dashboard',
              index: _kAdminBranch,
              currentIndex: currentIndex,
              onTap: onTap,
            ),
            _NavItem(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Profile',
              index: _kProfileBranch,
              currentIndex: currentIndex,
              onTap: onTap,
            ),
          ]
        : [
            _NavItem(
              icon: Icons.home_rounded,
              activeIcon: Icons.home_rounded,
              label: 'Home',
              index: _kVenuesBranch,
              currentIndex: currentIndex,
              onTap: onTap,
            ),
            _NavItem(
              icon: Icons.group_outlined,
              activeIcon: Icons.group_rounded,
              label: 'Matches',
              index: _kMatchesBranch,
              currentIndex: currentIndex,
              onTap: onTap,
            ),
            _NavItem(
              icon: Icons.emoji_events_outlined,
              activeIcon: Icons.emoji_events_rounded,
              label: 'Tournaments',
              index: _kTournamentsBranch,
              currentIndex: currentIndex,
              onTap: onTap,
            ),
            _NavItem(
              icon: Icons.storefront_outlined,
              activeIcon: Icons.storefront_rounded,
              label: 'Market',
              index: _kMarketBranch,
              currentIndex: currentIndex,
              onTap: onTap,
            ),
            _NavItem(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Profile',
              index: _kProfileBranch,
              currentIndex: currentIndex,
              onTap: onTap,
            ),
          ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: items.map((item) => Expanded(child: item)).toList(),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == currentIndex;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppColors.primary : AppColors.textHint,
              size: 21,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                color: isActive ? AppColors.primary : AppColors.textHint,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
