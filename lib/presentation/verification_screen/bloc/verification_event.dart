part of 'verification_bloc.dart';

abstract class verificationEvent extends Equatable {
  const verificationEvent();

  @override
  List<Object?> get props => [];
}

class verificationInitialEvent extends verificationEvent {
  final DateTime registrationTime;
  final String email;
  final String password;

  const verificationInitialEvent({
    required this.registrationTime,
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [registrationTime, email, password];
}

class CheckVerificationEvent extends verificationEvent {}

class ResendEmailEvent extends verificationEvent {}

class TimerTickEvent extends verificationEvent {
  final Duration remainingTime;
  const TimerTickEvent(this.remainingTime);
  @override
  List<Object?> get props => [remainingTime];
}
