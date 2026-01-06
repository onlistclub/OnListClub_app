part of 'sign_up_bloc.dart';

abstract class SignUpEvent extends Equatable {
  const SignUpEvent();

  @override
  List<Object?> get props => [];
}

class SignUpInitialEvent extends SignUpEvent {}

class FirstNameChangedEvent extends SignUpEvent {
  final String firstName;
  const FirstNameChangedEvent({required this.firstName});
  @override
  List<Object?> get props => [firstName];
}

class LastNameChangedEvent extends SignUpEvent {
  final String lastName;
  const LastNameChangedEvent({required this.lastName});
  @override
  List<Object?> get props => [lastName];
}

class EmailChangedEvent extends SignUpEvent {
  final String email;
  const EmailChangedEvent({required this.email});
  @override
  List<Object?> get props => [email];
}

class PasswordChangedEvent extends SignUpEvent {
  final String password;
  const PasswordChangedEvent({required this.password});
  @override
  List<Object?> get props => [password];
}

class ConfirmPasswordChangedEvent extends SignUpEvent {
  final String confirmPassword;
  const ConfirmPasswordChangedEvent({required this.confirmPassword});
  @override
  List<Object?> get props => [confirmPassword];
}

class DobChangedEvent extends SignUpEvent {
  final DateTime dob;
  const DobChangedEvent({required this.dob});
  @override
  List<Object?> get props => [dob];
}

class SubmitSignUpEvent extends SignUpEvent {}

class PhoneChangedEvent extends SignUpEvent {
  final String phone;
  final String? countryIso;
  final String? nationalNumber;
  const PhoneChangedEvent({required this.phone, this.countryIso, this.nationalNumber});
  @override
  List<Object?> get props => [phone, countryIso, nationalNumber];
}
