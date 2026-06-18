import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:padel/core/router/app_router.dart';
import 'package:padel/core/theme/app_theme.dart';
import 'package:padel/features/admin/data/services/admin_service.dart';
import 'package:padel/features/admin/presentation/bloc/admin_bloc.dart';
import 'package:padel/features/auth/data/services/auth_service.dart';
import 'package:padel/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:padel/features/auth/presentation/bloc/auth_event.dart';
import 'package:padel/features/booking/data/services/booking_service.dart';
import 'package:padel/features/booking/presentation/bloc/booking_bloc.dart';
import 'package:padel/features/matches/data/services/matchmaking_service.dart';
import 'package:padel/features/matches/presentation/bloc/matches_bloc.dart';
import 'package:padel/features/venues/data/services/venue_service.dart';
import 'package:padel/features/venues/presentation/bloc/venues_bloc.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
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

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authService),
        RepositoryProvider.value(value: venueService),
        RepositoryProvider.value(value: bookingService),
        RepositoryProvider.value(value: matchmakingService),
        RepositoryProvider.value(value: adminService),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => AuthBloc(authService: authService)..add(const AuthStarted()),
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
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PadelPro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: _router,
    );
  }
}
