import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:padel/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:padel/features/admin/presentation/screens/manage_courts_screen.dart';
import 'package:padel/features/admin/presentation/screens/payment_verification_screen.dart';
import 'package:padel/features/admin/presentation/screens/revenue_screen.dart';
import 'package:padel/features/admin/presentation/screens/user_profile_view_screen.dart';
import 'package:padel/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:padel/features/auth/presentation/bloc/auth_state.dart';
import 'package:padel/features/auth/presentation/screens/login_screen.dart';
import 'package:padel/features/auth/presentation/screens/help_support_screen.dart';
import 'package:padel/features/auth/presentation/screens/profile_screen.dart';
import 'package:padel/features/auth/presentation/screens/register_screen.dart';
import 'package:padel/features/auth/presentation/screens/about_malaaby_screen.dart';
import 'package:padel/features/auth/presentation/screens/verify_phone_screen.dart';
import 'package:padel/features/auth/presentation/screens/complete_profile_screen.dart';
import 'package:padel/features/booking/data/models/booking_model.dart';
import 'package:padel/features/booking/presentation/screens/booking_confirm_screen.dart';
import 'package:padel/features/booking/presentation/screens/card_payment_screen.dart';
import 'package:padel/features/booking/presentation/screens/booking_success_screen.dart';
import 'package:padel/features/market/presentation/screens/manage_market_screen.dart';
import 'package:padel/features/market/presentation/screens/market_screen.dart';
import 'package:padel/features/matches/presentation/screens/match_detail_screen.dart';
import 'package:padel/features/reviews/presentation/screens/add_review_screen.dart';
import 'package:padel/features/reviews/presentation/screens/venue_reviews_screen.dart';
import 'package:padel/features/skill_requests/presentation/screens/skill_requests_screen.dart';
import 'package:padel/features/tournaments/presentation/screens/manage_tournaments_screen.dart';
import 'package:padel/features/tournaments/presentation/screens/tournaments_screen.dart';
import 'package:padel/features/venues/data/services/venue_service.dart';
import 'package:padel/features/venues/presentation/bloc/venues_bloc.dart';
import 'package:padel/features/venues/presentation/bloc/venues_event.dart';
import 'package:padel/features/venues/presentation/screens/venue_detail_screen.dart';
import 'package:padel/features/venues/presentation/screens/venues_list_screen.dart';
import 'package:padel/features/venues/presentation/screens/venues_map_screen.dart';
import 'package:padel/features/wallet/presentation/screens/wallet_screen.dart';
import 'package:padel/core/widgets/coming_soon_screen.dart';
import 'package:padel/core/widgets/main_shell.dart';
import 'package:padel/core/widgets/splash_screen.dart';

