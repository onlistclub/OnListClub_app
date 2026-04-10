part of 'complete_profile_bloc.dart';

abstract class CompleteProfileEvent extends Equatable {
  const CompleteProfileEvent();
  @override
  List<Object?> get props => [];
}

class CompleteProfileInitialEvent extends CompleteProfileEvent {
  final String? prefillNome;
  final String? prefillCognome;
  final String? prefillEmail;
  const CompleteProfileInitialEvent({
    this.prefillNome,
    this.prefillCognome,
    this.prefillEmail,
  });
  @override
  List<Object?> get props => [prefillNome, prefillCognome, prefillEmail];
}

class CompleteProfileFirstNameChangedEvent extends CompleteProfileEvent {
  final String firstName;
  const CompleteProfileFirstNameChangedEvent({required this.firstName});
  @override
  List<Object?> get props => [firstName];
}

class CompleteProfileLastNameChangedEvent extends CompleteProfileEvent {
  final String lastName;
  const CompleteProfileLastNameChangedEvent({required this.lastName});
  @override
  List<Object?> get props => [lastName];
}

class CompleteProfileDobChangedEvent extends CompleteProfileEvent {
  final DateTime dob;
  const CompleteProfileDobChangedEvent({required this.dob});
  @override
  List<Object?> get props => [dob];
}

class CompleteProfilePhoneChangedEvent extends CompleteProfileEvent {
  final String phone;
  final String? countryIso;
  final String? nationalNumber;
  const CompleteProfilePhoneChangedEvent({
    required this.phone,
    this.countryIso,
    this.nationalNumber,
  });
  @override
  List<Object?> get props => [phone, countryIso, nationalNumber];
}

class CompleteProfileSubmitEvent extends CompleteProfileEvent {}
