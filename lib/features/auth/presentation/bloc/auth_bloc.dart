import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:padel/features/auth/data/services/auth_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  StreamSubscription? _authSubscription;

  AuthBloc({required AuthService authService})
      : _authService = authService,
        super(const AuthInitial()) {
    on<AuthStarted>(_onStarted);
    on<AuthLoginWithEmail>(_onLoginWithEmail);
    on<AuthLoginWithGoogle>(_onLoginWithGoogle);
    on<AuthRegister>(_onRegister);
    on<AuthLoggedOut>(_onLoggedOut);
    on<AuthProfileUpdated>(_onProfileUpdated);
    on<AuthPasswordResetRequested>(_onPasswordReset);
  }

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    await emit.onEach(
      _authService.authStateChanges,
      onData: (user) {
        if (user != null) {
          emit(AuthAuthenticated(user));
        } else {
          emit(const AuthUnauthenticated());
        }
      },
      onError: (_, __) => emit(const AuthUnauthenticated()),
    );
  }

  Future<void> _onLoginWithEmail(AuthLoginWithEmail event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      final user = await _authService.signInWithEmailAndPassword(event.email, event.password);
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(_friendlyError(e.toString())));
    }
  }

  Future<void> _onLoginWithGoogle(AuthLoginWithGoogle event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      final user = await _authService.signInWithGoogle();
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(_friendlyError(e.toString())));
    }
  }

  Future<void> _onRegister(AuthRegister event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      final user = await _authService.signUpWithEmailAndPassword(
        email: event.email,
        password: event.password,
        displayName: event.displayName,
      );
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(_friendlyError(e.toString())));
    }
  }

  Future<void> _onLoggedOut(AuthLoggedOut event, Emitter<AuthState> emit) async {
    await _authService.signOut();
    emit(const AuthUnauthenticated());
  }

  Future<void> _onProfileUpdated(AuthProfileUpdated event, Emitter<AuthState> emit) async {
    final current = state;
    if (current is! AuthAuthenticated) return;

    emit(const AuthLoading());
    try {
      final updated = await _authService.updateProfile(
        uid: current.user.uid,
        displayName: event.displayName,
        skillLevel: event.skillLevel,
        preferredSide: event.preferredSide,
        phone: event.phone,
      );
      emit(AuthAuthenticated(updated));
    } catch (e) {
      emit(AuthError(e.toString()));
      emit(current);
    }
  }

  Future<void> _onPasswordReset(AuthPasswordResetRequested event, Emitter<AuthState> emit) async {
    try {
      await _authService.sendPasswordResetEmail(event.email);
      emit(const AuthPasswordResetSent());
    } catch (e) {
      emit(AuthError(_friendlyError(e.toString())));
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('user-not-found') || raw.contains('wrong-password') || raw.contains('invalid-credential')) {
      return 'Incorrect email or password.';
    }
    if (raw.contains('email-already-in-use')) return 'An account with this email already exists.';
    if (raw.contains('weak-password')) return 'Password must be at least 6 characters.';
    if (raw.contains('network-request-failed')) return 'No internet connection.';
    if (raw.contains('cancelled')) return 'Sign-in was cancelled.';
    if (raw.contains('permission-denied') || raw.contains('PERMISSION_DENIED')) {
      return 'Database permission error. Please check your Firestore security rules.';
    }
    if (raw.contains('unavailable')) return 'Service temporarily unavailable. Please try again.';
    if (raw.contains('too-many-requests')) return 'Too many attempts. Please wait a moment.';
    // In debug builds, surface the raw error to make issues obvious
    assert(() {
      // ignore: avoid_print
      print('[AuthBloc] Unhandled error: $raw');
      return true;
    }());
    return 'Something went wrong. Please try again.';
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }
}
