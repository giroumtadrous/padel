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
  final double skillLevel;
  final String preferredSide;
  const AuthRegister({
    required this.email,
    required this.password,
    required this.displayName,
    required this.skillLevel,
    required this.preferredSide,
  });
  @override
  List<Object?> get props => [email, password, displayName, skillLevel, preferredSide];
}

class AuthLoggedOut extends AuthEvent {
  const AuthLoggedOut();
}

class AuthProfileUpdated extends AuthEvent {
  final String? displayName;
  final String? preferredSide;
  final String? phone;
  final double? skillLevel;
  const AuthProfileUpdated({
    this.displayName,
    this.preferredSide,
    this.phone,
    this.skillLevel,
  });
  @override
  List<Object?> get props => [displayName, preferredSide, phone, skillLevel];
}

/// Submits a skill-level change for admin review — does not change
/// [UserModel.skillLevel] itself until an admin approves it.
class RequestSkillLevelChange extends AuthEvent {
  final double requestedLevel;
  const RequestSkillLevelChange(this.requestedLevel);
  @override
  List<Object?> get props => [requestedLevel];
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
