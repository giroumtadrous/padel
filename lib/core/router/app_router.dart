import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:padel/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:padel/features/admin/presentation/screens/manage_courts_screen.dart';
import 'package:padel/features/admin/presentation/screens/revenue_screen.dart';
import 'package:padel/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:padel/features/auth/presentation/bloc/auth_state.dart';
import 'package:padel/features/auth/presentation/screens/login_screen.dart';
import 'package:padel/features/auth/presentation/screens/profile_screen.dart';
import 'package:padel/features/auth/presentation/screens/register_screen.dart';
import 'package:padel/features/booking/presentation/screens/booking_confirm_screen.dart';
import 'package:padel/features/booking/presentation/screens/booking_history_screen.dart';
import 'package:padel/features/booking/presentation/screens/slot_selection_screen.dart';
import 'package:padel/features/matches/presentation/screens/match_detail_screen.dart';
import 'package:padel/features/matches/presentation/screens/open_matches_screen.dart';
import 'package:padel/features/venues/presentation/screens/venue_detail_screen.dart';
import 'package:padel/features/venues/presentation/screens/venues_list_screen.dart';
import 'package:padel/core/widgets/main_shell.dart';

class AppRouter {
  static GoRouter router(BuildContext context) {
    final authBloc = context.read<AuthBloc>();

    return GoRouter(
      initialLocation: '/venues',
      refreshListenable: _GoRouterRefreshStream(authBloc.stream),
      redirect: (ctx, state) {
        final authState = authBloc.state;
        final isAuthenticated = authState is AuthAuthenticated;
        final loc = state.matchedLocation;

        final isAuthRoute = loc == '/login' || loc == '/register';

        if (!isAuthenticated && !isAuthRoute) return '/login';
        if (isAuthenticated && isAuthRoute) return '/venues';

        if (loc.startsWith('/admin') && isAuthenticated) {
          final user = (authState as AuthAuthenticated).user;
          if (!user.isAdmin) return '/venues';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (_, __) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (_, __) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/booking/confirm',
          builder: (_, __) => const BookingConfirmScreen(),
        ),
        GoRoute(
          path: '/admin',
          builder: (_, __) => const AdminDashboardScreen(),
          routes: [
            GoRoute(
              path: 'courts',
              builder: (_, state) => ManageCourtsScreen(
                venueId: state.uri.queryParameters['venueId'] ?? '',
              ),
            ),
            GoRoute(
              path: 'revenue',
              builder: (_, state) => RevenueScreen(
                venueId: state.uri.queryParameters['venueId'] ?? '',
              ),
            ),
          ],
        ),
        StatefulShellRoute.indexedStack(
          builder: (_, __, shell) => MainShell(navigationShell: shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/venues',
                  builder: (_, __) => const VenuesListScreen(),
                  routes: [
                    GoRoute(
                      path: ':venueId',
                      builder: (_, state) => VenueDetailScreen(
                        venueId: state.pathParameters['venueId']!,
                      ),
                      routes: [
                        GoRoute(
                          path: 'book/:courtId',
                          builder: (_, state) => SlotSelectionScreen(
                            venueId: state.pathParameters['venueId']!,
                            courtId: state.pathParameters['courtId']!,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/matches',
                  builder: (_, __) => const OpenMatchesScreen(),
                  routes: [
                    GoRoute(
                      path: ':matchId',
                      builder: (_, state) => MatchDetailScreen(
                        matchId: state.pathParameters['matchId']!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/bookings',
                  builder: (_, __) => const BookingHistoryScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (_, __) => const ProfileScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
