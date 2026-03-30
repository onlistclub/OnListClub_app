part of 'authentication_bloc.dart';

abstract class AuthenticationEvent extends Equatable {
  const AuthenticationEvent();

  @override
  List<Object?> get props => [];
}

class AuthenticationInitialEvent extends AuthenticationEvent {}

class EmailChangedEvent extends AuthenticationEvent {
  final String email;

  const EmailChangedEvent({required this.email});

  @override
  List<Object?> get props => [email];
}

class PasswordChangedEvent extends AuthenticationEvent {
  final String password;

  const PasswordChangedEvent({required this.password});

  @override
  List<Object?> get props => [password];
}

class LoginButtonPressedEvent extends AuthenticationEvent {}

class RegisterButtonPressedEvent extends AuthenticationEvent {}

class GoogleSignInEvent extends AuthenticationEvent {}

class AppleSignInEvent extends AuthenticationEvent {}
