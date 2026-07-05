import 'package:equatable/equatable.dart';
import 'package:padel/features/auth/data/models/user_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final UserModel user;
  const AuthAuthenticated(this.user);
  @override
  // Bloc no-ops an emit() whose state is == the current one (and never even
  // updates its stored state), so phoneVerified/phoneVerificationSkipped must
  // be part of equality — otherwise re-emitting the same uid after phone
  // verification (or skipping it) would be silently dropped and the router's
  // redirect gate would never clear.
  List<Object?> get props => [user.uid, user.phoneVerified, user.phoneVerificationSkipped];
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
  @override
  List<Object?> get props => [message];
}

class AuthPasswordResetSent extends AuthState {
  const AuthPasswordResetSent();
}
