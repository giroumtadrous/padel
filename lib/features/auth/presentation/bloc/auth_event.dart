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
