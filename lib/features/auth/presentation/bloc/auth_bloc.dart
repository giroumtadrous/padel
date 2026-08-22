import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:padel/features/auth/data/services/auth_service.dart';
import 'package:padel/features/skill_requests/data/services/skill_request_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  final SkillRequestService _skillRequestService;
  StreamSubscription? _authSubscription;

  AuthBloc({required AuthService authService, SkillRequestService? skillRequestService})
      : _authService = authService,
        _skillRequestService = skillRequestService ?? SkillRequestService(),
        super(const AuthInitial()) {
    on<AuthStarted>(_onStarted);
    on<AuthLoginWithEmail>(_onLoginWithEmail);
    on<AuthLoginWithGoogle>(_onLoginWithGoogle);
    on<AuthLoginWithApple>(_onLoginWithApple);
    on<AuthRegister>(_onRegister);
    on<AuthLoggedOut>(_onLoggedOut);
    on<AuthProfileUpdated>(_onProfileUpdated);
    on<RequestSkillLevelChange>(_onRequestSkillLevelChange);
    on<AuthPasswordResetRequested>(_onPasswordReset);
    on<ToggleFavorite>(_onToggleFavorite);
    on<TopUpWallet>(_onTopUpWallet);
    on<SaveFcmToken>(_onSaveFcmToken);
    on<RefreshCurrentUser>(_onRefreshCurrentUser);
    on<SkipPhoneVerification>(_onSkipPhoneVerification);
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

  Future<void> _onLoginWithApple(AuthLoginWithApple event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      final user = await _authService.signInWithApple();
      emit(AuthAuthenticated(user));
} catch (e) {
  emit(AuthError('DEBUG: ${e.toString()}'));
}
  }

  Future<void> _onRefreshCurrentUser(RefreshCurrentUser event, Emitter<AuthState> emit) async {
    if (state is! AuthAuthenticated) return;
    try {
      final refreshed = await _authService.currentUser;
      if (refreshed != null) emit(AuthAuthenticated(refreshed));
    } catch (_) {
      // Keep the current state if the refresh fails.
    }
  }

  Future<void> _onSkipPhoneVerification(
      SkipPhoneVerification event, Emitter<AuthState> emit) async {
    final current = state;
    if (current is! AuthAuthenticated) return;
    try {
      final updated = await _authService.skipPhoneVerification(current.user.uid);
      emit(AuthAuthenticated(updated));
    } catch (_) {
      // Keep the current state if this fails — the verify-phone screen just
      // won't be able to leave yet, no worse than before.
    }
  }

  Future<void> _onRegister(AuthRegister event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      final user = await _authService.signUpWithEmailAndPassword(
        email: event.email,
        password: event.password,
        displayName: event.displayName,
        skillLevel: event.skillLevel,
        preferredSide: event.preferredSide,
      );
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(_friendlyError(e.toString())));
    }
  }

  Future<void> _onLoggedOut(AuthLoggedOut event, Emitter<AuthState> emit) async {
    try {
      await _authService.signOut();
    } catch (_) {
      // Best-effort — even if the Google/Firebase sign-out call itself fails
      // (e.g. no network), still drop local auth state so the router sends
      // the user back to /login instead of leaving them stuck on the
      // current screen with no way forward.
    }
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
        preferredSide: event.preferredSide,
        phone: event.phone,
        skillLevel: event.skillLevel,
      );
      emit(AuthAuthenticated(updated));
    } catch (e) {
      emit(AuthError(e.toString()));
      emit(current);
    }
  }

  Future<void> _onRequestSkillLevelChange(
      RequestSkillLevelChange event, Emitter<AuthState> emit) async {
    final current = state;
    if (current is! AuthAuthenticated) return;

    try {
      await _skillRequestService.submitRequest(
        userId: current.user.uid,
        userName: current.user.displayName,
        currentLevel: current.user.skillLevel,
        requestedLevel: event.requestedLevel,
      );
      final refreshed = await _authService.currentUser;
      if (refreshed != null) emit(AuthAuthenticated(refreshed));
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

  Future<void> _onToggleFavorite(ToggleFavorite event, Emitter<AuthState> emit) async {
    final current = state;
    if (current is! AuthAuthenticated) return;

    try {
      final updated = await _authService.toggleFavorite(current.user.uid, event.venueId);
      emit(AuthAuthenticated(updated));
    } catch (e) {
      // Silently fail — don't change state on favorite error
    }
  }

  Future<void> _onTopUpWallet(TopUpWallet event, Emitter<AuthState> emit) async {
    final current = state;
    if (current is! AuthAuthenticated) return;

    try {
      final updated = await _authService.topUpWallet(current.user.uid, event.amount);
      emit(AuthAuthenticated(updated));
    } catch (e) {
      emit(AuthError(e.toString()));
      emit(current);
    }
  }

  Future<void> _onSaveFcmToken(SaveFcmToken event, Emitter<AuthState> emit) async {
    final current = state;
    if (current is! AuthAuthenticated) return;

    try {
      await _authService.saveFcmToken(current.user.uid, event.token);
    } catch (_) {
      // Non-critical — ignore
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('user-not-found') || raw.contains('wrong-password') || raw.contains('invalid-credential')) {
      return 'Incorrect email or password.';
    }
    if (raw.contains('email-already-in-use')) return 'An account with this email already exists.';
    if (raw.contains('account-exists-with-different-credential')) {
      final email = _authService.pendingLinkEmail;
      return 'An account already exists for ${email ?? 'this email'} using a different sign-in '
          'method. Sign in with that method once — we\'ll link this one automatically for next time.';
    }
    if (raw.contains('weak-password')) return 'Password must be at least 6 characters.';
    if (raw.contains('network-request-failed')) return 'No internet connection.';
    if (raw.contains('cancelled')) return 'Sign-in was cancelled.';
    if (raw.contains('only available on iOS')) return 'Apple Sign-In is only available on iOS.';
    if (raw.contains('permission-denied') || raw.contains('PERMISSION_DENIED')) {
      return 'Database permission error. Please check your Firestore security rules.';
    }
    if (raw.contains('unavailable')) return 'Service temporarily unavailable. Please try again.';
    if (raw.contains('too-many-requests')) return 'Too many attempts. Please wait a moment.';
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
