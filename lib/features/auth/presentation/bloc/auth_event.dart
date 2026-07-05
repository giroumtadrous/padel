import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthStarted extends AuthEvent {
  const AuthStarted();
}

class AuthLoginWithEmail extends AuthEvent {
  final String email;
  final String password;
  const AuthLoginWithEmail({required this.email, required this.password});
  @override
  List<Object?> get props => [email, password];
}

class AuthLoginWithGoogle extends AuthEvent {
  const AuthLoginWithGoogle();
}

class AuthLoginWithApple extends AuthEvent {
  const AuthLoginWithApple();
}

/// Re-fetches the current user from Firestore and re-emits
/// [AuthAuthenticated] — used after an out-of-band update (e.g. phone
/// verification) that the bloc itself didn't perform.
class RefreshCurrentUser extends AuthEvent {
  const RefreshCurrentUser();
}

/// Permanently skips the phone verification gate for the current user.
class SkipPhoneVerification extends AuthEvent {
  const SkipPhoneVerification();
}

class AuthRegister extends AuthEvent {
  final String email;
  final String password;
  final String displayName;
  const AuthRegister({required this.email, required this.password, required this.displayName});
  @override
  List<Object?> get props => [email, password, displayName];
}

class AuthLoggedOut extends AuthEvent {
  const AuthLoggedOut();
}

class AuthProfileUpdated extends AuthEvent {
  final String? displayName;
  final double? skillLevel;
  final String? preferredSide;
  final String? phone;
  const AuthProfileUpdated({this.displayName, this.skillLevel, this.preferredSide, this.phone});
  @override
  List<Object?> get props => [displayName, skillLevel, preferredSide, phone];
}

class AuthPasswordResetRequested extends AuthEvent {
  final String email;
  const AuthPasswordResetRequested(this.email);
  @override
  List<Object?> get props => [email];
}

class ToggleFavorite extends AuthEvent {
  final String venueId;
  const ToggleFavorite(this.venueId);
  @override
  List<Object?> get props => [venueId];
}

class TopUpWallet extends AuthEvent {
  final double amount;
  const TopUpWallet(this.amount);
  @override
  List<Object?> get props => [amount];
}

class SaveFcmToken extends AuthEvent {
  final String token;
  const SaveFcmToken(this.token);
  @override
  List<Object?> get props => [token];
}