class AppRouter {
  static GoRouter router(BuildContext context) {
    final authBloc = context.read<AuthBloc>();

    return GoRouter(
      initialLocation: '/splash',
      refreshListenable: _GoRouterRefreshStream(authBloc.stream),
      redirect: (ctx, state) {
        final authState = authBloc.state;
        final loc = state.matchedLocation;
        final isAuthRoute = loc == '/login' || loc == '/register';

        // During initial Firebase auth check, hold at /splash
        if (authState is AuthInitial || authState is AuthLoading) {
          return loc == '/splash' ? null : '/splash';
        }

        final isAuthenticated = authState is AuthAuthenticated;
        final homeRoute =
            isAuthenticated && authState.user.hasAdminAccess ? '/admin' : '/venues';
        if (!isAuthenticated && !isAuthRoute) return '/login';
        if (isAuthenticated && isAuthRoute) return homeRoute;
        if (loc == '/splash') return isAuthenticated ? homeRoute : '/login';

        if (authState is AuthAuthenticated) {
          final isProfileIncomplete = authState.user.preferredSide.isEmpty || authState.user.skillLevel == 0.0;
          if (isProfileIncomplete) {
            return loc == '/complete-profile' ? null : '/complete-profile';
          }

          if (loc == '/complete-profile') {
            return homeRoute;
          }

          if (loc.startsWith('/admin') && !authState.user.hasAdminAccess) return '/venues';

          // Admins only get the Dashboard + Profile tabs — no player-facing
          // browsing surfaces.
          final isPlayerOnlyRoute = loc.startsWith('/venues') ||
              loc.startsWith('/matches') ||
              loc.startsWith('/tournaments') ||
              loc.startsWith('/market');
          if (isPlayerOnlyRoute && authState.user.hasAdminAccess) return '/admin';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          builder: (_, __) => const SplashScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, __) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (_, __) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/verify-phone',
          builder: (_, __) => const VerifyPhoneScreen(),
        ),
        GoRoute(
          path: '/complete-profile',
          builder: (_, __) => const CompleteProfileScreen(),
        ),
        GoRoute(
          path: '/booking/confirm',
          builder: (_, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            return BookingConfirmScreen(
              venueName: extra['venueName'] as String? ?? '',
              courtName: extra['courtName'] as String? ?? '',
            );
          },
        ),
        GoRoute(
          path: '/booking/card-payment',
          builder: (_, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            return CardPaymentScreen(
              venueName: extra['venueName'] as String? ?? '',
              courtName: extra['courtName'] as String? ?? '',
              useLoyaltyDiscount: extra['useLoyaltyDiscount'] as bool? ?? false,
            );
          },
        ),
        GoRoute(
          path: '/booking/success',
          builder: (_, state) {
            final booking = state.extra as BookingModel?;
            if (booking == null) return const ProfileScreen();
            return BookingSuccessScreen(booking: booking);
          },
        ),
        GoRoute(
          path: '/booking/:bookingId/review',
          builder: (_, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            return AddReviewScreen(
              bookingId: state.pathParameters['bookingId']!,
              venueId: extra['venueId'] as String? ?? '',
              venueName: extra['venueName'] as String? ?? 'Venue',
            );
          },
        ),
        GoRoute(
          path: '/wallet',
          builder: (_, __) => const WalletScreen(),
        ),
        GoRoute(
          path: '/help-support',
          builder: (_, __) => const HelpSupportScreen(),
        ),
        GoRoute(
          path: '/about',
          builder: (_, __) => const AboutMalaabyScreen(),
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
                      path: 'map',
                      builder: (_, __) => const VenuesMapScreen(),
                    ),
                    GoRoute(
                      path: ':venueId',
                      builder: (context, state) {
                        final venueId = state.pathParameters['venueId']!;
                        // Scoped VenuesBloc — isolated from the shared list
                        // bloc so loading venue detail can never overwrite
                        // (and race with) the venues list's own state.
                        return BlocProvider(
                          create: (ctx) => VenuesBloc(
                            venueService: ctx.read<VenueService>(),
                          )..add(LoadVenueDetail(venueId)),
                          child: VenueDetailScreen(venueId: venueId),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/matches',
                  builder: (_, __) => const ComingSoonScreen(
                    title: 'Open Matches',
                    message: 'Community open matches are on their way.',
                    icon: Icons.group_outlined,
                  ),
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
                  path: '/tournaments',
                  builder: (_, __) => const TournamentsScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/market',
                  builder: (_, __) => const MarketScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
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
                    GoRoute(
                      path: 'payments',
                      builder: (_, state) => PaymentVerificationScreen(
                        venueId: state.uri.queryParameters['venueId'] ?? '',
                      ),
                    ),
                    GoRoute(
                      path: 'tournaments',
                      builder: (_, __) => const ManageTournamentsScreen(),
                    ),
                    GoRoute(
                      path: 'market',
                      builder: (_, __) => const ManageMarketScreen(),
                    ),
                    GoRoute(
                      path: 'skill-requests',
                      builder: (_, __) => const SkillRequestsScreen(),
                    ),
                    GoRoute(
                      path: 'reviews',
                      builder: (_, state) => VenueReviewsScreen(
                        venueId: state.uri.queryParameters['venueId'] ?? '',
                      ),
                    ),
                    GoRoute(
                      path: 'user/:userId',
                      builder: (_, state) => UserProfileViewScreen(
                        userId: state.pathParameters['userId']!,
                        venueId: state.uri.queryParameters['venueId'] ?? '',
                      ),
                    ),
                  ],
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
