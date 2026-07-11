import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:padel/core/router/app_router.dart';
import 'package:padel/core/services/notification_service.dart';
import 'package:padel/core/services/notifications_repository.dart';
import 'package:padel/core/theme/app_theme.dart';
import 'package:padel/features/admin/data/services/admin_service.dart';
import 'package:padel/features/admin/presentation/bloc/admin_bloc.dart';
import 'package:padel/features/auth/data/services/auth_service.dart';
import 'package:padel/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:padel/features/auth/presentation/bloc/auth_event.dart';
import 'package:padel/features/auth/presentation/bloc/auth_state.dart';
import 'package:padel/features/booking/data/services/booking_service.dart';
import 'package:padel/features/booking/presentation/bloc/booking_bloc.dart';
import 'package:padel/features/market/data/services/market_service.dart';
import 'package:padel/features/market/presentation/bloc/market_bloc.dart';
import 'package:padel/features/matches/data/services/matchmaking_service.dart';
import 'package:padel/features/matches/presentation/bloc/matches_bloc.dart';
import 'package:padel/features/reviews/data/services/review_service.dart';
import 'package:padel/features/skill_requests/data/services/skill_request_service.dart';
import 'package:padel/features/tournaments/data/services/tournament_service.dart';
import 'package:padel/features/tournaments/presentation/bloc/tournaments_bloc.dart';
import 'package:padel/features/venues/data/services/venue_service.dart';
import 'package:padel/features/venues/presentation/bloc/venues_bloc.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialise push notifications — non-critical, ignore failures on emulators
  try {
    await NotificationService().init();
  } catch (_) {}

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark, // dark icons on light cream header
  ));

  runApp(const PadelApp());
}

class PadelApp extends StatelessWidget {
  const PadelApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Services — singletons, shared across BLoCs
    final authService = AuthService();
    final venueService = VenueService();
    final bookingService = BookingService();
    final matchmakingService = MatchmakingService();
    final adminService = AdminService();
    final reviewService = ReviewService();
    final notificationsRepository = NotificationsRepository();
    final tournamentService = TournamentService();
    final marketService = MarketService();
    final skillRequestService = SkillRequestService();

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authService),
        RepositoryProvider.value(value: venueService),
        RepositoryProvider.value(value: bookingService),
        RepositoryProvider.value(value: matchmakingService),
        RepositoryProvider.value(value: adminService),
        RepositoryProvider.value(value: reviewService),
        RepositoryProvider.value(value: notificationsRepository),
        RepositoryProvider.value(value: tournamentService),
        RepositoryProvider.value(value: marketService),
        RepositoryProvider.value(value: skillRequestService),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => AuthBloc(
              authService: authService,
              skillRequestService: skillRequestService,
            )..add(const AuthStarted()),
          ),
          BlocProvider(
            create: (_) => VenuesBloc(venueService: venueService),
          ),
          BlocProvider(
            create: (_) => BookingBloc(bookingService: bookingService),
          ),
          BlocProvider(
            create: (_) => MatchesBloc(matchmakingService: matchmakingService),
          ),
          BlocProvider(
            create: (_) => AdminBloc(adminService: adminService, venueService: venueService),
          ),
          BlocProvider(
            create: (_) => TournamentsBloc(tournamentService: tournamentService),
          ),
          BlocProvider(
            create: (_) => MarketBloc(marketService: marketService),
          ),
        ],
        child: const _AppView(),
      ),
    );
  }
}

class _AppView extends StatefulWidget {
  const _AppView();

  @override
  State<_AppView> createState() => _AppViewState();
}

class _AppViewState extends State<_AppView> {
  late final _router = AppRouter.router(context);

  @override
  void initState() {
    super.initState();
    // When auth state changes to authenticated, save FCM token
    context.read<AuthBloc>().stream.listen((state) async {
      if (state is AuthAuthenticated) {
        final token = await NotificationService().getToken();
        if (token != null && mounted) {
          context.read<AuthBloc>().add(SaveFcmToken(token));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PadelPro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
